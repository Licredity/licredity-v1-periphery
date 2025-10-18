// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {MockCallFail} from "./mocks/MockCallFail.sol";
import {MockUniswapV4Router} from "./mocks/MockUniswapV4Router.sol";
import {Test} from "@forge-std/Test.sol";

contract UniswapV4RouterTest is Test {
    error PositionManagerCallFail();
    error UniswapV4UnlockFail();
    error UniswapV4SwapFail();

    MockUniswapV4Router failRouter;
    MockCallFail mockCallFail;

    function setUp() public {
        mockCallFail = new MockCallFail();
        failRouter = new MockUniswapV4Router(address(mockCallFail));
    }

    function test_UniswapV4Router_FailPositionManagerCall() public {
        vm.expectRevert(PositionManagerCallFail.selector);
        failRouter.positionManagerCall(0, hex"deadbeef");
    }

    function test_UniswapV4Router_FailUniswapV4Unlock() public {
        vm.expectRevert(UniswapV4UnlockFail.selector);
        failRouter.uniswapPoolManagerCall(hex"deadbeef");
    }

    function test_UniswapV4Router_FailUniswapV4Swap() public {
        vm.expectRevert(UniswapV4SwapFail.selector);
        failRouter.swap(hex"deadbeef");
    }
}