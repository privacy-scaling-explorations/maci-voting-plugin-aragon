// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {hashHelpers, PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {MaciVoting} from "../src/MaciVoting.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";

contract MaciVotingScript is Script {
    address pluginRepoFactory;
    DAOFactory daoFactory;
    string nameWithEntropy;
    address[] pluginAddress;
    address maciAddress;
    DomainObjs.PublicKey coordinatorPublicKey;
    IMaciVoting.VotingSettings votingSettings;
    address verifier = address(0x41501310360fB771e65Ef7DCA4F48231D9178253);
    address vkRegistry = address(0xDd16A1E9908b663Ed55260D63A4b6BD519662029);
    address policyFactory = address(0xF85482f8254EFb6a96346756ab81d5582E436d18);
    address checkerFactory = address(0x9D1C736b5c86d3eB6D9C062D89793C2fEa4bd5da);
    address voiceCreditProxyFactory = address(0x9D1C736b5c86d3eB6D9C062D89793C2fEa4bd5da);

    function setUp() public {
        pluginRepoFactory = vm.envAddress("PLUGIN_REPO_FACTORY");
        daoFactory = DAOFactory(vm.envAddress("DAO_FACTORY"));
        maciAddress = vm.envAddress("MACI_ADDRESS");
        coordinatorPublicKey = DomainObjs.PublicKey({
            x: vm.envUint("COORDINATOR_PUBLIC_KEY_X"),
            y: vm.envUint("COORDINATOR_PUBLIC_KEY_Y")
        });
        nameWithEntropy = string.concat("my-plugin-", vm.toString(block.timestamp));

        votingSettings = IMaciVoting.VotingSettings({
            minParticipation: 0,
            minDuration: 0,
            minProposerVotingPower: 0
        });
    }

    function run() public {
        // 0. Setting up Foundry
        vm.startBroadcast(vm.envUint("PRIVATE_KEY"));

        // 1. Deploying the Plugin Setup
        MaciVotingSetup pluginSetup = deployPluginSetup();

        // 2. Publishing it in the Aragon OSx Protocol
        PluginRepo pluginRepo = deployPluginRepo(address(pluginSetup));

        // 3. Defining the DAO Settings
        DAOFactory.DAOSettings memory daoSettings = getDAOSettings();

        // 4. Defining the plugin settings
        DAOFactory.PluginSettings[] memory pluginSettings = getPluginSettings(pluginRepo);

        // 5. Deploying the DAO
        vm.recordLogs();
        address createdDAO = address(daoFactory.createDao(daoSettings, pluginSettings));

        // 6. Getting the Plugin Address
        Vm.Log[] memory logEntries = vm.getRecordedLogs();

        for (uint256 i = 0; i < logEntries.length; i++) {
            if (
                logEntries[i].topics[0] ==
                keccak256("InstallationApplied(address,address,bytes32,bytes32)")
            ) {
                pluginAddress.push(address(uint160(uint256(logEntries[i].topics[2]))));
            }
        }

        vm.stopBroadcast();

        // 7. Logging the resulting addresses
        console2.log("Plugin Setup: ", address(pluginSetup));
        console2.log("Plugin Repo: ", address(pluginRepo));
        console2.log("Created DAO: ", address(createdDAO));
        console2.log("Installed Plugins: ");
        for (uint256 i = 0; i < pluginAddress.length; i++) {
            console2.log("- ", pluginAddress[i]);
        }
    }

    function deployPluginSetup() public returns (MaciVotingSetup) {
        MaciVotingSetup pluginSetup = new MaciVotingSetup();
        return pluginSetup;
    }

    function deployPluginRepo(address pluginSetup) public returns (PluginRepo pluginRepo) {
        pluginRepo = PluginRepoFactory(pluginRepoFactory).createPluginRepoWithFirstVersion(
            nameWithEntropy,
            pluginSetup,
            msg.sender,
            "1", // TODO: Give these actual values on prod
            "1"
        );
    }

    function getDAOSettings() public view returns (DAOFactory.DAOSettings memory) {
        return DAOFactory.DAOSettings(address(0), "", nameWithEntropy, "");
    }

    function getPluginSettings(
        PluginRepo pluginRepo
    ) public view returns (DAOFactory.PluginSettings[] memory pluginSettings) {
        bytes memory pluginSettingsData = abi.encode(maciAddress, coordinatorPublicKey, votingSettings, verifier, vkRegistry, policyFactory, checkerFactory, voiceCreditProxyFactory);

        PluginRepo.Tag memory tag = PluginRepo.Tag(1, 1);
        pluginSettings = new DAOFactory.PluginSettings[](1);
        pluginSettings[0] = DAOFactory.PluginSettings(
            PluginSetupRef(tag, pluginRepo),
            pluginSettingsData
        );
    }
}
