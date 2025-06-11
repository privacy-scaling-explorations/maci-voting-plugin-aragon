// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.29;

import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {MACI} from "@maci-protocol/contracts/contracts/MACI.sol";
import {IMACI} from "@maci-protocol/contracts/contracts/interfaces/IMACI.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {Tally} from "@maci-protocol/contracts/contracts/Tally.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";

import {AragonTest} from "./base/AragonTest.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {Utils} from "../script/Utils.sol";

abstract contract MaciVotingTest is AragonTest {
    DAO internal dao;
    MaciVoting internal plugin;
    MaciVotingSetup internal setup;
    uint256 internal forkId;

    function setUp() public virtual {
        vm.prank(address(0xB0b));
        forkId = vm.createFork(vm.envString("RPC_URL"));
        vm.selectFork(forkId);

        Utils.MaciEnvVariables memory maciEnvVariables = Utils.readMaciEnv();
        (
            GovernanceERC20 tokenToClone,
            MaciVotingSetup.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = Utils.getGovernanceTokenAndMintSettings();
        address maciVoting = address(new MaciVoting());

        setup = new MaciVotingSetup(tokenToClone, maciVoting);

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

        bytes memory setupData = abi.encode(params, tokenSettings, mintSettings);

        (DAO _dao, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        dao = _dao;
        plugin = MaciVoting(_plugin);

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
            abi.encodeWithSignature("tallyResults(uint256)", 0),
            abi.encode(yesValue, true)
        );
        vm.mockCall(
            pollContracts.tally,
            abi.encodeWithSignature("tallyResults(uint256)", 1),
            abi.encode(noValue, true)
        );
    }
}

contract MaciVotingInitializeTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize() public view {
        assertEq(address(plugin.dao()), address(dao));
    }

    function test_reverts_if_reinitialized() public {
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
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(params);
    }
}

contract MaciVotingProposalCreationTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
        // Uncomment this to check an existing deployed plugin
        // plugin = MaciVoting(0xA60187Ef04a44bcd06754E660bf78079f298fc02);
    }

    function test_0_erc20votes_assigned() public {
        address voteToken = address(plugin.getVotingToken());

        (, , GovernanceERC20.MintSettings memory mintSettings) = Utils
            .getGovernanceTokenAndMintSettings();

        uint256 totalTokens = 0;
        uint256 totalVotingPower = plugin.totalVotingPower(block.number - 1);

        address[] memory receivers = mintSettings.receivers;
        for (uint256 i = 0; i < receivers.length; i++) {
            uint256 balance = IVotesUpgradeable(voteToken).getVotes(receivers[i]);
            assertEq(balance, mintSettings.amounts[i], "Balance mismatch for receiver");

            totalTokens += balance;
        }
        assertEq(totalVotingPower, totalTokens);

        address unknownWallet = address(0x0A);
        uint256 unknownBalance = IVotesUpgradeable(voteToken).getVotes(unknownWallet);
        assertEq(unknownBalance, 0);
    }

    function test_1_createProposal() public {
        vm.startPrank(address(0xB0b));

        Action[] memory _actions = new Action[](1);
        _actions[0] = Action({to: address(0x0), value: 0, data: bytes("0x00")});
        bytes memory data = abi.encode(uint256(0), uint8(0), false);

        // Create a proposal
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });
        assertEq(plugin.getProposal(proposalId).parameters.snapshotBlock, block.number - 1);

        vm.stopPrank();
    }

    function test_2_createProposal_reverts_if_not_enough_voting_power() public {
        vm.startPrank(address(0x0A));

        if (plugin.minProposerVotingPower() == 0) {
            // we can always create a proposal
            return;
        }

        Action[] memory _actions = new Action[](1);
        _actions[0] = Action({to: address(0x0), value: 0, data: bytes("0x00")});

        bytes memory data = abi.encode(uint256(0), uint8(0), false);

        // Create a proposal
        vm.expectRevert(
            abi.encodeWithSelector(MaciVoting.ProposalCreationForbidden.selector, address(0x0A))
        );
        plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });

        vm.stopPrank();
    }
}

contract MaciVotingProposalExecutionTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
    }

    function test_execute_proposal() public {
        vm.startPrank(address(0xB0b));

        Action[] memory _actions = new Action[](1);
        _actions[0] = Action({to: address(0x0), value: 0, data: bytes("0x00")});
        bytes memory data = abi.encode(uint256(0), uint8(0), false);

        // Create a proposal
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });

        mockTallyResults(
            proposalId,
            900, // yes votes
            100 // no votes
        );

        plugin.execute(proposalId);

        vm.stopPrank();
    }

    function test_execute_proposal_reverts_if_not_enough_votes() public {
        vm.startPrank(address(0xB0b));

        Action[] memory _actions = new Action[](1);
        _actions[0] = Action({to: address(0x0), value: 0, data: bytes("0x00")});
        bytes memory data = abi.encode(uint256(0), uint8(0), false);

        // Create a proposal
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });

        // Mock tally results with insufficient votes
        mockTallyResults(
            proposalId,
            100, // yes votes
            900 // no votes
        );

        vm.expectRevert(
            abi.encodeWithSelector(MaciVoting.ProposalExecutionForbidden.selector, proposalId)
        );
        plugin.execute(proposalId);

        vm.stopPrank();
    }
}

contract MaciVotingChangeCoordinatorPublicKeyTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
    }

    function test_change_coordinator_public_key() public {
        vm.startPrank(address(0xB0b));

        (uint256 oldX, uint256 oldY) = plugin.coordinatorPublicKey();

        DomainObjs.PublicKey memory newPublicKey = DomainObjs.PublicKey({x: oldX + 1, y: oldY + 1});

        // Encode the function call
        bytes memory callData = abi.encodeWithSignature(
            "changeCoordinatorPublicKey((uint256,uint256))",
            newPublicKey
        );
        // Create DAO action
        Action[] memory actions = new Action[](1);
        actions[0] = Action({
            to: address(plugin), // Target contract
            value: 0,
            data: callData
        });
        bytes memory data = abi.encode(uint256(0), uint8(0), false);

        // Create proposal with this action
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://change-coordinator-key"),
            _actions: actions,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 15 minutes),
            _data: data
        });

        mockTallyResults(
            proposalId,
            900, // yes votes
            100 // no votes
        );

        plugin.execute(proposalId);

        (uint256 updatedX, uint256 updatedY) = plugin.coordinatorPublicKey();
        assertEq(updatedX, newPublicKey.x);
        assertEq(updatedY, newPublicKey.y);

        vm.stopPrank();
    }

    function test_revert_change_if_caller_is_not_dao() public {
        vm.startPrank(address(0xB0b));

        (uint256 oldX, uint256 oldY) = plugin.coordinatorPublicKey();

        DomainObjs.PublicKey memory newPublicKey = DomainObjs.PublicKey({x: oldX + 1, y: oldY + 1});

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(plugin),
                address(0xB0b),
                plugin.CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID()
            )
        );
        plugin.changeCoordinatorPublicKey(newPublicKey);

        vm.stopPrank();
    }
}
