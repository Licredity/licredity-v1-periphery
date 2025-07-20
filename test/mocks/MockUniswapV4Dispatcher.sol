// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV4Dispatcher} from "src/libraries/UniswapV4Dispatcher.sol";

contract MockUniswapV4Dispatcher {
    address public uniswapV4Mock;

    constructor(address _uniswapV4Mock) {
        uniswapV4Mock = _uniswapV4Mock;
    }

    function uniswapPoolManagerCall(uint256 swapValue, bytes calldata swapCalldata) external payable {
        UniswapV4Dispatcher.uniswapPoolManagerCall(uniswapV4Mock, swapValue, swapCalldata);
    }

    function positionManagerCall(uint256 positionValue, bytes calldata positionCalldata) external payable {
        UniswapV4Dispatcher.positionManagerCall(uniswapV4Mock, positionValue, positionCalldata);
    }
}
