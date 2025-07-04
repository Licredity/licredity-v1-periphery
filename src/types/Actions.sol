// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ActionsData {
    uint256 tokenId;
    bytes unlockData;
}

library Actions {
    uint256 public constant DEPOSIT_FUNGIBLE = 0x00;
    uint256 public constant DEPOSIT_NON_FUNGIBLE = 0x01;
    uint256 public constant WITHDRAW_FUNGIBLE = 0x02;
    uint256 public constant WITHDRAW_NON_FUNGIBLE = 0x03;
    uint256 public constant INCREASE_DEBT_AMOUNT = 0x04;
    uint256 public constant INCREASE_DEBT_SHARE = 0x05;
    uint256 public constant DECREASE_DEBT_AMOUNT = 0x06;
    uint256 public constant DECREASE_DEBT_SHARE = 0x07;
    uint256 public constant SEIZE = 0x08;
    uint256 public constant DYN_CALL = 0x09;
}
