// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {PositionManager} from "src/PositionManager.sol";
import {LicredityAccount} from "src/LicredityAccount.sol";
import {Actions, ActionsData} from "src/types/Actions.sol";
import {Planner, Plan} from "./shared/Planner.sol";
import {AccountPlan, AccountPlanner} from "./shared/AccountPlanner.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {stdJson} from "@forge-std/StdJson.sol";

contract PositionManagerWithUniswapV4Test is PeripheryDeployers {
    using stdJson for string;

    IPoolManager uniswapV4poolManager;
    PositionManager licredityManager;
    LicredityAccount account;

    uint256 _deadline;

    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant PARASWAP = address(0x6A000F20005980200259B80c5102003040001068);

    address constant USDC_SENDER = address(0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5);

    function setUp() public {
        vm.createSelectFork("ETH", 22990827);
        uniswapV4poolManager = deployUniswapV4Core(address(0xabcd), hex"01");

        deployLicredity(address(0), uint256(365), address(uniswapV4poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);
        deployAndSetOracleMock();
        deployNonFungibleMock();

        licredityManager =
            new PositionManager(address(this), uniswapV4poolManager, address(0), IAllowanceTransfer(PERMIT2_ADDRESS));
        licredityManager.updateLicredityMarketWhitelist(address(licredity), true);
        account =
            new LicredityAccount(address(this), uniswapV4poolManager, address(0), IAllowanceTransfer(PERMIT2_ADDRESS));

        _deadline = block.timestamp + 1;
    }

    function _getParaSwapCalldata(string memory swapType) internal view returns (bytes memory swapCalldata) {
        string memory path = string.concat("./test/test_data/paraswap_", swapType, ".json");
        string memory json = vm.readFile(path);
        swapCalldata = json.parseRaw(".txParams.data");
    }

    function _getUSDC(address receiver, uint256 amount) internal {
        vm.startPrank(USDC_SENDER);
        IERC20(USDC).transfer(receiver, amount);
        vm.stopPrank();
    }

    function test_paraswap_native() public {
        licredityManager.updateRouterWhitelist(PARASWAP, true);
        bytes memory swapCalldata = _getParaSwapCalldata("native");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 5 ether), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 5 ether}(calls, _deadline);

        assertGe(IERC20(address(USDC)).balanceOf(address(this)), 0);
    }

    function test_PoolManager_paraswap_token() public {
        licredityManager.updateRouterWhitelist(PARASWAP, true);
        licredityManager.updateTokenApporve(USDC, PARASWAP, type(uint256).max);
        _getUSDC(address(licredityManager), 1000e6);

        bytes memory swapCalldata = _getParaSwapCalldata("token");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 0), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute(calls, _deadline);

        assertGe(address(licredityManager).balance, 0);
    }

    function test_Account_paraswap_token() public {
        account.updateRouterWhitelist(PARASWAP, true);
        account.updateTokenApporve(USDC, PARASWAP, type(uint256).max);
        _getUSDC(address(account), 1000e6);

        bytes memory swapCalldata = _getParaSwapCalldata("token");

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 0), swapCalldata));

        account.execute(licredity, planner.encode(), _deadline);

        assertGe(address(account).balance, 0);
    }
}
