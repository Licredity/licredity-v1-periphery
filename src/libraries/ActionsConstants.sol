// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title Action Constants
/// @notice Common constants used in actions
/// @dev Constants are gas efficient alternatives to their literal values
library ActionConstants {
    /// @notice used to signal that the recipient of an action should be the msgSender
    address internal constant MSG_SENDER = address(1);

    /// @notice used to signal that the recipient of an action should be the address(this)
    address internal constant ADDRESS_THIS = address(2);
}
