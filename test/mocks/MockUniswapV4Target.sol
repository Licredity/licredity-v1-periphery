// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hasher} from "../shared/Hasher.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {console} from "@forge-std/console.sol";

contract MockUniswapV4Target {
    Hasher public swapParamsTargetHash = Hasher.wrap(hex"");

    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);
    event ModifierLiquidityWithoutUnlock(uint256 indexed value, bytes actions, bytes[] params);

    uint256 public swapCounter = 0;

    function swap(PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData) external {
        swapParamsTargetHash = swapParamsTargetHash.update(abi.encode(key, params, hookData));
        swapCounter++;
        emit Swap(key, params, hookData);
    }

    function modifyLiquiditiesWithoutUnlock(bytes calldata actions, bytes[] calldata params) external payable {
        emit ModifierLiquidityWithoutUnlock(msg.value, actions, params);
    }
}
