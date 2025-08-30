// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityAccount} from "src/LicredityAccount.sol";
import {Actions} from "src/types/Actions.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {AccountPlan, AccountPlanner} from "./shared/AccountPlanner.sol";
import {SwapPlanner, SwapPlan} from "./shared/SwapPlanner.sol";
import {UniswapV4Actions} from "./shared/UniswapV4Actions.sol";
import {PositionPlanner, PositionPlan} from "./shared/PositionPlanner.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IHooks} from "@uniswap-v4-core/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap-v4-core/types/PoolKey.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {TickMath} from "@uniswap-v4-core/libraries/TickMath.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {BaseERC20Mock} from "@licredity-v1-test/utils/Deployer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible as FungibleMock} from "@licredity-v1-test/utils/Deployer.sol";

contract LicredityAccountExecuteTest is PeripheryDeployers {
    LicredityAccount account;
    LicredityAccount otherAccount;

    BaseERC20Mock testToken;

    uint24 private constant FEE = 100;
    int24 private constant TICK_SPACING = 1;
    uint160 private constant ONE_SQRT_PRICE_X96 = 0x1000000000000000000000000;
    PoolKey poolKey;
    address uniswapV4PositionManager;

    uint256 _deadline;

    function setUp() public {
        IPoolManager poolManager = deployUniswapV4Core(address(0xabcd), hex"01");
        deployLicredity(address(0), uint256(365), address(poolManager), address(this), "Debt ETH", "DETH");
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

        account = new LicredityAccount(address(this), poolManager, uniswapV4PositionManager, permit2);
        otherAccount = new LicredityAccount(address(this), poolManager, uniswapV4PositionManager, permit2);

        _deadline = block.timestamp + 1;
    }

    function test_licredityAccount_depositFungible() public {
        uint256 positionId = account.open(licredity);
        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 5 ether));

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(0)), 5 ether);

        account.execute{value: 5 ether}(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_depositNonFungible() public {
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(account), 1);

        uint256 positionId = account.open(licredity);
        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 1));

        account.execute(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_withdrawFungible(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);
        deal(address(this), amount);

        uint256 positionId = account.open(licredity);
        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), amount));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(address(0xb0b), address(0), amount));

        account.execute{value: amount}(licredity, planner.encode(), _deadline);

        assertEq(address(0xb0b).balance, amount);
    }

    function test_licredityAccount_withdrawNonFungible() public {
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(account), 1);

        uint256 positionId = account.open(licredity);
        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 1));
        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xb0b), address(nonFungibleMock), 1));

        account.execute(licredity, planner.encode(), _deadline);

        assertEq(nonFungibleMock.ownerOf(1), address(0xb0b));
    }

    function test_licredityAccount_debtAmount(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);

        uint256 positionId = account.open(licredity);
        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, amount));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(false, amount, false));

        account.execute(licredity, planner.encode(), _deadline);
    }

    function _getPosition(uint256 depositETHAmount, uint256 borrowETHAmount) internal returns (uint256 positionId) {
        positionId = otherAccount.open(licredity);

        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), depositETHAmount));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, borrowETHAmount));

        otherAccount.execute{value: depositETHAmount}(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_seize() public {
        uint256 seizedPosition = _getPosition(10 ether, 9.9 ether);
        oracleMock.setFungibleConfig(FungibleMock.wrap(address(0)), 0.9 ether, 1000); // 1000 / 1_000_000 = 0.1%

        AccountPlan memory planner = AccountPlanner.init();

        planner.add(Actions.SEIZE, abi.encode(seizedPosition));
        planner.add(Actions.SWITCH, abi.encode(seizedPosition));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1.5 ether));

        account.execute{value: 10 ether}(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_initializeLiquidity() public {
        uint256 positionId = account.open(licredity);

        account.updateTokenPermit2(address(licredity), uniswapV4PositionManager, type(uint160).max, type(uint48).max);

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

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1.1 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 1 ether));
        planner.add(Actions.UNISWAP_V4_POSITION_MANAGER_CALL, abi.encode(1 ether, positionManagerCalldata));
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(false, uniswapV4PositionManager, 1));
        account.execute{value: 2.1 ether}(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_swap() public {
        test_licredityAccount_initializeLiquidity();

        uint256 positionId = account.open(licredity);
        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(-0.2 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });
        SwapPlan memory swapPlan = SwapPlanner.init();

        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));

        bytes memory swapCallData = swapPlan.finalizeSwap(poolKey.currency1, poolKey.currency0, address(this), false);

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 0.5 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 0.2 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapCallData);

        account.execute{value: 0.5 ether}(licredity, planner.encode(), _deadline);
    }

    function swapDebtTokenToBase() internal {
        uint256 positionId = account.open(licredity);
        SwapPlan memory swapPlan = SwapPlanner.init();

        IPoolManager.SwapParams memory swapParam = IPoolManager.SwapParams({
            zeroForOne: false,
            amountSpecified: int256(0.02 ether),
            sqrtPriceLimitX96: TickMath.getSqrtPriceAtTick(3)
        });

        swapPlan.add(Actions.UNISWAP_V4_SWAP, abi.encode(poolKey, swapParam, bytes("")));
        swapPlan.addSwap(poolKey.currency1, poolKey.currency0, ActionConstants.ADDRESS_THIS, false);
        swapPlan.add(Actions.UNISWAP_V4_SWEEP, abi.encode(address(0), ActionConstants.ADDRESS_THIS)); 

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 0.03 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapPlan.encode());
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(false, address(0), ActionConstants.OPEN_DELTA));

        account.execute{value: 0.5 ether}(licredity, planner.encode(), _deadline);
    }

    function test_licredityAccount_swapDebtTokenToBase() public {
        test_licredityAccount_initializeLiquidity();
        swapDebtTokenToBase();
    }

    function test_licredityAccount_closePosition() public {
        test_licredityAccount_initializeLiquidity();
        swapDebtTokenToBase();

        uint256 positionId = account.open(licredity);
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

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.SWITCH, abi.encode(positionId));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.ADDRESS_THIS, 0.02 ether));
        planner.add(Actions.UNISWAP_V4_POOL_MANAGER_CALL, swapPlan.encode());
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(false, 0.02 ether, false));
        account.execute{value: 0.5 ether}(licredity, planner.encode(), _deadline);

        account.close(licredity, positionId);
    }

    receive() external payable {}
}
