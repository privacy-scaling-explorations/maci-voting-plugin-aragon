// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {hashHelpers, PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {MaciVoting} from "../src/MaciVoting.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";
import {Utils} from "../script/Utils.sol";

contract MaciVotingScript is Script {
    address pluginRepoFactory;
    DAOFactory daoFactory;
    string nameWithEntropy;
    address[] pluginAddress;

    function setUp() public {
        pluginRepoFactory = vm.envAddress("PLUGIN_REPO_FACTORY");
        daoFactory = DAOFactory(vm.envAddress("DAO_FACTORY"));
        nameWithEntropy = string.concat("maci-voting-plugin-", vm.toString(block.timestamp));
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
        (GovernanceERC20 tokenToClone, , ) = Utils.getGovernanceTokenAndMintSettings();

        MaciVotingSetup pluginSetup = new MaciVotingSetup(tokenToClone);
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

    function getMaciVotingSetupParams()
        internal
        returns (
            MaciVotingSetup.SetupMACIParams memory setupMaciParams,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        )
    {
        (, tokenSettings, mintSettings) = Utils.getGovernanceTokenAndMintSettings();
        (
            address maciAddress,
            DomainObjs.PublicKey memory coordinatorPublicKey,
            IMaciVoting.VotingSettings memory votingSettings,
            address verifier,
            address vkRegistry,
            address policyFactory,
            address checkerFactory,
            address voiceCreditProxyFactory
        ) = Utils.readMaciAddresses();

        setupMaciParams = MaciVotingSetup.SetupMACIParams({
            maci: maciAddress,
            publicKey: coordinatorPublicKey,
            votingSettings: votingSettings,
            verifier: verifier,
            vkRegistry: vkRegistry,
            policyFactory: policyFactory,
            checkerFactory: checkerFactory,
            voiceCreditProxyFactory: voiceCreditProxyFactory
        });

        return (setupMaciParams, tokenSettings, mintSettings);
    }

    function getPluginSettings(
        PluginRepo pluginRepo
    ) public returns (DAOFactory.PluginSettings[] memory pluginSettings) {
        (
            MaciVotingSetup.SetupMACIParams memory setupMaciParams,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = getMaciVotingSetupParams();
        bytes memory pluginSettingsData = abi.encode(setupMaciParams, tokenSettings, mintSettings);

        PluginRepo.Tag memory tag = PluginRepo.Tag(1, 1);
        pluginSettings = new DAOFactory.PluginSettings[](1);
        pluginSettings[0] = DAOFactory.PluginSettings(
            PluginSetupRef(tag, pluginRepo),
            pluginSettingsData
        );
    }
}
