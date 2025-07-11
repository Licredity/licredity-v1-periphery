// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hasher} from "../shared/Hasher.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract MockUniswapV4SwapTarget {
    Hasher public swapParamsTargetHash = Hasher.wrap(hex"");

    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);

    uint256 public swapCounter = 0;

    function swap(PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData) external {
        swapParamsTargetHash = swapParamsTargetHash.update(abi.encode(key, params, hookData));
        swapCounter++;
        emit Swap(key, params, hookData);
    }
}
