// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {PermissionLib} from "@aragon/osx-commons-contracts/src/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx-commons-contracts/src/plugin/setup/PluginSetup.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {ProxyLib} from "@aragon/osx-commons-contracts/src/utils/deployment/ProxyLib.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";

import {IMaciVoting} from "./IMaciVoting.sol";
import {MaciVoting} from "./MaciVoting.sol";

/// @title MaciVotingSetup
/// @dev Release 1, Build 1
// @custom:oz-upgrades-unsafe-allow state-variable-immutable
contract MaciVotingSetup is PluginSetup {
    using Clones for address;
    using ProxyLib for address;

    /// @notice The address of the `GovernanceERC20` base contract.
    address public immutable governanceERC20Base;

    /// @notice Configuration settings for a token used within the governance system.
    /// @param addr The token address. If set to `address(0)`, a new `GovernanceERC20` token is deployed.
    ///     If the address implements `IVotes`, it will be used directly; otherwise,
    ///     it is wrapped as `GovernanceWrappedERC20`.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    struct TokenSettings {
        address addr;
        string name;
        string symbol;
    }

    /// @notice Constructs the `PluginSetup` by storing the `MaciVoting` implementation address.
    /// @dev The implementation address is used to deploy UUPS proxies referencing it and
    /// to verify the plugin on the respective block explorers.
    constructor(GovernanceERC20 _governanceERC20Base, address _maciVoting) PluginSetup(_maciVoting) {
        governanceERC20Base = address(_governanceERC20Base);
    }

    function _deployToken(
        address _dao,
        TokenSettings memory tokenSettings,
        GovernanceERC20.MintSettings memory mintSettings
    ) internal returns (address token) {
        token = governanceERC20Base.clone();
        GovernanceERC20(token).initialize(IDAO(_dao), tokenSettings.name, tokenSettings.symbol, mintSettings);
    }

    function _deployPlugin(IMaciVoting.InitializationParams memory _params) internal returns (address plugin_) {
        plugin_ = IMPLEMENTATION.deployUUPSProxy(abi.encodeCall(MaciVoting.initialize, _params));
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes memory _data
    ) external returns (address plugin, PreparedSetupData memory preparedSetupData) {
        (
            IMaciVoting.InitializationParams memory _params,
            TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = abi.decode(_data, (IMaciVoting.InitializationParams, TokenSettings, GovernanceERC20.MintSettings));

        address token = _deployToken(_dao, tokenSettings, mintSettings);

        _params.dao = IDAO(_dao);
        _params.token = IVotesUpgradeable(token);

        plugin = _deployPlugin(_params);

        preparedSetupData.permissions = new PermissionLib.MultiTargetPermission[](2);
        preparedSetupData.permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });

        preparedSetupData.permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(plugin).CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID()
        });
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(
        address _dao,
        SetupPayload calldata _payload
    ) external view returns (PermissionLib.MultiTargetPermission[] memory permissions) {
        permissions = new PermissionLib.MultiTargetPermission[](2);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _dao,
            who: _payload.plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });

        permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(_payload.plugin).CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID()
        });
    }
}
