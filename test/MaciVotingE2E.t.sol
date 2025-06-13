// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.29;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";

import {AragonE2E} from "./base/AragonE2E.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {Utils} from "../script/Utils.sol";

contract MaciVotingE2E is AragonE2E {
    address internal dao;
    MaciVoting internal plugin;
    PluginRepo internal repo;
    MaciVotingSetup internal setup;
    address internal unauthorised = account("unauthorised");

    function setUp() public virtual override {
        super.setUp();

        (
            GovernanceERC20 tokenToClone,
            MaciVotingSetup.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = Utils.getGovernanceTokenAndMintSettings();
        address maciVoting = address(new MaciVoting());

        setup = new MaciVotingSetup(tokenToClone, maciVoting);
        address _plugin;

        Utils.MaciEnvVariables memory maciEnvVariables = Utils.readMaciEnv();
        IMaciVoting.InitializationParams memory params = IMaciVoting.InitializationParams({
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

        (dao, repo, _plugin) = deployRepoAndDao(
            string.concat("maci-voting-plugin-test-", vm.toString(block.timestamp)),
            address(setup),
            abi.encode(params, tokenSettings, mintSettings)
        );

        plugin = MaciVoting(_plugin);
    }

    function test_e2e() public view {
        // test repo
        PluginRepo.Version memory version = repo.getLatestVersion(repo.latestRelease());
        assertEq(version.pluginSetup, address(setup));
        assertEq(version.buildMetadata, NON_EMPTY_BYTES);

        // test dao
        assertEq(
            keccak256(bytes(DAO(payable(dao)).daoURI())),
            keccak256(bytes("https://mockDaoURL.com"))
        );
    }
}
