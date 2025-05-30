// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console2} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DAOFactory} from "@aragon/osx/framework/dao/DAOFactory.sol";
import {PluginRepoFactory} from "@aragon/osx/framework/plugin/repo/PluginRepoFactory.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {hashHelpers, PluginSetupRef} from "@aragon/osx/framework/plugin/setup/PluginSetupProcessorHelpers.sol";

import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

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
        console2.log("Installed Plugins and voting tokens: ");
        for (uint256 i = 0; i < pluginAddress.length; i++) {
            console2.log("- Plugin: ", pluginAddress[i]);
            console2.log("- Token:  ", address(MaciVoting(pluginAddress[i]).getVotingToken()));
        }
    }

    function deployPluginSetup() public returns (MaciVotingSetup) {
        // this ERC20 is just a placeholder, it will be cloned with token and mint settings from Utils
        GovernanceERC20 tokenToClone = new GovernanceERC20(
            IDAO(address(0x0)),
            "",
            "",
            GovernanceERC20.MintSettings({receivers: new address[](0), amounts: new uint256[](0)})
        );

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
            IMaciVoting.InitializationParams memory params,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        )
    {
        (, tokenSettings, mintSettings) = Utils.getGovernanceTokenAndMintSettings();

        Utils.MaciEnvVariables memory maciEnvVariables = Utils.readMaciEnv();

        params = IMaciVoting.InitializationParams({
            dao: IDAO(address(0)), // Set in MaciVotingSetup.prepareInstallation
            token: IVotesUpgradeable(address(0)), // Set in MaciVotingSetup.prepareInstallation
            maci: maciEnvVariables.maci,
            coordinatorPublicKey: maciEnvVariables.coordinatorPublicKey,
            votingSettings: maciEnvVariables.votingSettings,
            verifier: maciEnvVariables.verifier,
            verifyingKeysRegistry: maciEnvVariables.verifyingKeysRegistry,
            policyFactory: maciEnvVariables.policyFactory,
            checkerFactory: maciEnvVariables.checkerFactory,
            voiceCreditProxyFactory: maciEnvVariables.voiceCreditProxyFactory,
            treeDepths: maciEnvVariables.treeDepths,
            messageBatchSize: maciEnvVariables.messageBatchSize
        });

        return (params, tokenSettings, mintSettings);
    }

    function getPluginSettings(
        PluginRepo pluginRepo
    ) public returns (DAOFactory.PluginSettings[] memory pluginSettings) {
        (
            IMaciVoting.InitializationParams memory params,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = getMaciVotingSetupParams();
        bytes memory pluginSettingsData = abi.encode(params, tokenSettings, mintSettings);

        PluginRepo.Tag memory tag = PluginRepo.Tag(1, 1);
        pluginSettings = new DAOFactory.PluginSettings[](1);
        pluginSettings[0] = DAOFactory.PluginSettings(
            PluginSetupRef(tag, pluginRepo),
            pluginSettingsData
        );
    }
}
