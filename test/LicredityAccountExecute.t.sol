// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityAccount} from "src/LicredityAccount.sol";
import {Actions} from "src/types/Actions.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {AccountPlan, AccountPlanner} from "./shared/AccountPlanner.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {BaseERC20Mock} from "@licredity-v1-test/utils/Deployer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

contract LicredityAccountExecuteTest is PeripheryDeployers {
    LicredityAccount account;

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

        account = new LicredityAccount(address(this), poolManager, uniswapV4PositionManager, permit2);
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
}
