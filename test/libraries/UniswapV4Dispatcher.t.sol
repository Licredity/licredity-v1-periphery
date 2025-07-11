// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {UniswapV4Dispatcher} from "src/libraries/UniswapV4Dispatcher.sol";
import {Hasher} from "../shared/Hasher.sol";
import {MockUniswapV4Swap} from "../mocks/MockUniswapV4Swap.sol";
import {MockUniswapV4SwapTarget} from "../mocks/MockUniswapV4SwapTarget.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract UniswapV4DispatcherTest is Test {
    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);

    MockUniswapV4SwapTarget swapTarget;
    MockUniswapV4Swap swapCaller;
    Hasher swapParamsHash = Hasher.wrap(hex"");

    function setUp() public {
        swapTarget = new MockUniswapV4SwapTarget();
        swapCaller = new MockUniswapV4Swap(address(swapTarget));
    }

    struct SwapParams {
        PoolKey key;
        IPoolManager.SwapParams params;
        bytes hookData;
    }

    function test_fuzz_multiSwapCall(SwapParams[] memory params) public {
        if (params.length == 0) {
            bytes[] memory swapParams = new bytes[](0);
            swapCaller.multiSwapCall(swapParams);
        } else {
            bytes[] memory swapParams = new bytes[](params.length);
            for (uint256 i = 0; i < params.length; i++) {
                swapParams[i] = abi.encode(params[i].key, params[i].params, params[i].hookData);
                swapParamsHash = swapParamsHash.update(swapParams[i]);
            }

            vm.expectEmit(false, false, false, true);
            emit Swap(params[0].key, params[0].params, params[0].hookData);
            swapCaller.multiSwapCall(swapParams);
            assertEq(swapTarget.swapCounter(), params.length);
            assertEq(Hasher.unwrap(swapTarget.swapParamsTargetHash()), Hasher.unwrap(swapParamsHash));
        }
    }
}
