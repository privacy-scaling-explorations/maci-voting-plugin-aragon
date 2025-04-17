// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IMaciVoting {
    struct VotingSettings {
        uint32 minParticipation;
        uint64 minDuration;
        uint256 minProposerVotingPower;
    }
}
