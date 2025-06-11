// SPDX-License-Identifier: MIT
pragma solidity 0.8.29;

import {Vm} from "forge-std/Test.sol";
import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {Params} from "@maci-protocol/contracts/contracts/utilities/Params.sol";
import {GovernanceERC20} from "@aragon/token-voting-plugin/ERC20/governance/GovernanceERC20.sol";

import {IMaciVoting} from "../src/IMaciVoting.sol";
import {MaciVotingSetup} from "../src/MaciVotingSetup.sol";

library Utils {
    // the canonical hevm cheat‑code address
    Vm public constant VM = Vm(address(bytes20(uint160(uint256(keccak256("hevm cheat code"))))));

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
            /* solhint-disable-next-line reason-string, gas-custom-errors */
            revert("Invalid mode string (expected QV, NON_QV, or FULL)");
        }
    }

    function readMaciEnv() public view returns (MaciEnvVariables memory maciEnvVariables) {
        maciEnvVariables.maci = VM.envAddress("MACI_ADDRESS");
        maciEnvVariables.coordinatorPublicKey = DomainObjs.PublicKey({
            x: VM.envUint("COORDINATOR_PUBLIC_KEY_X"),
            y: VM.envUint("COORDINATOR_PUBLIC_KEY_Y")
        });
        maciEnvVariables.votingSettings = IMaciVoting.VotingSettings(
            uint8(VM.envUint("MINIMUM_PARTICIPATION")),
            uint8(VM.envUint("MINIMUM_DURATION")),
            VM.envUint("MINIMUM_PROPOSER_VOTING_POWER"),
            uint8(VM.envUint("VOTE_OPTIONS")),
            parseMode(VM.envString("MODE"))
        );
        maciEnvVariables.verifier = VM.envAddress("VERIFIER_ADDRESS");
        maciEnvVariables.verifyingKeysRegistry = VM.envAddress("VERIFYING_KEY_REGISTRY_ADDRESS");
        maciEnvVariables.policyFactory = VM.envAddress("POLICY_FACTORY_ADDRESS");
        maciEnvVariables.checkerFactory = VM.envAddress("CHECKER_FACTORY_ADDRESS");
        maciEnvVariables.voiceCreditProxyFactory = VM.envAddress("VOICE_CREDIT_PROXY_FACTORY_ADDRESS");
        maciEnvVariables.treeDepths = Params.TreeDepths({
            tallyProcessingStateTreeDepth: uint8(VM.envUint("TALLY_PROCESSING_STATE_TREE_DEPTH")),
            voteOptionTreeDepth: uint8(VM.envUint("VOTE_OPTION_TREE_DEPTH")),
            stateTreeDepth: uint8(VM.envUint("STATE_TREE_DEPTH"))
        });
        maciEnvVariables.messageBatchSize = uint8(VM.envUint("MESSAGE_BATCH_SIZE"));
    }

    function getGovernanceTokenAndMintSettings()
        public
        returns (GovernanceERC20, MaciVotingSetup.TokenSettings memory, GovernanceERC20.MintSettings memory)
    {
        MaciVotingSetup.TokenSettings memory tokenSettings = MaciVotingSetup.TokenSettings({
            addr: address(0), // If set to `address(0)`, a new `GovernanceERC20` token is deployed
            name: VM.envString("TOKEN_NAME"),
            symbol: VM.envString("TOKEN_SYMBOL")
        });
        GovernanceERC20.MintSettings memory mintSettings = GovernanceERC20.MintSettings({
            receivers: new address[](3),
            amounts: new uint256[](3)
        });

        address[] memory receivers = VM.envAddress("MINT_SETTINGS_RECEIVERS", ",");
        uint256 amount = VM.envUint("MINT_SETTINGS_AMOUNT");
        mintSettings.receivers = receivers;
        mintSettings.amounts = new uint256[](receivers.length);
        for (uint256 i = 0; i < receivers.length; i++) {
            mintSettings.amounts[i] = amount;
        }

        GovernanceERC20 tokenToClone = new GovernanceERC20(
            IDAO(address(0x0)),
            tokenSettings.name,
            tokenSettings.symbol,
            mintSettings
        );
        return (tokenToClone, tokenSettings, mintSettings);
    }
}
