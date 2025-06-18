// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";

import {MaciVoting} from "../../src/MaciVoting.sol";
import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_Execute_Test is MaciVoting_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_execute_ExecutesProposal() public {
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

    function test_execute_RevertWhen_NotEnoughVotes() public {
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
