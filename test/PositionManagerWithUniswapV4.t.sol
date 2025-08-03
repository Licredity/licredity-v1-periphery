// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PositionManager} from "src/PositionManager.sol";
import {Actions, ActionsData} from "src/types/Actions.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IUniswapV4PositionManager} from "src/interfaces/external/IUniswapV4PositionManager.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {Planner, Plan} from "./shared/Planner.sol";
import {PositionPlanner, PositionPlan} from "./shared/PositionPlanner.sol";
import {SwapPlanner, SwapPlan} from "./shared/SwapPlanner.sol";
import {UniswapV4Actions} from "./shared/UniswapV4Actions.sol";
import {IERC721} from "@forge-std/interfaces/IERC721.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";

contract PositionManagerWithUniswapV4Test is PeripheryDeployers {
    IPoolManager uniswapV4poolManager;
    address uniswapV4PositionManager;
    PositionManager licredityManager;

    uint256 _deadline;
    uint24 private constant FEE = 100;
    int24 private constant TICK_SPACING = 1;
    uint160 private constant ONE_SQRT_PRICE_X96 = 0x1000000000000000000000000;

    PoolKey poolKey;

    function setUp() public {
        uniswapV4poolManager = deployUniswapV4Core(address(0xabcd), hex"01");
        deployLicredity(address(0), address(uniswapV4poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);

        deployAndSetOracleMock();

        poolKey = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(address(licredity)), FEE, TICK_SPACING, IHooks(address(licredity))
        );

        IAllowanceTransfer permit2 = IAllowanceTransfer(deployPermit2());
        uniswapV4PositionManager = deployUniswapV4PositionManager(
            address(uniswapV4poolManager), address(permit2), 100_000, address(0), address(0), hex"02"
        );

        licredityManager = new PositionManager(address(this), uniswapV4poolManager, uniswapV4PositionManager, permit2);
        licredityManager.updateTokenPermit2(
            address(licredity), uniswapV4PositionManager, type(uint160).max, type(uint48).max
        );
        licredityManager.updateLicredityMarketWhitelist(address(licredity), true);

        _deadline = block.timestamp + 1;
    }

    function test_initializeLiquidity() public {
        uint256 tokenId = licredityManager.mint(licredity);

        PositionPlan memory positionPlan = PositionPlanner.init();
        positionPlan.add(
            UniswapV4Actions.MINT_POSITION,
            abi.encode(
                poolKey,
                int24(-2),
                int24(2),
                uint256(10000.5 ether),
                uint128(1 ether),
                uint128(1 ether),
                address(this),
                bytes("")
            )
        );
        positionPlan.add(UniswapV4Actions.SETTLE_PAIR, abi.encode(poolKey.currency0, poolKey.currency1));
        positionPlan.add(UniswapV4Actions.SWEEP, abi.encode(address(0), address(this)));
        bytes memory positionManagerCalldata = positionPlan.encode();

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1.1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 1 ether));
        planner.add(Actions.UNISWAP_V4_POSITION_MANAGER_CALL, abi.encode(1 ether, positionManagerCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 2.1 ether}(calls, _deadline);
        assertEq(IERC721(uniswapV4PositionManager).ownerOf(1), address(this));
    }

    function test_swap() public {
        test_initializeLiquidity();

        uint256 tokenId = licredityManager.mint(licredity);

        SwapPlan memory swapPlan = SwapPlanner.init();

        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(-0.2 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });
        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));
        bytes memory swapCallData = swapPlan.finalizeSwap(poolKey.currency1, poolKey.currency0, address(this), false);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 0.5 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 0.2 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapCallData);
        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 0.5 ether}(calls, _deadline);
    }

    function test_swap_closePosition() public {
        test_initializeLiquidity();

        uint256 tokenId = licredityManager.mint(licredity);

        SwapPlan memory swapPlan = SwapPlanner.init();

        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: true,
            amountSpecified: int256(-0.02 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(-3)
        });

        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));
        // Use licredity position manager to pay for swap and receive debt token
        swapPlan.addSwap(poolKey.currency0, poolKey.currency1, ActionConstants.ADDRESS_THIS, false);
        swapPlan.add(Actions.UNISWAP_V4_SWEEP, abi.encode(address(0), ActionConstants.MSG_SENDER));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 0.02 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapPlan.encode());
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(false, 0.02 ether, false));
        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 0.5 ether}(calls, _deadline);
    }

    receive() external payable {}
}
