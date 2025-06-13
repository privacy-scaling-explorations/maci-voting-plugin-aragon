// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";

import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {Params} from "@maci-protocol/contracts/contracts/utilities/Params.sol";

interface IMaciVoting {
    struct InitializationParams {
        IDAO dao;
        IVotesUpgradeable token;
        address maci;
        DomainObjs.PublicKey coordinatorPublicKey;
        VotingSettings votingSettings;
        address verifier;
        address verifyingKeysRegistry;
        address policyFactory;
        address checkerFactory;
        address voiceCreditProxyFactory;
        Params.TreeDepths treeDepths;
        uint8 messageBatchSize;
    }

    struct VotingSettings {
        uint32 minParticipation;
        uint64 minDuration;
        uint256 minProposerVotingPower;
        uint8 voteOptions;
        DomainObjs.Mode mode;
    }
}
