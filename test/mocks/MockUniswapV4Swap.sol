// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV4Dispatcher} from "src/libraries/UniswapV4Dispatcher.sol";

contract MockUniswapV4Swap {
    address public uniswapV4PoolManager;

    constructor(address _uniswapV4PoolManager) {
        uniswapV4PoolManager = _uniswapV4PoolManager;
    }

    function multiSwapCall(bytes[] calldata swapParams) external {
        UniswapV4Dispatcher.multiSwapCall(uniswapV4PoolManager, swapParams);
    }
}
