// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityExecutor} from "src/LicredityExecutor.sol";
import {Actions} from "src/types/Actions.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {ILicredityExecutor} from "src/interfaces/ILicredityExecutor.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {ExecutePlan, ExecutePlanner} from "./shared/ExecutePlanner.sol";
import {SwapPlanner, SwapPlan} from "./shared/SwapPlanner.sol";
import {UniswapV4Actions} from "./shared/UniswapV4Actions.sol";
import {PositionPlanner, PositionPlan} from "./shared/PositionPlanner.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungibleLibrary} from "@licredity-v1-core/types/NonFungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {BaseERC20Mock} from "@licredity-v1-core/test/BaseERC20Mock.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract licredityExecutorTest is PeripheryDeployers {
    LicredityExecutor executor;

    BaseERC20Mock testToken;

    uint24 private constant FEE = 100;
    int24 private constant TICK_SPACING = 1;
    uint160 private constant ONE_SQRT_PRICE_X96 = 0x1000000000000000000000000;
    PoolKey poolKey;
    address uniswapV4PositionManager;

    uint256 _deadline;

    function setUp() public {
        IPoolManager poolManager = deployUniswapV4Core(address(0xabcd), hex"01");
        deployLicredity(address(0), address(poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);

        deployAndSetOracleMock();
        deployNonFungibleMock();

        testToken = _newAsset(18);

        IAllowanceTransfer permit2 = IAllowanceTransfer(deployPermit2());
        uniswapV4PositionManager = deployUniswapV4PositionManager(
            address(poolManager), address(permit2), 100_000, address(0), address(0), hex"02"
        );

        poolKey = PoolKey(
            Currency.wrap(address(0)), Currency.wrap(address(licredity)), FEE, TICK_SPACING, IHooks(address(licredity))
        );

        executor = new LicredityExecutor(poolManager, uniswapV4PositionManager, permit2);

        _deadline = block.timestamp + 1;
    }

    function test_licredityExecutor_depositFungible() public {
        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 5 ether));

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(0)), 5 ether);

        licredity.unlock{value: 5 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_depositNonFungible() public {
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(executor), 1);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(positionId, true, address(nonFungibleMock), 1));
        vm.expectEmit(true, true, false, false);
        emit ILicredity.DepositNonFungible(1, NonFungibleLibrary.from(address(nonFungibleMock), 1));

        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_withdrawFungible(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);
        deal(address(this), amount);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), amount));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(positionId, address(0xb0b), address(0), amount));

        licredity.unlock{value: amount}(address(executor), planner.encode(_deadline));

        assertEq(address(0xb0b).balance, amount);
    }

    function test_licredityExecutor_withdrawNonFungible() public {
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(executor), 1);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(positionId, true, address(nonFungibleMock), 1));
        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(positionId, address(0xb0b), address(nonFungibleMock), 1));

        licredity.unlock(address(executor), planner.encode(_deadline));

        assertEq(nonFungibleMock.ownerOf(1), address(0xb0b));
    }

    function _deposit() internal returns (uint256 positionId) {
        positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 10 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, 5 ether + 10011));

        licredity.unlock{value: 10 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_debtAmount(uint256 amount) public {
        amount = bound(amount, 1, 1000 ether - 1);

        _deposit();
        oracleMock.setQuotePrice(1.1 ether);
        skip(10000);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, amount));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(positionId, amount, false));

        licredity.unlock{value: 1 ether}(address(executor), planner.encode(_deadline + 10001));
    }

    function test_licredityExecutor_debtAmount_opendelta(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, amount));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.OPEN_DELTA, false));

        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_decreaseDebtAmountUsingBalance(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);
        IERC20(address(licredity)).approve(address(executor), amount);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, amount));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(licredity), amount));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(positionId, amount, true));

        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_debtShare(uint256 share) public {
        share = bound(share, 1e6, 9999 ether * 1e6); // 1e6 = 1 share

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 1 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(positionId, ActionConstants.MSG_SENDER, share + 1e6));
        planner.add(Actions.DECREASE_DEBT_SHARE, abi.encode(positionId, share, false));

        licredity.unlock{value: 1 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_debtShare_opendelta(uint256 share) public {
        share = bound(share, 1e6, 9999 ether * 1e6); // 1e6 = 1 share

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.EXCHANGE, abi.encode(false, ActionConstants.MSG_SENDER, 1 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(positionId, ActionConstants.MSG_SENDER, share + 1e6));
        planner.add(Actions.DECREASE_DEBT_SHARE, abi.encode(positionId, ActionConstants.OPEN_DELTA, false));

        licredity.unlock{value: 1 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_decreaseShareUsingBalance(uint256 share) public {
        share = bound(share, 1e6, 9999 ether * 1e6); // 1e6 = 1 share
        IERC20(address(licredity)).approve(address(executor), type(uint256).max);

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 1 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(positionId, ActionConstants.ADDRESS_THIS, share + 1e6));
        planner.add(
            Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, false, address(licredity), ActionConstants.OPEN_DELTA)
        );
        planner.add(Actions.DECREASE_DEBT_SHARE, abi.encode(positionId, share, true));

        licredity.unlock{value: 1 ether}(address(executor), planner.encode(_deadline));
    }

    function _getPosition(uint256 depositEthAmount, uint256 borrowEthAmount) internal returns (uint256 positionId) {
        positionId = licredity.openPosition();

        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), depositEthAmount));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, borrowEthAmount));

        licredity.unlock{value: depositEthAmount}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_seize() public {
        uint256 seizedPosition = _getPosition(10 ether, 9.9 ether);
        oracleMock.setFungibleConfig(Fungible.wrap(address(0)), 0.9 ether, 1000); // 1000 / 1_000_000 = 0.1%

        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.SEIZE, abi.encode(seizedPosition, ActionConstants.MSG_SENDER));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(seizedPosition, true, address(0), 1.5 ether));

        licredity.unlock{value: 10 ether}(address(executor), planner.encode(_deadline));
    }

    function initLiquidity(uint256 tokenId) public {
        uint256 positionId = licredity.openPosition();

        executor.approvePermit2(address(licredity), uniswapV4PositionManager);
        executor.approve(address(licredity), uniswapV4PositionManager);

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
                ActionConstants.MSG_SENDER,
                bytes("")
            )
        );
        positionPlan.add(UniswapV4Actions.SETTLE_PAIR, abi.encode(poolKey.currency0, poolKey.currency1));
        positionPlan.add(UniswapV4Actions.SWEEP, abi.encode(address(0), address(this)));
        bytes memory positionManagerCalldata = positionPlan.encode();

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 1.1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.ADDRESS_THIS, 1 ether));
        planner.add(Actions.UNISWAP_V4_POSITION_MANAGER_CALL, abi.encode(1 ether, positionManagerCalldata));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(positionId, false, uniswapV4PositionManager, tokenId));
        licredity.unlock{value: 2.1 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_initializeLiquidity() public {
        initLiquidity(1);
    }

    function test_licredityExecutor_initializeLiquidityByMapTokenId() public {
        initLiquidity(0);
    }

    function test_licredityExecutor_swap() public {
        initLiquidity(1);

        uint256 positionId = licredity.openPosition();
        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(-0.2 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });
        SwapPlan memory swapPlan = SwapPlanner.init();

        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));

        bytes memory swapCallData = swapPlan.finalizeSwap(poolKey.currency1, poolKey.currency0, address(this), false);

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(0), 0.5 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.ADDRESS_THIS, 0.2 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapCallData);

        licredity.unlock{value: 0.5 ether}(address(executor), planner.encode(_deadline));
    }

    function swapDebtTokenToBase() internal {
        uint256 positionId = licredity.openPosition();
        SwapPlan memory swapPlan = SwapPlanner.init();

        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(0.02 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });

        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));
        swapPlan.addSwap(poolKey.currency1, poolKey.currency0, ActionConstants.ADDRESS_THIS, false);
        swapPlan.add(Actions.UNISWAP_V4_SWEEP, abi.encode(address(0), ActionConstants.ADDRESS_THIS));

        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.ADDRESS_THIS, 0.03 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapPlan.encode());
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, false, address(0), ActionConstants.OPEN_DELTA));

        licredity.unlock{value: 0.5 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_swapDebtTokenToBase() public {
        initLiquidity(1);
        swapDebtTokenToBase();
    }

    function test_licredityExecutor_closePosition() public {
        initLiquidity(1);
        swapDebtTokenToBase();

        uint256 positionId = licredity.openPosition();
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

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(positionId, ActionConstants.MSG_SENDER, 0.02 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapPlan.encode());
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(positionId, 0.02 ether, false));
        licredity.unlock{value: 0.5 ether}(address(executor), planner.encode(_deadline));

        licredity.closePosition(positionId);
    }

    function test_licredityExecutor_exchange() public {
        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.EXCHANGE, abi.encode(false, ActionConstants.MSG_SENDER, 1 ether));
        licredity.unlock{value: 1 ether}(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_exchangeERC20() public {
        IPoolManager poolManager = deployUniswapV4Core(address(0xabcd), hex"02");
        deployLicredity(address(testToken), address(poolManager), address(this), "Debt TST", "DTST");

        testToken.mint(address(this), 1 ether);
        testToken.approve(address(executor), 1 ether);

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.EXCHANGE, abi.encode(true, ActionConstants.MSG_SENDER, 1 ether));
        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_deadlinePassed() public {
        ExecutePlan memory planner = ExecutePlanner.init();

        vm.warp(_deadline + 1);
        vm.expectRevert(abi.encodeWithSelector(ILicredityExecutor.DeadlinePassed.selector, _deadline));
        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    function test_licredityExecutor_NotSafeCallback() public {
        vm.expectRevert(abi.encodeWithSelector(ILicredityExecutor.NotSafeCallback.selector));
        executor.unlockCallback(hex"00");
    }

    function test_licredityExecutor_unknownAction() public {
        ExecutePlan memory planner = ExecutePlanner.init();

        planner.add(0xFF, abi.encode());

        vm.expectRevert(abi.encodeWithSelector(ILicredityExecutor.UnknownAction.selector, 0xFF));
        licredity.unlock(address(executor), planner.encode(_deadline));
    }

    receive() external payable {}
}
