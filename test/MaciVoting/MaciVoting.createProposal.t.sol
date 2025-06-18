// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";

import {MaciVoting} from "../../src/MaciVoting.sol";
import {Utils} from "../../script/Utils.sol";
import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_CreateProposal_Test is MaciVoting_Test_Base {
    function setUp() public override {
        super.setUp();
        // Uncomment this to check an existing deployed plugin
        // plugin = MaciVoting(0xA60187Ef04a44bcd06754E660bf78079f298fc02);
    }

    // FIXME: this test is not working
    function test_0_erc20votes_assigned() public {
        address voteToken = address(plugin.getVotingToken());

        (,, GovernanceERC20.MintSettings memory mintSettings) =
            Utils.getGovernanceTokenAndMintSettings();

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

    function test_createProposal_CreatesProposal() public {
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

    function test_createProposal_RevertWhen_NotEnoughVotingPower() public {
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
