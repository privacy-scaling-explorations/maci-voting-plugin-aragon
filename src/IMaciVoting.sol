// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {IDAO} from "@aragon/osx-commons-contracts/src/dao/IDAO.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";
import {IPlugin} from "@aragon/osx-commons-contracts/src/plugin/IPlugin.sol";

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
        IPlugin.TargetConfig targetConfig;
        address verifier;
        address verifyingKeysRegistry;
        address policyFactory;
        address checkerFactory;
        address voiceCreditProxyFactory;
        Params.TreeDepths treeDepths;
        uint8 messageBatchSize;
    }

    /// @notice A struct containing the voting settings for proposals.
    /// @param minParticipation The minimum participation value.
    ///     Its value has to be in the interval [0, 10^6] defined by `RATIO_BASE = 10**6`.
    /// @param minDuration The minimum duration of the proposal vote in seconds.
    /// @param minProposerVotingPower The minimum voting power required to create a proposal.
    /// @param voteOptions The number of voting options available in the poll.
    /// @param mode The MACI mode for the poll (either QV, NON_QV, or FULL).
    struct VotingSettings {
        uint32 minParticipation;
        uint64 minDuration;
        uint256 minProposerVotingPower;
        uint8 voteOptions;
        DomainObjs.Mode mode;
    }

    /// @notice A container for the results of the voting. We read from the poll and
    /// store the results here.
    /// @param yes The number of votes for the "yes" option.
    /// @param no The number of votes for the "no" option.
    /// @param abstain The number of votes for the "abstain" option.
    struct TallyResults {
        uint256 yes;
        uint256 no;
        uint256 abstain;
    }

    // @notice Tally results struct that is implementd in Tally but not defined
    // in the interface ITally
    // @param flag Whether the tally value was initialized or not
    // @param value The tally value of an option
    struct TallyResult {
        bool flag;
        uint256 value;
    }

    /// @notice A container for the proposal parameters at the time of proposal creation.
    /// @param startDate The start date of the proposal vote.
    /// @param endDate The end date of the proposal vote.
    /// @param snapshotBlock The number of the block prior to the proposal creation.
    /// @param minVotingPower The minimum voting power needed.
    struct ProposalParameters {
        uint64 startDate;
        uint64 endDate;
        uint256 snapshotBlock;
        uint256 minVotingPower;
    }

    /// @notice A container for proposal-related information.
    /// @param executed Whether the proposal is executed or not.
    /// @param parameters The proposal parameters at the time of the proposal creation.
    /// @param actions The actions to be executed when the proposal passes.
    /// @param allowFailureMap A bitmap allowing the proposal to succeed, even if individual
    /// actions might revert. If the bit at index `i` is 1, the proposal succeeds even if the `i`th
    /// action reverts. A failure map value of 0 requires every action to not revert.
    /// @param targetConfig Configuration for the execution target, specifying the target address
    /// and operation type (either `Call` or `DelegateCall`). Defined by `TargetConfig` in the
    /// `IPlugin` interface,
    ///     part of the `osx-commons-contracts` package, added in build 3.
    /// @param pollId The ID of the MACI poll
    /// @param pollAddress The address of the MACI poll
    struct Proposal {
        bool executed;
        ProposalParameters parameters;
        TallyResults tally;
        Action[] actions;
        uint256 allowFailureMap;
        // TODO: #24 (merge-ok) decide whether to include minApprovalPower and other
        // IMajorityVoting functionality
        // uint256 minApprovalPower;
        IPlugin.TargetConfig targetConfig;
        uint256 pollId;
        address pollAddress;
    }

    function minProposerVotingPower() external view returns (uint256);
    function totalVotingPower(uint256 _blockNumber) external view returns (uint256);
    function getVotingToken() external view returns (IVotesUpgradeable);
    function minParticipation() external view returns (uint32);
    function minDuration() external view returns (uint64);
    function getProposal(uint256 _proposalId) external view returns (Proposal memory proposal_);
    function changeCoordinatorPublicKey(DomainObjs.PublicKey calldata _coordinatorPublicKey)
        external;
}
