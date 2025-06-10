// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IPluginSetup} from "@aragon/osx-commons-contracts/src/plugin/setup/IPluginSetup.sol";
import {PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";

interface IDAOFactory {
    /// @notice The container for the DAO settings to be set during the DAO initialization.
    /// @param trustedForwarder The address of the trusted forwarder required for meta transactions.
    /// @param daoURI The DAO uri used with [EIP-4824](https://eips.ethereum.org/EIPS/eip-4824).
    /// @param subdomain The ENS subdomain to be registered for the DAO contract.
    /// @param metadata The metadata of the DAO.
    struct DAOSettings {
        address trustedForwarder;
        string daoURI;
        string subdomain;
        bytes metadata;
    }

    /// @notice The container with the information required to install a plugin on the DAO.
    /// @param pluginSetupRef The `PluginSetupRepo` address of the plugin and the version tag.
    /// @param data The bytes-encoded data containing the input parameters for the installation as specified in the plugin's build metadata JSON file.
    struct PluginSettings {
        PluginSetupRef pluginSetupRef;
        bytes data;
    }

    /// @notice The container with the information about an installed plugin on a DAO.
    /// @param plugin The address of the deployed plugin instance.
    /// @param preparedSetupData The applied preparedSetupData which contains arrays of helpers and permissions.
    struct InstalledPlugin {
        address plugin;
        IPluginSetup.PreparedSetupData preparedSetupData;
    }

    /// @notice Creates a new DAO, registers it in the DAO registry, and optionally installs plugins via the plugin setup processor.
    /// @dev If `_pluginSettings` is empty, the caller is granted `EXECUTE_PERMISSION` on the DAO.
    /// @param _daoSettings The settings to configure during DAO initialization.
    /// @param _pluginSettings An array containing plugin references and settings. If provided, each plugin is installed
    /// after the DAO creation.
    /// @return createdDao The address of the newly created DAO instance.
    function createDao(
        DAOSettings calldata _daoSettings,
        PluginSettings[] calldata _pluginSettings
    ) external returns (address createdDao);
}
