// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {IProposal} from
    "@aragon/osx-commons-contracts/src/plugin/extensions/proposal/IProposal.sol";
import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";

import {MaciVoting} from "../../src/MaciVoting.sol";
import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_CreateProposal_Test is MaciVoting_Test_Base {
    uint256 internal allowFailureMap;

    bytes internal metadata;
    Action[] internal actions;
    uint64 internal startDate;
    uint64 internal endDate;
    bytes internal data;

    uint256 internal snapshotBlock;

    function setUp() public override {
        super.setUp();

        allowFailureMap = 0;

        metadata = bytes("ipfs://hello");
        actions.push(Action({to: address(0x0), value: 0, data: bytes("0x00")}));
        startDate = uint64(block.timestamp + 5 minutes);
        endDate = uint64(block.timestamp + 15 minutes);
        data = abi.encode(allowFailureMap, uint8(0), false);

        snapshotBlock = block.number - 1;
    }

    /**
     * @notice Based on internal function `_createProposalId`
     */
    function predictProposalId(Action[] memory _actions, bytes memory _metadata)
        private
        view
        returns (uint256)
    {
        return uint256(
            keccak256(
                abi.encode(
                    block.chainid,
                    block.number,
                    address(plugin),
                    keccak256(abi.encode(_actions, _metadata))
                )
            )
        );
    }

    function test_createProposal_RevertWhen_NotEnoughProposerVotingPower() public {
        address unauthorizedAddress = address(0x0A);
        vm.startPrank(unauthorizedAddress);

        vm.expectRevert(
            abi.encodeWithSelector(
                DaoUnauthorized.selector,
                address(dao),
                address(plugin),
                unauthorizedAddress,
                plugin.CREATE_PROPOSAL_PERMISSION_ID()
            )
        );
        plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: data
        });
    }

    function test_createProposal_RevertWhen_NoVotingPower() public {
        uint256 zeroVotingPower = 0;
        vm.startPrank(address(0xB0b));

        vm.mockCall(
            address(plugin.getVotingToken()),
            abi.encodeWithSelector(IVotesUpgradeable.getPastTotalSupply.selector, snapshotBlock),
            abi.encode(zeroVotingPower)
        );

        vm.expectRevert(MaciVoting.NoVotingPower.selector);
        plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: data
        });
    }

    function test_createProposal_RevertWhen_ProposalAlreadyExists() public {
        vm.startPrank(address(0xB0b));

        plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: data
        });

        uint256 predictedProposalId = predictProposalId(actions, metadata);

        vm.expectRevert(
            abi.encodeWithSelector(MaciVoting.ProposalAlreadyExists.selector, predictedProposalId)
        );
        plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: data
        });
    }

    function test_createProposal_CreatesProposal() public {
        vm.startPrank(address(0xB0b));

        uint256 predictedProposalId = predictProposalId(actions, metadata);

        vm.expectEmit();
        emit IProposal.ProposalCreated(
            predictedProposalId,
            address(0xB0b),
            startDate,
            endDate,
            metadata,
            actions,
            allowFailureMap
        );
        uint256 proposalId = plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: data
        });
        assertEq(plugin.getProposal(proposalId).parameters.snapshotBlock, snapshotBlock);
    }

    function test_createProposal_SetsAllowFailureMap() public {
        uint256 _allowFailureMap = 1;

        vm.startPrank(address(0xB0b));

        bytes memory dataWithFailureMap = abi.encode(_allowFailureMap, uint8(0), false);

        uint256 proposalId = plugin.createProposal({
            _metadata: metadata,
            _actions: actions,
            _startDate: startDate,
            _endDate: endDate,
            _data: dataWithFailureMap
        });

        assertEq(plugin.getProposal(proposalId).allowFailureMap, _allowFailureMap);
    }
}
