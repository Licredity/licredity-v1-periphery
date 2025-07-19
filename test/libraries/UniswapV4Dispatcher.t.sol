// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {UniswapV4Dispatcher} from "src/libraries/UniswapV4Dispatcher.sol";
import {Hasher} from "../shared/Hasher.sol";
import {MockUniswapV4Dispatcher} from "../mocks/MockUniswapV4Dispatcher.sol";
import {MockUniswapV4Target} from "../mocks/MockUniswapV4Target.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";

contract UniswapV4DispatcherTest is Test {
    event Swap(PoolKey key, IPoolManager.SwapParams params, bytes hookData);
    event ModifierLiquidity(uint256 indexed value, uint256 indexed deadline, bytes unlockData);

    MockUniswapV4Target swapTarget;
    MockUniswapV4Dispatcher swapCaller;
    Hasher swapParamsHash = Hasher.wrap(hex"");

    function setUp() public {
        swapTarget = new MockUniswapV4Target();
        swapCaller = new MockUniswapV4Dispatcher(address(swapTarget));
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

    struct Plan {
        bytes actions;
        bytes[] params;
    }

    function test_fuzz_positionManagerCall(uint256 value, bytes calldata unlockData) public {
        vm.assume(value < address(this).balance);

        vm.expectEmit(true, true, false, true);
        emit ModifierLiquidity(value, block.timestamp, unlockData);

        swapCaller.positionManagerCall{value: value}(value, unlockData);
    }
}
