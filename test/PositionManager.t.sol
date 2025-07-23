// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PositionManager} from "src/PositionManager.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {Actions, ActionsData} from "src/types/Actions.sol";
import {Plan, Planner} from "./shared/Planner.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {DynTargetMock} from "./mocks/DynTargetMock.sol";
import {IPositionManager} from "src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {BaseERC20Mock} from "@licredity-v1-test/utils/Deployer.sol";
import {Fungible as FungibleMock} from "@licredity-v1-test/utils/Deployer.sol";

contract PositionManagerTest is PeripheryDeployers {
    error NotMinted();
    error CallFailure();

    PositionManager manager;
    BaseERC20Mock testToken;

    uint256 _deadline;

    function setUp() public {
        IPoolManager poolManager = deployUniswapV4Core(address(0xabcd), hex"01");
        deployLicredity(address(0), address(poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);

        deployAndSetOracleMock();
        deployNonFungibleMock();

        testToken = _newAsset(18);

        IAllowanceTransfer permit2 = IAllowanceTransfer(deployPermit2());
        address uniswapV4PositionManager = deployUniswapV4PositionManager(
            address(poolManager), address(permit2), 100_000, address(0), address(0), hex"02"
        );

        manager = new PositionManager(address(this), poolManager, uniswapV4PositionManager, permit2);
        manager.updatePoolWhitelist(address(licredity), true);

        _deadline = block.timestamp + 1;

        oracleMock.setFungibleConfig(FungibleMock.wrap(address(testToken)), 1 ether, 100_000); // 10%
    }

    function test_mint_notWhitelist(ILicredity other) public {
        vm.assume(address(other) != address(licredity));

        vm.expectRevert(IPositionManager.PoolNotWhitelisted.selector);
        manager.mint(other);
    }

    function test_mint() public {
        vm.expectEmit(true, true, false, false);
        emit ILicredity.OpenPosition(1, address(manager));

        manager.mint(ILicredity(address(licredity)));

        assertEq(manager.ownerOf(1), address(this));
        assertEq(manager.nextTokenId(), 2);
    }

    function test_burn_notMint() public {
        vm.expectRevert(NotMinted.selector);
        manager.burn(1);
    }

    function test_burn_notApprove() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        vm.startPrank(address(1));
        vm.expectRevert(abi.encodeWithSelector(IPositionManager.NotApproved.selector, address(1)));
        manager.burn(tokenId);
        vm.stopPrank();
    }

    function test_burn() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        vm.expectEmit(true, false, false, false);
        emit ILicredity.ClosePosition(1);
        manager.burn(tokenId);
    }

    function test_depositFungible_native() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(0)), 0.1 ether);
        manager.depositFungible{value: 0.1 ether}(tokenId, address(0), 0.1 ether);
    }

    function test_depositFungible_erc20() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        testToken.mint(address(this), 10 ether);
        testToken.approve(address(manager), 10 ether);

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(testToken)), 10 ether);
        manager.depositFungible(tokenId, address(testToken), 10 ether);
    }

    function test_depositNonFungible() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(manager), 1);

        manager.depositNonFungible(tokenId, address(nonFungibleMock), 1);
    }

    function test_depositFungible_payIsUser() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        testToken.mint(address(this), 10 ether);
        testToken.approve(address(manager), 10 ether);

        Plan memory planner = Planner.init(tokenId);

        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 0.1 ether));
        ActionsData[] memory calls = planner.finalize();

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(testToken)), 0.1 ether);
        manager.execute(calls, _deadline);
    }

    function test_depositFungible_payIsManager() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        testToken.mint(address(manager), 10 ether);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(false, address(testToken), 10 ether));
        ActionsData[] memory calls = planner.finalize();

        vm.expectEmit(true, true, false, true);
        emit ILicredity.DepositFungible(1, Fungible.wrap(address(testToken)), 10 ether);
        manager.execute(calls, _deadline);
    }

    function test_depositNonFungible_payIsUser() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        nonFungibleMock.mint(address(this), 1);
        nonFungibleMock.approve(address(manager), 1);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(true, address(nonFungibleMock), 1));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);

        assertEq(nonFungibleMock.ownerOf(1), address(licredity));
    }

    function test_depositNonFungible_payIsManager() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        nonFungibleMock.mint(address(manager), 1);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(false, address(nonFungibleMock), 1));
        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);

        assertEq(nonFungibleMock.ownerOf(1), address(licredity));
    }

    function test_withdrawFungible_msgSender() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        testToken.mint(address(this), 100 ether);
        testToken.approve(address(manager), 100 ether);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 50 ether));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, address(testToken), 20 ether));

        ActionsData[] memory calls = planner.finalize();

        vm.expectEmit(true, true, true, true);
        emit ILicredity.WithdrawFungible(1, address(this), Fungible.wrap(address(testToken)), 20 ether);

        manager.execute(calls, _deadline);
        assertEq(testToken.balanceOf(address(this)), 70 ether);
    }

    function test_withdrawFungible_manager() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        testToken.mint(address(this), 100 ether);
        testToken.approve(address(manager), 100 ether);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 50 ether));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.ADDRESS_THIS, address(testToken), 20 ether));

        ActionsData[] memory calls = planner.finalize();

        vm.expectEmit(true, true, true, true);
        emit ILicredity.WithdrawFungible(1, address(manager), Fungible.wrap(address(testToken)), 20 ether);

        manager.execute(calls, _deadline);
        assertEq(testToken.balanceOf(address(manager)), 20 ether);
    }

    function test_withdrawFungible_other() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        testToken.mint(address(this), 100 ether);
        testToken.approve(address(manager), 100 ether);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 50 ether));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(address(0xc0de), address(testToken), 20 ether));

        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        assertEq(testToken.balanceOf(address(0xc0de)), 20 ether);
    }

    function test_withdrawNonFungible() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));
        nonFungibleMock.mint(address(manager), 1);

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_NON_FUNGIBLE, abi.encode(false, address(nonFungibleMock), 1));
        planner.add(Actions.WITHDRAW_NON_FUNGIBLE, abi.encode(address(0xc0de), address(nonFungibleMock), 1));

        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        assertEq(nonFungibleMock.ownerOf(1), address(0xc0de));
    }

    function test_increaseDebtAmount() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 100 ether));
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(ActionConstants.MSG_SENDER, 5 ether));

        ActionsData[] memory calls = planner.finalize();

        vm.expectEmit(true, true, false, true);
        emit ILicredity.IncreaseDebtShare(1, address(this), 5e24, 5e18);

        manager.execute{value: 100 ether}(calls, _deadline);
        assertEq(IERC20(address(licredity)).balanceOf(address(this)), 5 ether);
    }

    function test_increaseDebtShare() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 100 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(ActionConstants.MSG_SENDER, 5e24));

        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 100 ether}(calls, _deadline);
        assertEq(IERC20(address(licredity)).balanceOf(address(this)), 5 ether);
    }

    function test_decreaseDebtShare() public {
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 100 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(ActionConstants.ADDRESS_THIS, 5e24));
        planner.add(Actions.DECREASE_DEBT_SHARE, abi.encode(false, 5e24, false));
        planner.add(Actions.WITHDRAW_FUNGIBLE, abi.encode(ActionConstants.MSG_SENDER, address(0), 100 ether));

        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 100 ether}(calls, _deadline);
        assertEq(IERC20(address(licredity)).balanceOf(address(this)), 0);
    }

    function test_decreaseDebtShare_useBalance(uint256 shareDelta) public {
        shareDelta = bound(shareDelta, 1e6, 10000 ether * 1e6 - 1);
        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(0), 1 ether));
        planner.add(Actions.INCREASE_DEBT_SHARE, abi.encode(address(licredity), shareDelta));
        planner.add(Actions.DECREASE_DEBT_SHARE, abi.encode(false, shareDelta - 1e6, true));

        ActionsData[] memory calls = planner.finalize();

        manager.execute{value: 1 ether}(calls, _deadline);
        assertEq(IERC20(address(licredity)).balanceOf(address(this)), 0);
    }

    function test_decreaseDebtAmount(uint256 amount) public {
        amount = bound(amount, 1, 10000 ether - 1);

        uint256 tokenId = manager.mint(ILicredity(address(licredity)));

        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(address(licredity), amount));
        planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(false, amount, true));

        ActionsData[] memory calls = planner.finalize();

        manager.execute(calls, _deadline);
        assertEq(IERC20(address(licredity)).balanceOf(address(this)), 0);
    }

    // function test_dynCall(uint256 amount, uint128 value1, uint128 value2, bytes calldata data1, bytes calldata data2)
    //     public
    // {
    //     amount = bound(amount, 1, 10000 ether - 1);

    //     address target1 = address(new DynTargetMock());
    //     address target2 = address(new DynTargetMock());

    //     vm.deal(address(manager), uint256(value1) + uint256(value2));

    //     uint256 tokenId = manager.mint(ILicredity(address(licredity)));

    //     Plan memory planner = Planner.init(tokenId);
    //     planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(address(licredity), amount));
    //     planner.add(Actions.DYN_CALL, abi.encode(target1, value1, data1));
    //     planner.add(Actions.DYN_CALL, abi.encode(target2, value2, data2));
    //     planner.add(Actions.DECREASE_DEBT_AMOUNT, abi.encode(false, amount, true));

    //     ActionsData[] memory calls = planner.finalize();

    //     vm.expectCall(address(target1), value1, data1);
    //     vm.expectCall(address(target2), value2, data2);

    //     manager.execute(calls, _deadline);
    // }

    // function test_dynCall_fail(bytes calldata data) public {
    //     DynTargetMock target = new DynTargetMock();
    //     target.setShouldThrow(true);

    //     uint256 tokenId = manager.mint(ILicredity(address(licredity)));

    //     Plan memory planner = Planner.init(tokenId);
    //     planner.add(Actions.DYN_CALL, abi.encode(target, 0, data));
    //     ActionsData[] memory calls = planner.finalize();

    //     vm.expectRevert(CallFailure.selector);
    //     manager.execute(calls, _deadline);
    // }

    // function test_seize() public {
    //     testToken.mint(address(this), 100 ether);
    //     testToken.mint(address(0xc0de), 100 ether);

    //     testToken.approve(address(manager), 100 ether);

    //     uint256 tokenId = manager.mint(ILicredity(address(licredity)));

    //     Plan memory planner = Planner.init(tokenId);
    //     planner.add(Actions.INCREASE_DEBT_AMOUNT, abi.encode(address(this), 0.9 ether));
    //     planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 1 ether));

    //     ActionsData[] memory calls = planner.finalize();

    //     manager.execute(calls, _deadline);
    //     assertEq(manager.ownerOf(1), address(this));
    //     oracleMock.setFungibleConfig(FungibleMock.wrap(address(testToken)), 0.5 ether, 100_000); // 10%

    //     vm.startPrank(address(0xc0de));
    //     testToken.approve(address(manager), 100 ether);

    //     tokenId = manager.mint(ILicredity(address(licredity)));

    //     planner = Planner.init(tokenId);
    //     planner.add(Actions.SEIZE, abi.encode(uint256(1)));
    //     planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(true, address(testToken), 1 ether));

    //     calls = planner.finalize();

    //     manager.execute(calls, _deadline);
    //     assertEq(manager.ownerOf(1), address(0xc0de));
    //     vm.stopPrank();
    // }

    receive() external payable {}
}
