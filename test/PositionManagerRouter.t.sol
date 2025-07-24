// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PositionManager} from "src/PositionManager.sol";
import {Actions, ActionsData} from "src/types/Actions.sol";
import {Planner, Plan} from "./shared/Planner.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract PositionManagerWithUniswapV4Test is PeripheryDeployers {
    IPoolManager uniswapV4poolManager;
    PositionManager licredityManager;
    uint256 _deadline;

    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant PARASWAP = address(0x6A000F20005980200259B80c5102003040001068);

    function setUp() public {
        vm.createSelectFork("ETH", 22988866);
        uniswapV4poolManager = deployUniswapV4Core(address(0xabcd), hex"01");

        deployLicredity(address(0), address(uniswapV4poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);
        deployAndSetOracleMock();
        deployNonFungibleMock();

        licredityManager =
            new PositionManager(address(this), uniswapV4poolManager, address(0), IAllowanceTransfer(PERMIT2_ADDRESS));
        licredityManager.updatePoolWhitelist(address(licredity), true);

        _deadline = block.timestamp + 1;
    }

    function test_paraswap_router() public {
        licredityManager.updateRouterWhitelist(PARASWAP, true);

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(
            Actions.DYN_CALL,
            abi.encode(
                PARASWAP,
                0.05 ether,
                hex"e3ead59e000000000000000000000000000010036c0190e009a000d0fc3541100a07380a000000000000000000000000eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000b1a2bc2ec50000000000000000000000000000000000000000000000000000000000000ae70d98000000000000000000000000000000000000000000000000000000000ae87307562b41ad7cc4471faf9512ec145401bd000000000000000000000000015ec8420000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000000000000000000000000001600000000000000000000000000000000000000000000000000000000000000180000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000001a0000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001a09995855c00494d039ab6792f18e368e530dff9310000014000000000ff00000900000000000000000000000000000000000000000000000000000000f196187f0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000000000000000000000000d1b71758e21960000137e000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000b1a2bc2ec50000000000000000000000000000000000000000000000000000400065a8177fae27000000000000000000000000000000000000000000000000000000000000000080000000000000000000000000000000000000000000000000000000000000000000000000000000000000006a000f20005980200259b80c5102003040001068"
            )
        );

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{ value: 0.05 ether }(calls, _deadline);

        assertGe(IERC20(address(USDC)).balanceOf(address(this)), 0);
    }
}
