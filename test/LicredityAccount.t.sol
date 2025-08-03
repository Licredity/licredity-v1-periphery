// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityAccount} from "src/LicredityAccount.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {BaseERC20Mock} from "@licredity-v1-test/utils/Deployer.sol";

contract LicredityAccountTest is PeripheryDeployers {
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

    function test_openWithClose() public {
        vm.expectEmit(true, true, false, false);
        emit ILicredity.OpenPosition(1, address(account));
        uint256 positionId = account.open(licredity);

        vm.expectEmit(true, false, false, false);
        emit ILicredity.ClosePosition(1);
        account.close(licredity, positionId);
    }

    function test_whithdraw_native() public {
        payable(address(account)).transfer(1 ether);
        account.sweepFungible(Currency.wrap(address(0)), address(1), 1 ether);

        assertEq(address(account).balance, 0);
        assertEq(address(1).balance, 1 ether);
    }

    function test_whithdraw_fungible() public {
        testToken.mint(address(account), 1 ether);
        account.sweepFungible(Currency.wrap(address(testToken)), address(1), 1 ether);

        assertEq(testToken.balanceOf(address(account)), 0);
        assertEq(testToken.balanceOf(address(1)), 1 ether);
    }

    function getNonFungible(address token, uint256 tokenId) internal pure returns (NonFungible nft) {
        assembly ("memory-safe") {
            nft := or(shl(96, token), and(tokenId, 0xffffffffffffffff))
        }
    }

    function test_whithdraw_nonFungible() public {
        nonFungibleMock.mint(address(account), 1);
        NonFungible nft = getNonFungible(address(nonFungibleMock), 1);

        account.sweepNonFungible(nft, address(1));
        assertEq(nonFungibleMock.ownerOf(1), address(1));
    }
}
