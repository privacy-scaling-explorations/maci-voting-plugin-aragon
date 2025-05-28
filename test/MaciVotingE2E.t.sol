// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {PluginRepo} from "@aragon/osx/framework/plugin/repo/PluginRepo.sol";
import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {AragonE2E} from "./base/AragonE2E.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";
import {Utils} from "../script/Utils.sol";

contract MaciVotingE2E is AragonE2E {
    DAO internal dao;
    MaciVoting internal plugin;
    PluginRepo internal repo;
    MaciVotingSetup internal setup;
    address internal unauthorised = account("unauthorised");

    function setUp() public virtual override {
        super.setUp();

        (
            GovernanceERC20 tokenToClone,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = Utils.getGovernanceTokenAndMintSettings();

        setup = new MaciVotingSetup(tokenToClone);
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

    function test_e2e() public {
        // test repo
        PluginRepo.Version memory version = repo.getLatestVersion(repo.latestRelease());
        assertEq(version.pluginSetup, address(setup));
        assertEq(version.buildMetadata, NON_EMPTY_BYTES);

        // test dao
        assertEq(keccak256(bytes(dao.daoURI())), keccak256(bytes("https://mockDaoURL.com")));
    }
}
