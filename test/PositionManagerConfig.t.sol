// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {PositionManagerConfigMock} from "./mocks/PositionManagerConfigMock.sol";
import {IPositionManagerConfig} from "src/interfaces/IPositionManagerConfig.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

contract PositionManagerConfigTest is Test {
    error NotGovernor();
    error NotNextGovernor();

    PositionManagerConfigMock config;

    function setUp() public {
        vm.createSelectFork("ETH", 22638094);
        IAllowanceTransfer permit2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
        config = new PositionManagerConfigMock(address(this), permit2);
    }

    function test_appointNextGovernor_notOwner() public {
        vm.startPrank(address(1));
        vm.expectRevert(NotGovernor.selector);
        config.appointNextGovernor(address(1));
        vm.stopPrank();
    }

    function test_appointNextGovernor(address[] calldata nextGovernors) public {
        vm.assume(nextGovernors.length > 1);
        for (uint256 i = 0; i < nextGovernors.length; i++) {
            vm.expectEmit(true, false, false, false);
            emit IPositionManagerConfig.AppointNextGovernor(nextGovernors[i]);
            config.appointNextGovernor(nextGovernors[i]);
        }

        assertEq(config.loadNextGovernor(), nextGovernors[nextGovernors.length - 1]);
    }

    function test_confirmNextGovernor(address _governorAddr) public {
        config.appointNextGovernor(_governorAddr);

        vm.startPrank(_governorAddr);
        vm.expectEmit(true, true, false, false);
        emit IPositionManagerConfig.ConfirmNextGovernor(address(this), _governorAddr);
        config.confirmNextGovernor();
        vm.stopPrank();

        assertEq(config.loadGovernor(), _governorAddr);
        assertEq(config.loadNextGovernor(), address(0));
    }

    function test_confirmNextGovernor_notPending(address pendingAddr, address other) public {
        vm.assume(pendingAddr != other);

        config.appointNextGovernor(pendingAddr);

        vm.startPrank(other);
        vm.expectRevert(NotNextGovernor.selector);
        config.confirmNextGovernor();
        vm.stopPrank();
    }

    function test_updatePoolWhitelist(address pool) public {
        vm.expectEmit(true, false, false, true);
        emit IPositionManagerConfig.UpdatePoolWhitelist(pool, true);
        config.updateLicredityMarketWhitelist(pool, true);

        assertTrue(config.loadPoolWhitelist(ILicredity(pool)));

        vm.expectEmit(true, false, false, true);
        emit IPositionManagerConfig.UpdatePoolWhitelist(pool, false);
        config.updateLicredityMarketWhitelist(pool, false);

        assertFalse(config.loadPoolWhitelist(ILicredity(pool)));
    }

    function test_updateRouterWhitelist(address router) public {
        vm.expectEmit(true, false, false, true);
        emit IPositionManagerConfig.UpdateRouterWhitelist(router, true);
        config.updateRouterWhitelist(router, true);

        assertTrue(config.loadRouterWhitelist(router));

        vm.expectEmit(true, false, false, true);
        emit IPositionManagerConfig.UpdateRouterWhitelist(router, false);
        config.updateRouterWhitelist(router, false);

        assertFalse(config.loadRouterWhitelist(router));
    }
}
