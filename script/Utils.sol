// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import {Test} from "forge-std/Test.sol";
import {IDAO} from "@aragon/osx/core/plugin/PluginUUPSUpgradeable.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {Params} from "@maci-protocol/contracts/contracts/utilities/Params.sol";

import {IMaciVoting} from "../src/IMaciVoting.sol";
import {GovernanceERC20} from "../src/ERC20Votes/GovernanceERC20.sol";

library Utils {
    // the canonical hevm cheat‑code address
    Vm constant vm = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

    struct MaciEnvVariables {
        address maci;
        DomainObjs.PublicKey coordinatorPublicKey;
        IMaciVoting.VotingSettings votingSettings;
        address verifier;
        address verifyingKeysRegistry;
        address policyFactory;
        address checkerFactory;
        address voiceCreditProxyFactory;
        Params.TreeDepths treeDepths;
        uint8 messageBatchSize;
    }

    function parseMode(string memory mode) internal pure returns (DomainObjs.Mode) {
        if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("QV"))) {
            return DomainObjs.Mode.QV;
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("NON_QV"))) {
            return DomainObjs.Mode.NON_QV;
        } else if (keccak256(abi.encodePacked(mode)) == keccak256(abi.encodePacked("FULL"))) {
            return DomainObjs.Mode.FULL;
        } else {
            revert("Invalid mode string (expected QV, NON_QV, or FULL)");
        }
    }

    function readMaciEnv() public view returns (MaciEnvVariables memory maciEnvVariables) {
        maciEnvVariables.maci = vm.envAddress("MACI_ADDRESS");
        maciEnvVariables.coordinatorPublicKey = DomainObjs.PublicKey({
            x: vm.envUint("COORDINATOR_PUBLIC_KEY_X"),
            y: vm.envUint("COORDINATOR_PUBLIC_KEY_Y")
        });
        maciEnvVariables.votingSettings = IMaciVoting.VotingSettings(
            uint8(vm.envUint("MINIMUM_PARTICIPATION")),
            uint8(vm.envUint("MINIMUM_DURATION")),
            vm.envUint("MINIMUM_PROPOSER_VOTING_POWER"),
            uint8(vm.envUint("VOTE_OPTIONS")),
            parseMode(vm.envString("MODE"))
        );
        maciEnvVariables.verifier = vm.envAddress("VERIFIER_ADDRESS");
        maciEnvVariables.verifyingKeysRegistry = vm.envAddress("VERIFYING_KEY_REGISTRY_ADDRESS");
        maciEnvVariables.policyFactory = vm.envAddress("POLICY_FACTORY_ADDRESS");
        maciEnvVariables.checkerFactory = vm.envAddress("CHECKER_FACTORY_ADDRESS");
        maciEnvVariables.voiceCreditProxyFactory = vm.envAddress(
            "VOICE_CREDIT_PROXY_FACTORY_ADDRESS"
        );
        maciEnvVariables.treeDepths = Params.TreeDepths({
            tallyProcessingStateTreeDepth: uint8(vm.envUint("TALLY_PROCESSING_STATE_TREE_DEPTH")),
            voteOptionTreeDepth: uint8(vm.envUint("VOTE_OPTION_TREE_DEPTH")),
            stateTreeDepth: uint8(vm.envUint("STATE_TREE_DEPTH"))
        });
        maciEnvVariables.messageBatchSize = uint8(vm.envUint("MESSAGE_BATCH_SIZE"));
    }

    function getGovernanceTokenAndMintSettings()
        public
        returns (
            GovernanceERC20,
            GovernanceERC20.TokenSettings memory,
            GovernanceERC20.MintSettings memory
        )
    {
        GovernanceERC20.TokenSettings memory tokenSettings = GovernanceERC20.TokenSettings({
            name: "DAO Voting Token",
            symbol: "DVT"
        });
        GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20.MintSettings({
            receivers: new address[](3),
            amounts: new uint256[](3)
        });
        // local tests
        mintSettings.receivers[0] = address(0xB0b);
        mintSettings.amounts[0] = 1 * 10 ** 18;
        // Nico's address for UI tests
        mintSettings.receivers[1] = address(0xE4721A80C6e56f4ebeed6acEE91b3ee715e7dD64);
        mintSettings.amounts[1] = 5 * 10 ** 18;
        // John's address for UI tests
        mintSettings.receivers[2] = address(0x91AdDB0E8443C83bAf2aDa6B8157B38f814F0bcC);
        mintSettings.amounts[2] = 5 * 10 ** 18;

        GovernanceERC20 tokenToClone = new GovernanceERC20(
            IDAO(address(0x0)),
            tokenSettings.name,
            tokenSettings.symbol,
            mintSettings
        );
        return (tokenToClone, tokenSettings, mintSettings);
    }
}
