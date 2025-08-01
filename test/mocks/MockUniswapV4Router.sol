// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {UniswapV4Router} from "src/base/UniswapV4Router.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";

contract MockUniswapV4Router is UniswapV4Router {
    constructor(address _uniswapV4Mock) UniswapV4Router(IPoolManager(_uniswapV4Mock), _uniswapV4Mock) {}

    function positionManagerCall(uint256 positionValue, bytes calldata positionCalldata) external payable {
        _positionManagerCall(positionValue, positionCalldata);
    }

    function uniswapPoolManagerCall(bytes calldata swapCalldata) external {
        _uniswapPoolManagerCall(swapCalldata);
    }

    function uniswapPoolSwapCall(bytes calldata swapCalldata) external {
        _swap(swapCalldata);
    }

    function _pay(Currency token, address payer, address recipient, uint256 amount) internal override {}
}
