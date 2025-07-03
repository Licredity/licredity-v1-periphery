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

    /// @notice Registers a pool
    /// @param pool The hook address
    function updatePoolWhitelist(address pool, bool isWhitelisted) external;
}
