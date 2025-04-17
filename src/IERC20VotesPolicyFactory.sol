// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/// @title IERC20VotesPolicyFactory
/// @notice Factory contract for deploying ERC20 votes policies.
/// @dev Provides methods for clone deployment and related events.
interface IERC20VotesPolicyFactory {
    /// @notice Deploys a new clone contract.
    /// @dev This function should be implemented by the factory contract.
    function deploy(address checker) external returns (address);
}
