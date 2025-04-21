// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.28;

import {IVotesUpgradeable} from "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {DAO} from "@aragon/osx/core/dao/DAO.sol";
import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";

import {DaoUnauthorized} from "@aragon/osx/core/utils/auth.sol";
import {AragonTest} from "./base/AragonTest.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";
import {MaciVoting} from "../src/MaciVoting.sol";
import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";
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

        (
            address maciAddress,
            DomainObjs.PublicKey memory coordinatorPublicKey,
            IMaciVoting.VotingSettings memory votingSettings,
            address verifier,
            address vkRegistry,
            address policyFactory,
            address checkerFactory,
            address voiceCreditProxyFactory
        ) = Utils.readMaciAddresses();
        (
            GovernanceERC20 tokenToClone,
            GovernanceERC20.TokenSettings memory tokenSettings,
            GovernanceERC20.MintSettings memory mintSettings
        ) = Utils.getGovernanceTokenAndMintSettings();

        setup = new MaciVotingSetup(tokenToClone);

        MaciVotingSetup.SetupMACIParams memory setupMaciParams = MaciVotingSetup.SetupMACIParams({
            maci: maciAddress,
            publicKey: coordinatorPublicKey,
            votingSettings: votingSettings,
            verifier: verifier,
            vkRegistry: vkRegistry,
            policyFactory: policyFactory,
            checkerFactory: checkerFactory,
            voiceCreditProxyFactory: voiceCreditProxyFactory
        });

        bytes memory setupData = abi.encode(setupMaciParams, tokenSettings, mintSettings);

        (DAO _dao, address _plugin) = createMockDaoWithPlugin(setup, setupData);

        dao = _dao;
        plugin = MaciVoting(_plugin);

        // Do we need to delegate votes? At the moment: doesnt look like it
        GovernanceERC20 voteToken = GovernanceERC20(address(plugin.getVotingToken()));
        voteToken.delegate(address(0xB0b));

        vm.roll(block.number + 1);
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
        (
            address maciAddress,
            DomainObjs.PublicKey memory coordinatorPublicKey,
            IMaciVoting.VotingSettings memory votingSettings,
            address verifier,
            address vkRegistry,
            address policyFactory,
            address checkerFactory,
            address voiceCreditProxyFactory
        ) = Utils.readMaciAddresses();
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(
            dao,
            maciAddress,
            coordinatorPublicKey,
            votingSettings,
            IVotesUpgradeable(address(0x0)),
            verifier,
            vkRegistry,
            policyFactory,
            checkerFactory,
            voiceCreditProxyFactory
        );
    }
}

contract MaciVotingProposalCreationTest is MaciVotingTest {
    function setUp() public override {
        super.setUp();
    }

    function test_createProposal() public {
        vm.prank(address(0xB0b));

        IDAO.Action[] memory _actions = new IDAO.Action[](1);
        _actions[0] = IDAO.Action({to: address(0x0), value: 0, data: bytes("0x00")});
        // Create a proposal
        uint256 proposalId = plugin.createProposal({
            _metadata: bytes("ipfs://hello"),
            _actions: _actions,
            _allowFailureMap: 0,
            _startDate: uint64(block.timestamp + 5 minutes),
            _endDate: uint64(block.timestamp + 1 days)
        });
        assertEq(plugin.proposalCount(), 1);
        assertEq(proposalId, 0);
    }

    function test_executeProposal() public {}
}
