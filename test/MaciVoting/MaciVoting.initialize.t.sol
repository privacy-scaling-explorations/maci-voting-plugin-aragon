// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IGovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/IGovernanceWrappedERC20.sol";

import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";
import {GovernanceWrappedERC20} from
    "@aragon/token-voting-plugin/ERC20/governance/GovernanceWrappedERC20.sol";

import {MaciVotingSetup} from "../../src/MaciVotingSetup.sol";
import {MaciVoting} from "../../src/MaciVoting.sol";
import {IMaciVoting} from "../../src/IMaciVoting.sol";
import {Utils} from "../../script/Utils.sol";
import {MaciVoting_Test_Base} from "./MaciVotingBase.t.sol";

contract MaciVoting_Initialize_Test is MaciVoting_Test_Base {
    function setUp() public override {
        super.setUp();
    }

    function test_initialize_InitializesPlugin() public view {
        assertEq(address(plugin.dao()), address(dao));
    }

    function test_initialize_RevertWhen_AlreadyInitialized() public {
        Utils.MaciEnvVariables memory maciEnvVariables = Utils.readMaciEnv();
        IMaciVoting.InitializationParams memory params = IMaciVoting.InitializationParams({
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
        vm.expectRevert("Initializable: contract is already initialized");
        plugin.initialize(params);
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
}
