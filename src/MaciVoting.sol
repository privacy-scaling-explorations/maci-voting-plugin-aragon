// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {PluginUUPSUpgradeable} from
    "@aragon/osx-commons-contracts/src/plugin/PluginUUPSUpgradeable.sol";
import {_applyRatioCeiled} from "@aragon/osx-commons-contracts/src/utils/math/Ratio.sol";
import {ProposalUpgradeable} from
    "@aragon/osx-commons-contracts/src/plugin/extensions/proposal/ProposalUpgradeable.sol";
import {IProposal} from
    "@aragon/osx-commons-contracts/src/plugin/extensions/proposal/IProposal.sol";
import {Action} from "@aragon/osx-commons-contracts/src/executors/IExecutor.sol";

import {SafeCastUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/math/SafeCastUpgradeable.sol";
import {IVotesUpgradeable} from
    "@openzeppelin/contracts-upgradeable/governance/utils/IVotesUpgradeable.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {MACI} from "@maci-protocol/contracts/contracts/MACI.sol";
import {DomainObjs} from "@maci-protocol/contracts/contracts/utilities/DomainObjs.sol";
import {Tally} from "@maci-protocol/contracts/contracts/Tally.sol";
import {ITally} from "@maci-protocol/contracts/contracts/interfaces/ITally.sol";
import {IMACI} from "@maci-protocol/contracts/contracts/interfaces/IMACI.sol";
import {Params} from "@maci-protocol/contracts/contracts/utilities/Params.sol";
import {IPolicy} from "@excubiae/contracts/contracts/interfaces/IPolicy.sol";

import {IMaciVoting} from "./IMaciVoting.sol";
import {IERC20VotesCheckerFactory} from "./IERC20VotesCheckerFactory.sol";
import {IERC20VotesPolicyFactory} from "./IERC20VotesPolicyFactory.sol";
import {IInitialVoiceCreditsProxyFactory} from "./IInitialVoiceCreditsProxyFactory.sol";

/// @title MaciVoting
/// @dev Release 1, Build 1
/// @notice Each voter gets voting power based on their token balance snapshot
/// Voters can vote for option 0 or 1 (yes or no)
/// Abstain - signed up but not voted (needs changes in the MACI protocol to keep track of that)
/// What about minimum participation?
contract MaciVoting is PluginUUPSUpgradeable, ProposalUpgradeable, IMaciVoting {
    using SafeCastUpgradeable for uint256;

    /// @notice The [ERC-165](https://eips.ethereum.org/EIPS/eip-165) interface ID of the contract.
    bytes4 internal constant MACI_VOTING_INTERFACE_ID = this.initialize.selector
        ^ this.minProposerVotingPower.selector ^ this.totalVotingPower.selector
        ^ this.getVotingToken.selector ^ this.minParticipation.selector ^ this.minDuration.selector
        ^ this.getProposal.selector ^ this.changeCoordinatorPublicKey.selector;

    /// @notice The ID of the permission required to call the
    /// `changeCoordinatorPublicKey` function.
    bytes32 public constant CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID =
        keccak256("CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID");

    /// @notice An
    /// [OpenZeppelin `Votes`](https://docs.openzeppelin.com/contracts/4.x/api/governance#Votes)
    /// compatible contract referencing the token being used for voting.
    IVotesUpgradeable private votingToken;

    /// @notice The factor to scale down the voice credits.
    uint256 private voiceCreditFactor;

    /// @notice The address of the maci contract.
    MACI public maci;

    /// @notice The coordinator public key.
    /// @dev We do not allow it to be passed per poll as we want the DAO to control this for now
    DomainObjs.PublicKey public coordinatorPublicKey;

    /// @notice The voting settings.
    VotingSettings public votingSettings;

    /// @notice A mapping between proposal IDs and proposal information.
    mapping(uint256 => Proposal) internal proposals;

    /// @notice The policy factory for the polls
    IERC20VotesPolicyFactory public policyFactory;
    /// @notice The checker factory for the polls
    IERC20VotesCheckerFactory public checkerFactory;
    /// @notice The voice credit proxy factory for the polls
    IInitialVoiceCreditsProxyFactory public voiceCreditProxyFactory;

    /// @notice The verifier for the polls
    address public verifier;
    /// @notice The vk registry for the polls
    address public verifyingKeysRegistry;

    /// @notice The tree depths for the polls
    Params.TreeDepths public treeDepths;

    /// @notice The message batch size for the polls
    uint8 public messageBatchSize;

    /// @notice Thrown if the proposal with same actions and metadata already exists.
    /// @param proposalId The id of the proposal.
    error ProposalAlreadyExists(uint256 proposalId);
    /// @notice Thrown when a sender is not allowed to create a proposal.
    /// @param _address The sender address.
    error ProposalCreationForbidden(address _address);
    /// @notice Thrown if the proposal execution is forbidden.
    /// @param proposalId The ID of the proposal.
    error ProposalExecutionForbidden(uint256 proposalId);
    /// @notice Thrown when a proposal doesn't exist.
    /// @param proposalId The ID of the proposal which doesn't exist.
    error NonexistentProposal(uint256 proposalId);
    /// @notice Thrown when the caller doesn't have enough voting power.
    error NoVotingPower();
    /// @notice Thrown when the proposal is not in the voting period.
    /// @param limit The bound limit (start or end date).
    /// @param actual The actual time.
    error DateOutOfBounds(uint64 limit, uint64 actual);

    /// @notice Emitted when the coordinator public key is changed.
    /// @param oldCoordinatorPublicKey The previous coordinator public key.
    /// @param newCoordinatorPublicKey The new coordinator public key.
    event CoordinatorKeyChanged(
        DomainObjs.PublicKey oldCoordinatorPublicKey, DomainObjs.PublicKey newCoordinatorPublicKey
    );

    /// @notice Disables the initializers on the implementation contract to prevent
    /// it from being left uninitialized.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /// @notice Initializes the plugin when build 1 is installed.
    /// @param _params The initialization parameters. Check `src/IMaciVoting`
    function initialize(IMaciVoting.InitializationParams memory _params) external initializer {
        __PluginUUPSUpgradeable_init(_params.dao);
        _setTargetConfig(_params.targetConfig);

        votingToken = _params.token;
        // set voiceCreditFactor equal to number of decimals so 1 token = 1 voice credit
        voiceCreditFactor = 10 ** IERC20Metadata(address(votingToken)).decimals();

        maci = MACI(_params.maci);
        coordinatorPublicKey = _params.coordinatorPublicKey;
        votingSettings = _params.votingSettings;
        verifier = _params.verifier;
        verifyingKeysRegistry = _params.verifyingKeysRegistry;
        policyFactory = IERC20VotesPolicyFactory(_params.policyFactory);
        checkerFactory = IERC20VotesCheckerFactory(_params.checkerFactory);
        voiceCreditProxyFactory = IInitialVoiceCreditsProxyFactory(_params.voiceCreditProxyFactory);
        treeDepths = _params.treeDepths;
        messageBatchSize = _params.messageBatchSize;
    }

    /// @notice Checks if this or the parent contract supports an interface by its ID.
    /// @param _interfaceId The ID of the interface.
    /// @return Returns `true` if the interface is supported.
    function supportsInterface(bytes4 _interfaceId)
        public
        view
        override(PluginUUPSUpgradeable, ProposalUpgradeable)
        returns (bool)
    {
        return _interfaceId == MACI_VOTING_INTERFACE_ID || super.supportsInterface(_interfaceId);
    }

    /// @inheritdoc IProposal
    function customProposalParamsABI() external pure returns (string memory) {
        return "(uint256 allowFailureMap, uint8 voteOption, bool tryEarlyExecution)";
    }

    /// @notice Returns the minimum voting power required to create a proposal stored
    /// in the voting settings.
    /// @return The minimum voting power required to create a proposal.
    function minProposerVotingPower() public view returns (uint256) {
        return votingSettings.minProposerVotingPower;
    }

    /// @notice Returns the total voting power at a specific block number.
    /// @param _blockNumber The block number to query the total voting power at.
    /// @return The total voting power (token supply) at the specified block.
    function totalVotingPower(uint256 _blockNumber) public view returns (uint256) {
        return votingToken.getPastTotalSupply(_blockNumber);
    }

    /// @notice get the voting token interface
    /// @return The voting token
    function getVotingToken() public view returns (IVotesUpgradeable) {
        return votingToken;
    }

    /// @notice Returns the minimum participation of the proposal
    /// @return The minimum participation
    function minParticipation() public view returns (uint32) {
        return votingSettings.minParticipation;
    }

    /// @notice Returns the minimum duration of the proposal
    /// @return The minimum duration
    function minDuration() public view returns (uint64) {
        return votingSettings.minDuration;
    }

    /// @inheritdoc IProposal
    function hasSucceeded(uint256 _proposalId) external view returns (bool) {
        return proposals[_proposalId].executed;
    }

    /// @notice Returns the proposal data for a given proposal ID.
    /// @param _proposalId The ID of the proposal to retrieve.
    /// @return proposal_ The proposal data including execution status, parameters, tally results,
    /// actions, and other metadata.
    function getProposal(uint256 _proposalId) external view returns (Proposal memory proposal_) {
        proposal_ = proposals[_proposalId];
    }

    /// @notice Deploy a poll in MACI
    /// @param _startDate The start date of the proposal.
    /// @param _endDate The end date of the proposal.
    /// @param _minVotingPower The minimum voting power required to pass the proposal.
    function deployPoll(uint64 _startDate, uint64 _endDate, uint256 _minVotingPower)
        internal
        returns (uint256, IMACI.PollContracts memory)
    {
        address[] memory relayers = new address[](1);
        relayers[0] = address(0);

        address checker =
            checkerFactory.deploy(address(votingToken), block.number, _minVotingPower);
        address policy = policyFactory.deploy(checker);

        address initialVoiceCreditProxy =
            voiceCreditProxyFactory.deploy(block.number, address(votingToken), voiceCreditFactor);

        // Arguments to deploy a poll
        IMACI.DeployPollArgs memory deployPollArgs = IMACI.DeployPollArgs({
            startDate: _startDate,
            endDate: _endDate,
            treeDepths: treeDepths,
            messageBatchSize: messageBatchSize,
            coordinatorPublicKey: coordinatorPublicKey,
            verifier: verifier,
            verifyingKeysRegistry: verifyingKeysRegistry,
            mode: votingSettings.mode,
            policy: policy,
            initialVoiceCreditProxy: initialVoiceCreditProxy,
            relayers: relayers,
            voteOptions: votingSettings.voteOptions
        });

        uint256 pollId = IMACI(maci).nextPollId();
        IMACI.PollContracts memory pollContracts = IMACI(maci).deployPoll(deployPollArgs);
        IPolicy(policy).setTarget(pollContracts.poll);

        return (pollId, pollContracts);
    }

    /// @notice Validates and returns the proposal vote dates.
    /// @param _start The start date of the proposal vote. If 0, the current timestamp is used
    /// and the vote starts immediately.
    /// @param _end The end date of the proposal vote. If 0, `_start + minDuration` is used.
    /// @return startDate The validated start date of the proposal vote.
    /// @return endDate The validated end date of the proposal vote.
    function _validateProposalDates(uint64 _start, uint64 _end)
        internal
        view
        returns (uint64 startDate, uint64 endDate)
    {
        uint64 currentTimestamp = block.timestamp.toUint64();

        if (_start == 0) {
            startDate = currentTimestamp;
        } else {
            startDate = _start;

            if (startDate < currentTimestamp) {
                revert DateOutOfBounds({limit: currentTimestamp, actual: startDate});
            }
        }

        // Since `minDuration` is limited to 1 year, `startDate + minDuration` can only overflow if
        // the `startDate` is after `type(uint64).max - minDuration`. In this case, the proposal
        // creation will revert and another date can be picked.
        uint64 earliestEndDate = startDate + votingSettings.minDuration;

        if (_end == 0) {
            endDate = earliestEndDate;
        } else {
            endDate = _end;

            if (endDate < earliestEndDate) {
                revert DateOutOfBounds({limit: earliestEndDate, actual: endDate});
            }
        }
    }

    /// @dev Helper function to avoid stack too deep in non via-ir compilation mode.
    function _emitProposalCreatedEvent(
        bytes calldata _metadata,
        Action[] calldata _actions,
        uint256 _allowFailureMap,
        uint256 proposalId,
        uint64 _startDate,
        uint64 _endDate
    ) private {
        emit ProposalCreated(
            proposalId, _msgSender(), _startDate, _endDate, _metadata, _actions, _allowFailureMap
        );
    }

    /// @notice Creates a proposal.
    /// @param _metadata The metadata of the proposal.
    /// @param _actions The actions of the proposal.
    /// @param _startDate The start date of the proposal.
    /// @param _endDate The end date of the proposal.
    /// @param _data The data of the proposal.
    /// @return proposalId The ID of the proposal.
    function createProposal(
        bytes calldata _metadata,
        Action[] calldata _actions,
        uint64 _startDate,
        uint64 _endDate,
        bytes calldata _data
    ) public returns (uint256 proposalId) {
        (uint256 _allowFailureMap,,) = abi.decode(_data, (uint256, uint8, bool));

        // Check that either `_msgSender` owns enough tokens or has enough
        // voting power from being a delegatee.
        {
            uint256 minProposerVotingPower_ = minProposerVotingPower();

            if (minProposerVotingPower_ != 0) {
                // Because of the checks in `MaciVotingSetup`, we can assume that `votingToken`
                // is an [ERC-20](https://eips.ethereum.org/EIPS/eip-20) token.
                if (
                    votingToken.getVotes(_msgSender()) < minProposerVotingPower_
                        && IVotesUpgradeable(address(votingToken)).getVotes(_msgSender())
                            < minProposerVotingPower_
                ) {
                    revert ProposalCreationForbidden(_msgSender());
                }
            }
        }

        uint256 snapshotBlock;
        unchecked {
            // The snapshot block must be mined already to protect the transaction against
            // backrunning transactions causing census changes.
            snapshotBlock = block.number - 1;
        }
        uint256 totalVotingPower_ = totalVotingPower(snapshotBlock);

        if (totalVotingPower_ == 0) {
            revert NoVotingPower();
        }

        (_startDate, _endDate) = _validateProposalDates(_startDate, _endDate);

        proposalId = _createProposalId(keccak256(abi.encode(_actions, _metadata)));

        // Store proposal related information
        Proposal storage proposal_ = proposals[proposalId];

        if (_proposalExists(proposalId)) {
            revert ProposalAlreadyExists(proposalId);
        }

        {
            proposal_.parameters.startDate = _startDate;
            proposal_.parameters.endDate = _endDate;
            proposal_.parameters.snapshotBlock = snapshotBlock;
            proposal_.parameters.minVotingPower =
                _applyRatioCeiled(totalVotingPower_, minParticipation());

            // TODO: #24 (merge-ok) decide whether to include minApprovalPower and other
            // IMajorityVoting functionality
            // proposal_.minApprovalPower = _applyRatioCeiled(totalVotingPower_, minApproval());
            proposal_.targetConfig = getTargetConfig();

            (uint256 pollId, IMACI.PollContracts memory pollContracts) =
                deployPoll(_startDate, _endDate, proposal_.parameters.minVotingPower);

            proposal_.pollId = pollId;
            proposal_.pollAddress = pollContracts.poll;

            // Reduce costs
            if (_allowFailureMap != 0) {
                proposal_.allowFailureMap = _allowFailureMap;
            }

            for (uint256 i; i < _actions.length;) {
                proposal_.actions.push(_actions[i]);
                unchecked {
                    ++i;
                }
            }
        }

        _emitProposalCreatedEvent(
            _metadata, _actions, _allowFailureMap, proposalId, _startDate, _endDate
        );
    }

    /// @notice Internal function to check if a proposal can be executed. It assumes
    /// the queried proposal exists.
    /// @param _proposalId The ID of the proposal.
    /// @return True if the proposal can be executed, false otherwise.
    function _canExecute(uint256 _proposalId) internal view returns (bool) {
        Proposal storage proposal_ = proposals[_proposalId];

        IMACI.PollContracts memory pollContracts = maci.getPoll(proposal_.pollId);
        Tally tally_ = Tally(pollContracts.tally);

        // Verify that the proposal has not been executed already.
        if (proposal_.executed) {
            return false;
        }
        // Verify that the proposal poll has ended.
        if (!tally_.isTallied()) {
            return false;
        }
        // Check if the minimum participation threshold has been reached
        // based on final voting results.
        if (tally_.totalSpent() < proposal_.parameters.minVotingPower) {
            return false;
        }
        // Check if the support threshold has been reached based on final voting results.
        // yes -> voteOption = 0
        // no -> voteOption = 1

        ITally.TallyResult memory yesTallyResult = tally_.getTallyResults(0);
        ITally.TallyResult memory noTallyResult = tally_.getTallyResults(1);

        if (!noTallyResult.isSet || !yesTallyResult.isSet) {
            return false;
        }

        if (yesTallyResult.value < noTallyResult.value) {
            return false;
        }

        return true;
    }

    /// @notice Checks if proposal exists or not.
    /// @param _proposalId The ID of the proposal.
    /// @return Returns `true` if proposal exists, otherwise false.
    function _proposalExists(uint256 _proposalId) private view returns (bool) {
        return proposals[_proposalId].parameters.snapshotBlock != 0;
    }

    /// @inheritdoc IProposal
    function canExecute(uint256 _proposalId) public view returns (bool) {
        if (!_proposalExists(_proposalId)) {
            revert NonexistentProposal(_proposalId);
        }

        return _canExecute(_proposalId);
    }

    /// @inheritdoc IProposal
    function execute(uint256 _proposalId) external {
        if (!_canExecute(_proposalId)) {
            revert ProposalExecutionForbidden(_proposalId);
        }

        Proposal storage proposal_ = proposals[_proposalId];

        proposal_.executed = true;

        IMACI.PollContracts memory pollContracts = maci.getPoll(proposal_.pollId);
        Tally tally_ = Tally(pollContracts.tally);

        ITally.TallyResult memory noTallyResult = tally_.getTallyResults(0);
        ITally.TallyResult memory yesTallyResult = tally_.getTallyResults(1);
        // Save the results in the proposal struct for faster access
        proposal_.tally.yes = yesTallyResult.value;
        proposal_.tally.no = noTallyResult.value;

        _execute(
            proposal_.targetConfig.target,
            bytes32(_proposalId),
            proposal_.actions,
            proposal_.allowFailureMap,
            proposal_.targetConfig.operation
        );

        emit ProposalExecuted(_proposalId);
    }

    /// @notice Changes the coordinator public key. Only DAO (with an action) can call
    /// @param _coordinatorPublicKey The new coordinator public key.
    function changeCoordinatorPublicKey(DomainObjs.PublicKey calldata _coordinatorPublicKey)
        public
        auth(CHANGE_COORDINATOR_PUBLIC_KEY_PERMISSION_ID)
    {
        DomainObjs.PublicKey memory oldCoordinatorPublicKey = coordinatorPublicKey;
        coordinatorPublicKey = _coordinatorPublicKey;

        emit CoordinatorKeyChanged(oldCoordinatorPublicKey, _coordinatorPublicKey);
    }

    /// @dev This empty reserved space is put in place to allow future versions to add new
    /// variables without shifting down storage in the inheritance chain.
    /// https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
    uint256[49] private __gap;
}
