// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockCallFail {
    fallback() external payable {
        assembly {
            revert(0x00, 0x00)
        }
    }
}