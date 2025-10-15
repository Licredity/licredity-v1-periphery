// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IPositionManagerConfig
/// @notice Interface for the positon manager configurations contract
interface IPositionManagerConfig {
    /// @notice Registers a router
    /// @param router The router address
    function updateRouterWhitelist(address router, bool isWhitelisted) external;

    /// @notice Approve the permit2 address for token
    /// @param token The token address
    /// @param spender The spender address
    /// @param amount The approved amount
    /// @param expiration The permit2 expiration
    function updateTokenPermit2(address token, address spender, uint160 amount, uint48 expiration) external;

    /// @notice Approve the spender for token
    /// @param token The token address
    /// @param spender The spender address
    /// @param amount The approved amount
    function updateTokenApporve(address token, address spender, uint256 amount) external;
}
