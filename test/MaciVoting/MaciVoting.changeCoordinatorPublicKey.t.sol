// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {DaoUnauthorized} from "@aragon/osx-commons-contracts/src/permission/auth/auth.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";

import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_ChangeCoordinatorPublicKey_Test is MaciVoting_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_changeCoordinatorPublicKey_ChangesPublicKey() public {
        vm.startPrank(address(0xB0b));

        (uint256 oldX, uint256 oldY) = plugin.coordinatorPublicKey();

        DomainObjs.PublicKey memory newPublicKey = DomainObjs.PublicKey({x: oldX + 1, y: oldY + 1});

        // Encode the function call
        bytes memory callData =
            abi.encodeWithSignature("changeCoordinatorPublicKey((uint256,uint256))", newPublicKey);
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

    function test_changeCoordinatorPublicKey_RevertWhen_CallerIsNotDao() public {
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
