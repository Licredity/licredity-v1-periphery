// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IPositionManagerConfig
/// @notice Interface for the positon manager configurations contract
interface IPositionManagerConfig {
    /// @notice Emitted when the next governor is appointed
    /// @param nextGovernor The next governor
    event AppointNextGovernor(address indexed nextGovernor);

    /// @notice Emitted when the next governor is confirmed
    /// @param lastGovernor The last governor
    /// @param newGovernor The new governor
    event ConfirmNextGovernor(address indexed lastGovernor, address indexed newGovernor);

    /// @notice Emitted when the pool is whitelisted
    /// @param pool The pool
    /// @param isWhitelisted Whether the pool is whitelisted
    event UpdatePoolWhitelist(address indexed pool, bool isWhitelisted);

    /// @notice Emitted when the router is whitelisted
    /// @param router The router
    /// @param isWhitelisted Whether the router is whitelisted
    event UpdateRouterWhitelist(address indexed router, bool isWhitelisted);

    /// @notice Registers a pool
    /// @param pool The hook address
    function updateLicredityMarketWhitelist(address pool, bool isWhitelisted) external;

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
