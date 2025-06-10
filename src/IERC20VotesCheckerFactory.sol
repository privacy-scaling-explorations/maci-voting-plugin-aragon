// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title IERC20VotesCheckerFactory
/// @notice Factory contract for deploying ERC20 votes checkers.
/// @dev Provides methods for clone deployment and related events.
interface IERC20VotesCheckerFactory {
    /// @notice Deploys a new clone contract.
    /// @dev This function should be implemented by the factory contract.
    function deploy(
        address _token,
        uint256 _snapshotBlock,
        uint256 _threshold
    ) external returns (address);
}
