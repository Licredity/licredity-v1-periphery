// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

struct ActionsData {
    uint256 tokenId;
    bytes unlockData;
}

struct UniswapV4ActionsData {
    uint256 positionCallValue;
    bytes positionCalldata;
    bytes[] swapParams;
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
    uint256 public constant EXCHANGE = 0x09;

    uint256 public constant SWITCH = 0x0a;

    uint256 public constant UNISWAP_V4_POSITION_MANAGER_CALL = 0x0b;
    uint256 public constant UNISWAP_V4_POOL_MANAGER_CALL = 0x0c;

    uint256 public constant UNISWAP_V4_SWAP = 0x0d;
    uint256 public constant UNISWAP_V4_TAKE = 0x0e;
    uint256 public constant UNISWAP_V4_SETTLE = 0x0f;
    uint256 public constant UNISWAP_V4_SWEEP = 0x10;

    uint256 public constant DYN_CALL = 0x11;
}
