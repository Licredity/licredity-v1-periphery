// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {Hasher} from "../shared/Hasher.sol";
import {MockUniswapV4Router} from "../mocks/MockUniswapV4Router.sol";
import {MockUniswapV4Target} from "../mocks/MockUniswapV4Target.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract UniswapV4RouterTest is Test {
    event UnlockData(bytes unlockData);
    event ModifierLiquidity(uint256 indexed value, uint256 indexed deadline, bytes unlockData);
    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);

    MockUniswapV4Target swapTarget;
    MockUniswapV4Router swapCaller;
    Hasher swapParamsHash = Hasher.wrap(hex"");

    function setUp() public {
        swapTarget = new MockUniswapV4Target();
        swapCaller = new MockUniswapV4Router(address(swapTarget));
    }

    function test_fuzz_uniswapPoolManagerCall(bytes calldata unlockData) public {
        vm.expectEmit(true, false, false, true);
        emit UnlockData(unlockData);

        swapCaller.uniswapPoolManagerCall(unlockData);
    }

    function test_fuzz_uniswapPoolSwap(
        PoolKey memory key,
        IPoolManager.SwapParams memory params,
        bytes calldata hookData
    ) public {
        bytes memory swapParam = abi.encode(key, params, hookData);

        vm.expectEmit(true, false, false, true);
        emit Swap(key, params, hookData);

        swapCaller.uniswapPoolSwapCall(swapParam);
    }

    function test_fuzz_positionManagerCall(uint256 value, bytes calldata unlockData) public {
        vm.assume(value < address(this).balance);

        vm.expectEmit(true, true, false, true);
        emit ModifierLiquidity(value, block.timestamp, unlockData);

        swapCaller.positionManagerCall{value: value}(value, unlockData);
    }
}
