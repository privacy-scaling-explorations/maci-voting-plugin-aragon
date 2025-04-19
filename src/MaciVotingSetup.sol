// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.20;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";

import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {IMaciVoting} from "./IMaciVoting.sol";
import {MaciVoting} from "./MaciVoting.sol";
import {GovernanceERC20} from "./ERC20Votes/GovernanceERC20.sol";
import {VotingPowerCondition} from "./ERC20Votes/VotingPowerCondition.sol";

/// @title MaciVotingSetup
/// @dev Release 1, Build 1
// @custom:oz-upgrades-unsafe-allow state-variable-immutable
contract MaciVotingSetup is PluginSetup {
    using Clones for address;

    /// @notice The address of the `MaciVoting` implementation contract.
    MaciVoting private immutable maciVoting;

    /// @notice The address of the `GovernanceERC20` base contract.
    address public immutable governanceERC20Base;

    struct SetupMACIParams {
        address maci;
        DomainObjs.PublicKey publicKey;
        IMaciVoting.VotingSettings votingSettings;
        address verifier;
        address vkRegistry;
        address policyFactory;
        address checkerFactory;
        address voiceCreditProxyFactory;
    }

    /// @notice Constructs the `PluginSetup` by storing the `MaciVoting` implementation address.
    /// @dev The implementation address is used to deploy UUPS proxies referencing it and
    /// to verify the plugin on the respective block explorers.
    constructor(GovernanceERC20 _governanceERC20Base) {
        maciVoting = new MaciVoting();
        governanceERC20Base = address(_governanceERC20Base);
    }

    function _deployToken(
        address _dao,
        GovernanceERC20.TokenSettings memory tokenSettings,
        GovernanceERC20.MintSettings memory mintSettings
    ) internal returns (address token) {
        token = governanceERC20Base.clone();
        GovernanceERC20(token).initialize(
            IDAO(_dao),
            tokenSettings.name,
            tokenSettings.symbol,
            mintSettings
        );
    }

    function _deployPlugin(
        address _dao,
        address token,
        SetupMACIParams memory setupMaciParams
    ) internal returns (address plugin_) {
        plugin_ = createERC1967Proxy(
            address(maciVoting),
            abi.encodeCall(
                MaciVoting.initialize,
                (
                    IDAO(_dao),
                    setupMaciParams.maci,
                    setupMaciParams.publicKey,
                    setupMaciParams.votingSettings,
                    IVotesUpgradeable(token),
                    setupMaciParams.verifier,
                    setupMaciParams.vkRegistry,
                    setupMaciParams.policyFactory,
                    setupMaciParams.checkerFactory,
                    setupMaciParams.voiceCreditProxyFactory
                )
            )
        );
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes memory _data
    ) external returns (address plugin, PreparedSetupData memory preparedSetupData) {
        (
            SetupMACIParams memory setupMaciParams,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = abi.decode(
                _data,
                (SetupMACIParams, GovernanceERC20.TokenSettings, GovernanceERC20.MintSettings)
            );

        address token = _deployToken(_dao, tokenSettings, mintSettings);
        plugin = _deployPlugin(_dao, token, setupMaciParams);

        // return permissions for the DAO to setup
        preparedSetupData.helpers = new address[](2);
        preparedSetupData.helpers[0] = address(new VotingPowerCondition(plugin));
        preparedSetupData.helpers[1] = token;

        preparedSetupData.permissions = new PermissionLib.MultiTargetPermission[](1);
        preparedSetupData.permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external view returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _dao,
            who: _payload.plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });
    }

    /// @inheritdoc IPluginSetup
    function implementation() external view returns (address) {
        return address(maciVoting);
    }
}
