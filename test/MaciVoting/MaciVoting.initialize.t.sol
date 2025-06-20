// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IGovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/IGovernanceWrappedERC20.sol";

import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";
import {GovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/GovernanceWrappedERC20.sol";
import {IPlugin} from "@aragon/osx-commons-contracts/src/plugin/IPlugin.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";

import {IMACI} from "@maci-protocol/contracts/contracts/interfaces/IMACI.sol";
import {MACI} from "@maci-protocol/contracts/contracts/MACI.sol";
import {Poll} from "@maci-protocol/contracts/contracts/Poll.sol";
import {IInitialVoiceCreditProxy} from
    "@maci-protocol/contracts/contracts/interfaces/IInitialVoiceCreditProxy.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {MaciVotingSetup} from "../../src/MaciVotingSetup.sol";
import {MaciVoting} from "../../src/MaciVoting.sol";
import {IMaciVoting} from "../../src/IMaciVoting.sol";
import {Utils} from "../../script/Utils.sol";
import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_Initialize_Test is MaciVoting_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize_RevertWhen_AlreadyInitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(initializationParams);
    }

    function test_initialize_InitializesPlugin() public view {
        assertEq(address(plugin.dao()), address(dao));
        IPlugin.TargetConfig memory targetConfig = plugin.getCurrentTargetConfig();
        assertEq(targetConfig.target, initializationParams.targetConfig.target);

        assertEq(uint8(targetConfig.operation), uint8(initializationParams.targetConfig.operation));
        assertEq(address(plugin.getVotingToken()), address(token));

        assertEq(address(plugin.maci()), initializationParams.maci);
        (uint256 x, uint256 y) = plugin.coordinatorPublicKey();
        assertEq(x, initializationParams.coordinatorPublicKey.x);
        assertEq(y, initializationParams.coordinatorPublicKey.y);

        (
            uint32 minParticipation,
            uint64 minDuration,
            uint256 minProposerVotingPower,
            uint8 voteOptions,
            DomainObjs.Mode mode
        ) = plugin.votingSettings();
        assertEq(minParticipation, initializationParams.votingSettings.minParticipation);
        assertEq(minDuration, initializationParams.votingSettings.minDuration);
        assertEq(
            minProposerVotingPower, initializationParams.votingSettings.minProposerVotingPower
        );
        assertEq(voteOptions, initializationParams.votingSettings.voteOptions);
        assertEq(uint8(mode), uint8(initializationParams.votingSettings.mode));

        assertEq(plugin.verifier(), initializationParams.verifier);
        assertEq(plugin.verifyingKeysRegistry(), initializationParams.verifyingKeysRegistry);
        assertEq(address(plugin.policyFactory()), initializationParams.policyFactory);
        assertEq(address(plugin.checkerFactory()), initializationParams.checkerFactory);
        assertEq(
            address(plugin.voiceCreditProxyFactory()), initializationParams.voiceCreditProxyFactory
        );

        (uint8 tallyProcessingStateTreeDepth, uint8 voteOptionTreeDepth, uint8 stateTreeDepth) =
            plugin.treeDepths();
        assertEq(
            tallyProcessingStateTreeDepth,
            initializationParams.treeDepths.tallyProcessingStateTreeDepth
        );
        assertEq(voteOptionTreeDepth, initializationParams.treeDepths.voteOptionTreeDepth);
        assertEq(stateTreeDepth, initializationParams.treeDepths.stateTreeDepth);
        assertEq(plugin.messageBatchSize(), initializationParams.messageBatchSize);
    }

    function test_initialize_Erc20VotesAssignedCorrectly() public {
        (,, GovernanceERC20.MintSettings memory mintSettings) =
            Utils.getGovernanceTokenAndMintSettings();

        uint256 totalTokens = 0;
        uint256 totalVotingPower = plugin.totalVotingPower(block.number - 1);

        address[] memory receivers = mintSettings.receivers;
        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 balance = IVotesUpgradeable(token).getVotes(receivers[i]);
            assertEq(balance, mintSettings.amounts[i], "Balance mismatch for receiver");

            totalTokens += balance;
        }
        assertEq(totalVotingPower, totalTokens);

        address unknownWallet = address(0x0A);
        uint256 unknownBalance = IVotesUpgradeable(token).getVotes(unknownWallet);
        assertEq(unknownBalance, 0);
    }

    function test_initialize_SetsUpGovernanceWrappedERC20() public {
        MaciVotingSetup.TokenSettings memory mockTokenSettings;
        GovernanceERC20.MintSettings memory mockMintSettings;
        IMaciVoting.InitializationParams memory mockParams;

        ERC20 erc20 = new ERC20("Test Token", "TEST");
        mockTokenSettings = MaciVotingSetup.TokenSettings({
            addr: address(erc20),
            name: "Wrapped Voting Token",
            symbol: "WVT"
        });

        bytes memory setupData = abi.encode(mockParams, mockTokenSettings, mockMintSettings);
        (, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        GovernanceWrappedERC20 wrappedToken =
            GovernanceWrappedERC20(address(MaciVoting(_plugin).getVotingToken()));

        assertEq(wrappedToken.name(), "Wrapped Voting Token");
        assertEq(wrappedToken.symbol(), "WVT");
        assertEq(ERC20(address(wrappedToken.underlying())).name(), "Test Token");
        assertEq(ERC20(address(wrappedToken.underlying())).symbol(), "TEST");

        assertFalse(setup.supportsIVotesInterface(address(erc20)));
        assertTrue(wrappedToken.supportsInterface(type(IGovernanceWrappedERC20).interfaceId));
        assertTrue(wrappedToken.supportsInterface(type(IVotesUpgradeable).interfaceId));
    }

    function test_initialize_SetsVoiceCreditFactorCorrectly() public {
        (,, GovernanceERC20.MintSettings memory mintSettings) =
            Utils.getGovernanceTokenAndMintSettings();

        // Create a proposal to deploy the `IInitialVoiceCreditProxy` instance
        vm.startPrank(address(0xB0b));
        Action[] memory _actions = new Action[](1);
        _actions[0] = Action({to: address(0x0), value: 0, data: bytes("0x00")});
        bytes memory data = abi.encode(uint256(0), uint8(0), false);
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });
        vm.stopPrank();
        vm.roll(block.number + 1);

        // Get the `IInitialVoiceCreditProxy` instance from the poll
        MaciVoting.Proposal memory proposal = plugin.getProposal(proposalId);
        IMACI.PollContracts memory pollContracts =
            MACI(maciEnvVariables.maci).getPoll(proposal.pollId);
        (,,,, IInitialVoiceCreditProxy initialVoiceCreditProxy) =
            Poll(pollContracts.poll).extContracts();

        address[] memory receivers = mintSettings.receivers;
        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 balance = IVotesUpgradeable(token).getVotes(receivers[i]);
            uint256 balanceNoDecimals = balance / 1e18;
            uint256 voiceCreditBalance =
                initialVoiceCreditProxy.getVoiceCredits(receivers[i], bytes("0x00"));
            assertEq(
                balanceNoDecimals, voiceCreditBalance, "Balance should equal voice credits 1-1"
            );
        }
    }
}
