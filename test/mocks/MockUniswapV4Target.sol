// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Hasher} from "../shared/Hasher.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {console} from "@forge-std/console.sol";

contract MockUniswapV4Target {
    Hasher public swapParamsTargetHash = Hasher.wrap(hex"");

    event UnlockData(bytes unlockData);
    event ModifierLiquidity(uint256 indexed value, uint256 indexed deadline, bytes unlockData);
    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);

    uint256 public swapCounter = 0;

    function unlock(bytes calldata unlockData) external payable {
        emit UnlockData(unlockData);
    }

    function modifyLiquidities(bytes calldata unlockData, uint256 deadline) external payable {
        emit ModifierLiquidity(msg.value, deadline, unlockData);
    }

    function swap(PoolKey memory key, IPoolManager.SwapParams memory params, bytes calldata hookData) external {
        emit Swap(key, params, hookData);
    }
}
