// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IApproveHelper
/// @notice Interface for the approve helper contract
interface IApproveHelper {
    /// @notice Approve the permit2 address for token
    /// @param token The token address
    /// @param spender The spender address
    function approvePermit2(address token, address spender) external;

    /// @notice Approve the spender for token
    /// @param token The token address
    /// @param spender The spender address
    function approve(address token, address spender) external;
}
