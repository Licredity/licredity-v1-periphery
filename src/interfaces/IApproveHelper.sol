// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title IApproveHelper
/// @notice Interface for the approve helper contract
interface IApproveHelper {
    /// @notice Approve the permit2 address for token
    /// @param token The token address
    /// @param spender The spender address
    /// @param amount The approved amount
    /// @param expiration The permit2 expiration
    function approvePermit2(address token, address spender, uint160 amount, uint48 expiration) external;

    /// @notice Approve the spender for token
    /// @param token The token address
    /// @param spender The spender address
    /// @param amount The approved amount
    function approve(address token, address spender, uint256 amount) external;
}
