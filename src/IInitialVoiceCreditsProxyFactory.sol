// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

/// @title IInitialVoiceCreditsProxyFactory
/// @notice Factory contract for deploying initial voice credits proxies.
/// @dev Provides methods for clone deployment and related events.
interface IInitialVoiceCreditsProxyFactory {
    /// @notice Deploys a new clone contract.
    /// @dev This function should be implemented by the factory contract.
    /// @param _snapshotBlock The snapshot block number.
    /// @param _token The token to deploy the proxy for.
    /// @param _factor The factor to scale down.
    function deploy(uint256 _snapshotBlock, address _token, uint256 _factor)
        external
        returns (address);
}
