// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.29;

import {Test} from "forge-std/Test.sol";
import {PluginSetup, IPluginSetup} from "@aragon/osx-commons-contracts/src/plugin/setup/PluginSetup.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract AragonTest is Test {
    bytes internal constant EMPTY_BYTES = "";

    /// @notice Creates a mock DAO with a plugin.
    /// @param setup The plugin setup interface.
    /// @param setupData The setup data in bytes.
    /// @return A tuple containing the DAO and the address of the plugin.
    function createMockDaoWithPlugin(IPluginSetup setup, bytes memory setupData) internal returns (DAO, address) {
        DAO _dao = DAO(payable(new ERC1967Proxy(address(new DAO()), EMPTY_BYTES)));
        _dao.initialize(EMPTY_BYTES, address(this), address(0), "");

        (address plugin, PluginSetup.PreparedSetupData memory preparedSetupData) = setup.prepareInstallation(
            address(_dao),
            setupData
        );

        _dao.applyMultiTargetPermissions(preparedSetupData.permissions);

        return (_dao, plugin);
    }

    /// @notice Returns the address associated with a given label.
    /// @param label The label to get the address for.
    /// @return addr The address associated with the label.
    function account(string memory label) internal returns (address addr) {
        (addr, ) = accountAndKey(label);
    }

    /// @notice Returns the address and private key associated with a given label.
    /// @param label The label to get the address and private key for.
    /// @return addr The address associated with the label.
    /// @return pk The private key associated with the label.
    function accountAndKey(string memory label) internal returns (address addr, uint256 pk) {
        pk = uint256(keccak256(abi.encodePacked(label)));
        addr = vm.addr(pk);
        vm.label(addr, label);
    }

    /// @notice Advances the EVM time by a given amount.
    /// @param time The amount of time to advance in seconds.
    function timetravel(uint256 time) internal {
        vm.warp(block.timestamp + time);
    }

    /// @notice Advances the EVM block number by a given amount.
    /// @param blocks The number of blocks to advance.
    function blocktravel(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }
}
