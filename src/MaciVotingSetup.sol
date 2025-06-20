// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {IERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {PermissionLib} from "@aragon/osx-commons-contracts/src/permission/PermissionLib.sol";
import {
    PluginSetup,
    IPluginSetup
} from "@aragon/osx-commons-contracts/src/plugin/setup/PluginSetup.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {ProxyLib} from "@aragon/osx-commons-contracts/src/utils/deployment/ProxyLib.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";
import {GovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/GovernanceWrappedERC20.sol";

import {IMaciVoting} from "./IMaciVoting.sol";
import {MaciVoting} from "./MaciVoting.sol";
import {VotingPowerCondition} from "./ERC20Votes/VotingPowerCondition.sol";

/// @title MaciVotingSetup
/// @dev Release 1, Build 1
// @custom:oz-upgrades-unsafe-allow state-variable-immutable
contract MaciVotingSetup is PluginSetup {
    using Address for address;
    using Clones for address;
    using ProxyLib for address;

    /// @notice A special address encoding permissions that are valid for any
    /// address `who` or `where`.
    address private constant ANY_ADDR = address(type(uint160).max);

    /// @notice The address of the `MaciVoting` base contract.
    // solhint-disable-next-line immutable-vars-naming
    MaciVoting private immutable maciVotingBase;

    /// @notice The address of the `GovernanceERC20` base contract.
    // solhint-disable-next-line immutable-vars-naming
    address public immutable governanceERC20Base;

    /// @notice The address of the `GovernanceWrappedERC20` base contract.
    // solhint-disable-next-line immutable-vars-naming
    address public immutable governanceWrappedERC20Base;

    /// @notice Configuration settings for a token used within the governance system.
    /// @param addr The token address. If set to `address(0)`, a new
    /// `GovernanceERC20` token is deployed.
    ///     If the address implements `IVotes`, it will be used directly; otherwise,
    ///     it is wrapped as `GovernanceWrappedERC20`.
    /// @param name The name of the token.
    /// @param symbol The symbol of the token.
    struct TokenSettings {
        address addr;
        string name;
        string symbol;
    }

    /// @notice Thrown if the passed token address is not a token contract.
    /// @param token The token address
    error TokenNotContract(address token);

    /// @notice Thrown if token address is not ERC20.
    /// @param token The token address
    error TokenNotERC20(address token);

    /// @notice The contract constructor deploying the plugin implementation contract
    ///     and receiving the governance token base contracts to clone from.
    /// @dev The implementation address is used to deploy UUPS proxies referencing it and
    /// to verify the plugin on the respective block explorers.
    /// @param _governanceERC20Base The base `GovernanceERC20` contract to create clones from.
    /// @param _governanceWrappedERC20Base The base `GovernanceWrappedERC20` contract to create
    /// clones from.
    /// @param _maciVoting The base `MaciVoting` implementation address
    constructor(
        GovernanceERC20 _governanceERC20Base,
        GovernanceWrappedERC20 _governanceWrappedERC20Base,
        address _maciVoting
    ) PluginSetup(_maciVoting) {
        maciVotingBase = MaciVoting(IMPLEMENTATION);
        governanceERC20Base = address(_governanceERC20Base);
        governanceWrappedERC20Base = address(_governanceWrappedERC20Base);
    }

    /// @inheritdoc IPluginSetup
    function prepareInstallation(address _dao, bytes memory _data)
        external
        returns (address plugin, PreparedSetupData memory preparedSetupData)
    {
        // Decode `_data` to extract the params needed for deploying and initializing `TokenVoting`
        // plugin, and the required helpers
        (
            IMaciVoting.InitializationParams memory _params,
            TokenSettings memory tokenSettings,
            // only used for GovernanceERC20(token is not passed)
            GovernanceERC20.MintSettings memory mintSettings
        ) = abi.decode(
            _data, (IMaciVoting.InitializationParams, TokenSettings, GovernanceERC20.MintSettings)
        );

        address token = tokenSettings.addr;

        if (tokenSettings.addr != address(0)) {
            if (!token.isContract()) {
                revert TokenNotContract(token);
            }

            if (!_isERC20(token)) {
                revert TokenNotERC20(token);
            }

            if (!supportsIVotesInterface(token)) {
                token = governanceWrappedERC20Base.clone();
                // User already has a token. We need to wrap it in
                // GovernanceWrappedERC20 in order to make the token
                // include governance functionality.
                GovernanceWrappedERC20(token).initialize(
                    IERC20Upgradeable(tokenSettings.addr), tokenSettings.name, tokenSettings.symbol
                );
            }
        } else {
            // Clone a `GovernanceERC20`.
            token = governanceERC20Base.clone();
            GovernanceERC20(token).initialize(
                IDAO(_dao), tokenSettings.name, tokenSettings.symbol, mintSettings
            );
        }

        _params.dao = IDAO(_dao);
        _params.token = IVotesUpgradeable(token);

        // Prepare and deploy plugin proxy.
        plugin =
            address(maciVotingBase).deployUUPSProxy(abi.encodeCall(MaciVoting.initialize, _params));

        preparedSetupData.helpers = new address[](1);
        preparedSetupData.helpers[0] = address(new VotingPowerCondition(plugin));

        // Prepare permissions
        preparedSetupData.permissions =
            new PermissionLib.MultiTargetPermission[](tokenSettings.addr != address(0) ? 4 : 5);

        // Grant the `EXECUTE_PERMISSION` on the DAO to the plugin
        preparedSetupData.permissions[0] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: _dao,
            who: plugin,
            condition: PermissionLib.NO_CONDITION,
            permissionId: DAO(payable(_dao)).EXECUTE_PERMISSION_ID()
        });

        preparedSetupData.permissions[1] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.GrantWithCondition,
            where: plugin,
            who: ANY_ADDR,
            condition: preparedSetupData.helpers[0], // VotingPowerCondition
            permissionId: MaciVoting(IMPLEMENTATION).CREATE_PROPOSAL_PERMISSION_ID()
        });

        preparedSetupData.permissions[2] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: ANY_ADDR,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(IMPLEMENTATION).EXECUTE_PROPOSAL_PERMISSION_ID()
        });

        // Grant the `CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID` on the plugin to the DAO
        preparedSetupData.permissions[3] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Grant,
            where: plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(plugin).CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID()
        });

        // Grant the `MINT_PERMISSION_ID` on the token to the DAO if deploying a new token
        if (tokenSettings.addr == address(0)) {
            bytes32 tokenMintPermission = GovernanceERC20(token).MINT_PERMISSION_ID();

            preparedSetupData.permissions[4] = PermissionLib.MultiTargetPermission({
                operation: PermissionLib.Operation.Grant,
                where: token,
                who: _dao,
                condition: PermissionLib.NO_CONDITION,
                permissionId: tokenMintPermission
            });
        }
    }

    /// @inheritdoc IPluginSetup
    function prepareUninstallation(address _dao, SetupPayload calldata _payload)
        external
        view
        returns (PermissionLib.MultiTargetPermission[] memory permissions)
    {
        permissions = new PermissionLib.MultiTargetPermission[](4);

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
            who: ANY_ADDR,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(IMPLEMENTATION).CREATE_PROPOSAL_PERMISSION_ID()
        });

        permissions[2] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: ANY_ADDR,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(IMPLEMENTATION).EXECUTE_PROPOSAL_PERMISSION_ID()
        });

        permissions[3] = PermissionLib.MultiTargetPermission({
            operation: PermissionLib.Operation.Revoke,
            where: _payload.plugin,
            who: _dao,
            condition: PermissionLib.NO_CONDITION,
            permissionId: MaciVoting(_payload.plugin).CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID()
        });
    }

    /// @notice Unsatisfiably determines if the token is an IVotes interface.
    /// @dev Many tokens don't use ERC165 even though they still support IVotes.
    function supportsIVotesInterface(address token) public view returns (bool) {
        (bool success1, bytes memory data1) = token.staticcall(
            abi.encodeWithSelector(IVotesUpgradeable.getPastTotalSupply.selector, 0)
        );
        (bool success2, bytes memory data2) = token.staticcall(
            abi.encodeWithSelector(IVotesUpgradeable.getVotes.selector, address(this))
        );
        (bool success3, bytes memory data3) = token.staticcall(
            abi.encodeWithSelector(IVotesUpgradeable.getPastVotes.selector, address(this), 0)
        );

        return (
            success1 && data1.length == 0x20 && success2 && data2.length == 0x20 && success3
                && data3.length == 0x20
        );
    }

    /// @notice Unsatisfiably determines if the contract is an ERC20 token.
    /// @dev It's important to first check whether token is a contract prior to this call.
    /// @param token The token address
    function _isERC20(address token) private view returns (bool) {
        (bool success, bytes memory data) =
            token.staticcall(abi.encodeCall(IERC20Upgradeable.balanceOf, (address(this))));
        return success && data.length == 0x20;
    }
}
