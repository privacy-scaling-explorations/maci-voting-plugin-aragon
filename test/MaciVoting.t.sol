// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {AragonTest} from "./base/AragonTest.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";

abstract contract MaciVotingTest is AragonTest {
    DAO internal dao;
    MaciVoting internal plugin;
    MaciVotingSetup internal setup;
    uint256 internal constant NUMBER = 420;

    address internal maciAddress;
    DomainObjs.PublicKey internal coordinatorPublicKey;
    IMaciVoting.VotingSettings internal votingSettings;
    address internal verifier;
    address internal vkRegistry;
    address internal policyFactory;
    address internal checkerFactory;
    address internal voiceCreditProxyFactory;

    function setUp() public virtual {
        setup = new MaciVotingSetup();
        bytes memory setupData = abi.encode(maciAddress, coordinatorPublicKey, votingSettings, verifier, vkRegistry, policyFactory, checkerFactory, voiceCreditProxyFactory);

        (DAO _dao, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        dao = _dao;
        plugin = MaciVoting(_plugin);
    }
}

contract MaciVotingInitializeTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize() public {
        assertEq(address(plugin.dao()), address(dao));
    }

    function test_reverts_if_reinitialized() public {
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(dao, maciAddress, coordinatorPublicKey, votingSettings, verifier, vkRegistry, policyFactory, checkerFactory, voiceCreditProxyFactory);
    }
}
