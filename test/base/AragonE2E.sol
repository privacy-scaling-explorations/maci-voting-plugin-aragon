// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {Vm} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";

import {AragonTest} from "./AragonTest.sol";

contract AragonE2E is AragonTest {
    bytes internal constant NON_EMPTY_BYTES = "0x1234";
    uint256 internal constant _FORK_BLOCK = 18_335_949; // fork block in .env takes precedence

    DAOFactory internal daoFactory;
    PluginRepoFactory internal repoFactory;

    error UnknownNetwork();

    function setUp() public virtual {
        daoFactory = DAOFactory(vm.envAddress("DAO_FACTORY"));
        repoFactory = PluginRepoFactory(vm.envAddress("PLUGIN_REPO_FACTORY"));

        vm.createSelectFork(vm.envString("RPC_URL"));

        console2.log("======================== E2E SETUP ======================");
        console2.log("Forking from: ", vm.envString("FORKING_NETWORK"));
        console2.log("from block:   ", vm.envOr("FORK_BLOCK", _FORK_BLOCK));
        console2.log("daoFactory:   ", address(daoFactory));
        console2.log("repoFactory:  ", address(repoFactory));
        console2.log("=========================================================");
    }

    /// @notice Deploys a new PluginRepo with the first version
    /// @param _repoSubdomain The subdomain for the new PluginRepo
    /// @param _pluginSetup The address of the plugin setup contract
    /// @return repo The address of the newly created PluginRepo
    function deployRepo(
        string memory _repoSubdomain,
        address _pluginSetup
    ) internal returns (PluginRepo repo) {
        repo = repoFactory.createPluginRepoWithFirstVersion({
            _subdomain: _repoSubdomain,
            _pluginSetup: _pluginSetup,
            _maintainer: address(this),
            _releaseMetadata: NON_EMPTY_BYTES,
            _buildMetadata: NON_EMPTY_BYTES
        });
    }

    /// @notice Deploys a DAO with the given PluginRepo and installation data
    /// @param repo The PluginRepo to use for the DAO
    /// @param installData The installation data for the DAO
    /// @return dao The newly created DAO
    /// @return plugin The plugin used in the DAO
    function deployDao(
        PluginRepo repo,
        bytes memory installData
    ) internal returns (DAO dao, address plugin) {
        // 1. dao settings
        DAOFactory.DAOSettings memory daoSettings = DAOFactory.DAOSettings({
            trustedForwarder: address(0),
            daoURI: "https://mockDaoURL.com",
            subdomain: "mockdao888",
            metadata: EMPTY_BYTES
        });

        // 2. dao plugin settings
        DAOFactory.PluginSettings[] memory installSettings = new DAOFactory.PluginSettings[](1);
        installSettings[0] = DAOFactory.PluginSettings({
            pluginSetupRef: PluginSetupRef({versionTag: getLatestTag(repo), pluginSetupRepo: repo}),
            data: installData
        });

        // 3. create dao and record the emitted events
        vm.recordLogs();
        dao = daoFactory.createDao(daoSettings, installSettings);

        // 4. get the plugin address
        Vm.Log[] memory entries = vm.getRecordedLogs();
        for (uint256 i = 0; i < entries.length; i++) {
            if (
                entries[i].topics[0] ==
                keccak256("InstallationApplied(address,address,bytes32,bytes32)")
            ) {
                // the plugin address is the third topic
                plugin = address(uint160(uint256(entries[i].topics[2])));
            }
        }
    }

    /// @notice Deploys a new PluginRepo and a DAO
    /// @param _repoSubdomain The subdomain for the new PluginRepo
    /// @param _pluginSetup The address of the plugin setup contract
    /// @param pluginInitData The initialization data for the plugin
    function deployRepoAndDao(
        string memory _repoSubdomain,
        address _pluginSetup,
        bytes memory pluginInitData
    ) internal returns (DAO dao, PluginRepo repo, address plugin) {
        repo = deployRepo(_repoSubdomain, _pluginSetup);
        (dao, plugin) = deployDao(repo, pluginInitData);
    }

    /// @notice Fetches the latest tag from the PluginRepo
    /// @param repo The PluginRepo to fetch the latest tag from
    /// @return The latest tag from the PluginRepo
    function getLatestTag(PluginRepo repo) internal view returns (PluginRepo.Tag memory) {
        PluginRepo.Version memory v = repo.getLatestVersion(repo.latestRelease());
        return v.tag;
    }
}
