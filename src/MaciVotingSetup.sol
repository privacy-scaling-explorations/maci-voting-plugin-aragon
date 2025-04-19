// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity ^0.8.20;

import {PermissionLib} from "@aragon/osx/core/permission/PermissionLib.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx/framework/plugin/setup/PluginSetup.sol";
import {IDAO} from "@aragon/osx/core/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";

import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {IMaciVoting} from "./IMaciVoting.sol";
import {MaciVoting} from "./MaciVoting.sol";

/// @title MaciVotingSetup
/// @dev Release 1, Build 1
// @custom:oz-upgrades-unsafe-allow state-variable-immutable
contract MaciVotingSetup is PluginSetup {
    MaciVoting private immutable maciVoting;

    /// @notice Constructs the `PluginSetup` by storing the `MaciVoting` implementation address.
    /// @dev The implementation address is used to deploy UUPS proxies referencing it and
    /// to verify the plugin on the respective block explorers.
    constructor() {
        maciVoting = new MaciVoting();
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(
        address _dao,
        bytes memory _data
    ) external returns (address plugin, PreparedSetupData memory preparedSetupData) {
        (
            address maci,
            DomainObjs.PublicKey memory publicKey,
            IMaciVoting.VotingSettings memory votingSettings,
            address verifier,
            address vkRegistry,
            address policyFactory,
            address checkerFactory,
            address voiceCreditProxyFactory
        ) = abi.decode(
                _data,
                (
                    address,
                    DomainObjs.PublicKey,
                    IMaciVoting.VotingSettings,
                    address,
                    address,
                    address,
                    address,
                    address
                )
            );

        plugin = createERC1967Proxy(
            address(maciVoting),
            abi.encodeCall(
                MaciVoting.initialize,
                (
                    IDAO(_dao),
                    maci,
                    publicKey,
                    votingSettings,
                    verifier,
                    vkRegistry,
                    policyFactory,
                    checkerFactory,
                    voiceCreditProxyFactory
                )
            )
        );

        PermissionLib.MultiTargetPermission[]
            memory permissions = new PermissionLib.MultiTargetPermission[](1);

        permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });

        preparedSetupData.permissions = permissions;
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
