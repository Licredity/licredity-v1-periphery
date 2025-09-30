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
    address constant ptUSDO = address(0xB10DA2F9147f9cf2B8826877Cd0c95c18A0f42dc);

    address constant PARASWAP = address(0x6A000F20005980200259B80c5102003040001068);
    address constant PENDLE = address(0x888888888889758F76e7103c6CbF23ABbF58F946);
    address constant ODOS = address(0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559);

    address constant swapReceiver = address(0x67411b21cAC859b840693bF5e21C5481F1288D97);

    address constant USDC_SENDER = address(0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5);
    
    function setUp() public {
        vm.label(USDC, "USDC");
        vm.label(ptUSDO, "ptUSDO");

        vm.createSelectFork("ETH", 23412519);
        
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

    function _getPendleSwapCalldata(string memory swapType) internal view returns (bytes memory swapCalldata) {
        string memory path = string.concat("./test/test_data/pendle_", swapType, ".json");
        string memory json = vm.readFile(path);
        swapCalldata = json.parseRaw(".routes[0].tx.data");
    }

    function _getOdosSwapCalldata(string memory swapType) internal view returns (bytes memory swapCalldata) {
        string memory path = string.concat("./test/test_data/odos_", swapType, ".json");
        string memory json = vm.readFile(path);
        swapCalldata = json.parseRaw(".transaction.data");
    }

    function _getUSDC(address receiver, uint256 amount) internal {
        vm.startPrank(USDC_SENDER);
        IERC20(USDC).transfer(receiver, amount);
        vm.stopPrank();
    }

    function test_PoolManager_paraswap_native() public {
        licredityManager.updateRouterWhitelist(PARASWAP, true);
        bytes memory swapCalldata = _getParaSwapCalldata("native");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 5 ether), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 5 ether}(calls, _deadline);

        assertGt(IERC20(address(USDC)).balanceOf(address(licredityManager)), 0);
    }

    function test_PoolManager_paraswap_token() public {
        licredityManager.updateRouterWhitelist(PARASWAP, true);
        licredityManager.updateTokenApporve(USDC, PARASWAP, type(uint256).max);
        _getUSDC(address(licredityManager), 5000e6);

        bytes memory swapCalldata = _getParaSwapCalldata("token");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 0), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute(calls, _deadline);

        assertGt(address(licredityManager).balance, 0);
    }

    function test_PoolManager_Pendle_native() public {
        licredityManager.updateRouterWhitelist(PENDLE, true);
        bytes memory swapCalldata = _getPendleSwapCalldata("native");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PENDLE, 5 ether), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 5 ether}(calls, _deadline);

        assertGt(IERC20(ptUSDO).balanceOf(swapReceiver), 0);
    }

    function test_PoolManager_Pendle_token() public {
        licredityManager.updateRouterWhitelist(PENDLE, true);
        licredityManager.updateTokenApporve(USDC, PENDLE, type(uint256).max);
        _getUSDC(address(licredityManager), 5000e6);

        bytes memory swapCalldata = _getPendleSwapCalldata("token");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PENDLE, 0), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute(calls, _deadline);

        assertGt(IERC20(ptUSDO).balanceOf(swapReceiver), 0);
    }

    function test_PoolManager_Odos_native() public {
        licredityManager.updateRouterWhitelist(ODOS, true);
        bytes memory swapCalldata = _getOdosSwapCalldata("native");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(ODOS, 5 ether), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        licredityManager.execute{value: 5 ether}(calls, _deadline);

        assertGt(IERC20(address(USDC)).balanceOf(swapReceiver), 0);
    }

    function test_PoolManager_Odos_token() public {
        licredityManager.updateRouterWhitelist(ODOS, true);
        licredityManager.updateTokenApporve(USDC, ODOS, type(uint256).max);
        _getUSDC(address(licredityManager), 5000e6);

        bytes memory swapCalldata = _getOdosSwapCalldata("token");

        uint256 tokenId = licredityManager.mint(licredity);
        Plan memory planner = Planner.init(tokenId);
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(ODOS, 0), swapCalldata));

        ActionsData[] memory calls = planner.finalize();

        assertEq(swapReceiver.balance, 0);
        
        licredityManager.execute(calls, _deadline);

        assertGt(swapReceiver.balance, 0);
    }

    function test_Account_paraswap_token() public {
        account.updateRouterWhitelist(PARASWAP, true);
        account.updateTokenApporve(USDC, PARASWAP, type(uint256).max);
        _getUSDC(address(account), 5000e6);

        bytes memory swapCalldata = _getParaSwapCalldata("token");

        AccountPlan memory planner = AccountPlanner.init();
        planner.add(Actions.DYN_CALL, abi.encodePacked(abi.encode(PARASWAP, 0), swapCalldata));

        account.execute(licredity, planner.encode(), _deadline);

        assertGt(address(account).balance, 0);
    }
}
