// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {IERC20Upgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";
import {GovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/GovernanceWrappedERC20.sol";

import {MACI} from "@maci-protocol/contracts/contracts/MACI.sol";
import {IMACI} from "@maci-protocol/contracts/contracts/interfaces/IMACI.sol";

import {AragonTest} from "../base/AragonTest.sol";
import {MaciVotingSetup} from "../../src/MaciVotingSetup.sol";
import {MaciVoting} from "../../src/MaciVoting.sol";
import {IMaciVoting} from "../../src/IMaciVoting.sol";
import {Utils} from "../../script/Utils.sol";

abstract contract MaciVoting_Test_Base is AragonTest {
    Utils.MaciEnvVariables internal maciEnvVariables;
    IMaciVoting.InitializationParams internal initializationParams;
    DAO internal dao;
    MaciVoting internal plugin;
    IVotesUpgradeable internal token;
    MaciVotingSetup internal setup;
    uint256 internal forkId;

    function setUp() public virtual {
        vm.prank(address(0xB0b));
        forkId = vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(forkId);

        maciEnvVariables = Utils.readMaciEnv();
        (
            GovernanceERC20 governanceERC20Base,
            MaciVotingSetup.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = Utils.getGovernanceTokenAndMintSettings();
        GovernanceWrappedERC20 governanceWrappedERC20Base =
            new GovernanceWrappedERC20(IERC20Upgradeable(address(0)), "", "");
        address maciVoting = address(new MaciVoting());

        setup = new MaciVotingSetup(governanceERC20Base, governanceWrappedERC20Base, maciVoting);

        initializationParams = IMaciVoting.InitializationParams({
            dao: IDAO(address(0)), // Set in MaciVotingSetup.prepareInstallation
            token: IVotesUpgradeable(address(0)), // Set in MaciVotingSetup.prepareInstallation
            maci: maciEnvVariables.maci,
            coordinatorPublicKey: maciEnvVariables.coordinatorPublicKey,
            votingSettings: maciEnvVariables.votingSettings,
            targetConfig: maciEnvVariables.targetConfig,
            verifier: maciEnvVariables.verifier,
            verifyingKeysRegistry: maciEnvVariables.verifyingKeysRegistry,
            policyFactory: maciEnvVariables.policyFactory,
            checkerFactory: maciEnvVariables.checkerFactory,
            voiceCreditProxyFactory: maciEnvVariables.voiceCreditProxyFactory,
            treeDepths: maciEnvVariables.treeDepths,
            messageBatchSize: maciEnvVariables.messageBatchSize
        });

        bytes memory setupData = abi.encode(initializationParams, tokenSettings, mintSettings);

        (DAO _dao, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        dao = _dao;
        plugin = MaciVoting(_plugin);
        token = plugin.getVotingToken();

        // Do we need to delegate votes? At the moment: doesnt look like it
        GovernanceERC20 voteToken = GovernanceERC20(address(plugin.getVotingToken()));
        voteToken.delegate(address(0xB0b));

        vm.roll(block.number + 1);
    }

    function mockTallyResults(uint256 proposalId, uint256 yesValue, uint256 noValue) public {
        MaciVoting.Proposal memory proposal = plugin.getProposal(proposalId);
        MACI maci = plugin.maci();
        IMACI.PollContracts memory pollContracts = maci.getPoll(proposal.pollId);

        // Mock the tally results for testing purposes
        vm.mockCall(pollContracts.tally, abi.encodeWithSignature("isTallied()"), abi.encode(true));
        vm.mockCall(
            pollContracts.tally,
            abi.encodeWithSignature("totalSpent()"),
            abi.encode(yesValue + noValue)
        );
        vm.mockCall(
            pollContracts.tally,
            abi.encodeWithSignature("getTallyResults(uint256)", 0),
            abi.encode(yesValue, true)
        );
        vm.mockCall(
            pollContracts.tally,
            abi.encodeWithSignature("getTallyResults(uint256)", 1),
            abi.encode(noValue, true)
        );
    }
}
