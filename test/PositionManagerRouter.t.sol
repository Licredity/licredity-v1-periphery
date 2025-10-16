// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {LicredityExecutor} from "src/LicredityExecutor.sol";
import {Actions} from "src/types/Actions.sol";
import {ActionConstants} from "src/libraries/ActionConstants.sol";
import {ExecutePlan, ExecutePlanner} from "./shared/ExecutePlanner.sol";
import {PeripheryDeployers} from "./shared/PeripheryDeployers.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {stdJson} from "@forge-std/StdJson.sol";

contract LicredityExecutorWithRouterTest is PeripheryDeployers {
    using stdJson for string;

    IPoolManager uniswapV4poolManager;
    LicredityExecutor executor;

    uint256 _deadline;

    address constant USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant PT_USDO = address(0xB10DA2F9147f9cf2B8826877Cd0c95c18A0f42dc);

    address constant PARASWAP = address(0x6A000F20005980200259B80c5102003040001068);
    address constant PENDLE = address(0x888888888889758F76e7103c6CbF23ABbF58F946);
    address constant ODOS = address(0xCf5540fFFCdC3d510B18bFcA6d2b9987b0772559);

    address constant SWAP_RECEIVER = address(0x67411b21cAC859b840693bF5e21C5481F1288D97);

    address constant USDC_SENDER = address(0xaD354CfBAa4A8572DD6Df021514a3931A8329Ef5);

    function setUp() public {
        vm.label(USDC, "USDC");
        vm.label(PT_USDO, "ptUSDO");

        vm.createSelectFork("ETH", 23412519);

        uniswapV4poolManager = deployUniswapV4Core(address(0xabcd), hex"01");

        deployLicredity(address(0), address(uniswapV4poolManager), address(this), "Debt ETH", "DETH");
        licredity.setDebtLimit(10000 ether);
        deployAndSetOracleMock();
        deployNonFungibleMock();

        executor = new LicredityExecutor(uniswapV4poolManager, address(0), IAllowanceTransfer(PERMIT2_ADDRESS));

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

    function _getUsdc(address receiver, uint256 amount) internal {
        vm.startPrank(USDC_SENDER);
        IERC20(USDC).transfer(receiver, amount);
        vm.stopPrank();
    }

    function test_PoolManager_paraswap_native() public {
        bytes memory swapCalldata = _getParaSwapCalldata("native");

        assertEq(IERC20(address(USDC)).balanceOf(address(executor)), 0);
        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.PARA_SWAP, abi.encodePacked(abi.encode(5 ether), swapCalldata));

        licredity.unlock{value: 5 ether}(address(executor), planner.encode(_deadline));

        assertGt(IERC20(address(USDC)).balanceOf(address(executor)), 0);
    }

    function test_PoolManager_paraswap_token() public {
        IERC20(USDC).approve(address(executor), type(uint256).max);
        _getUsdc(address(this), 5000e6);

        bytes memory swapCalldata = _getParaSwapCalldata("token");

        uint256 positionId = licredity.openPosition();
        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.APPROVE, abi.encode(address(USDC), PARASWAP));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(USDC), 5000e6));
        planner.add(
            Actions.WITHDRAW_FUNGIBLE, abi.encode(positionId, ActionConstants.ADDRESS_THIS, address(USDC), 5000e6)
        );
        planner.add(Actions.PARA_SWAP, abi.encodePacked(abi.encode(0), swapCalldata));

        assertEq(address(executor).balance, 0);
        licredity.unlock(address(executor), planner.encode(_deadline));
        assertGt(address(executor).balance, 0);
    }

    function test_PoolManager_Pendle_native() public {
        bytes memory swapCalldata = _getPendleSwapCalldata("native");

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.PENDLE_SWAP, abi.encodePacked(abi.encode(5 ether), swapCalldata));

        assertEq(IERC20(PT_USDO).balanceOf(SWAP_RECEIVER), 0);
        licredity.unlock{value: 5 ether}(address(executor), planner.encode(_deadline));
        assertGt(IERC20(PT_USDO).balanceOf(SWAP_RECEIVER), 0);
    }

    function test_PoolManager_Pendle_token() public {
        IERC20(USDC).approve(address(executor), type(uint256).max);
        _getUsdc(address(this), 5000e6);

        uint256 positionId = licredity.openPosition();
        bytes memory swapCalldata = _getPendleSwapCalldata("token");
        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.APPROVE, abi.encode(address(USDC), PENDLE));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(USDC), 5000e6));
        planner.add(
            Actions.WITHDRAW_FUNGIBLE, abi.encode(positionId, ActionConstants.ADDRESS_THIS, address(USDC), 5000e6)
        );
        planner.add(Actions.PENDLE_SWAP, abi.encodePacked(abi.encode(0), swapCalldata));

        assertEq(IERC20(PT_USDO).balanceOf(SWAP_RECEIVER), 0);
        licredity.unlock(address(executor), planner.encode(_deadline));
        assertGt(IERC20(PT_USDO).balanceOf(SWAP_RECEIVER), 0);
    }

    function test_PoolManager_Odos_native() public {
        bytes memory swapCalldata = _getOdosSwapCalldata("native");

        assertEq(IERC20(address(USDC)).balanceOf(address(executor)), 0);

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.ODOS_SWAP, abi.encodePacked(abi.encode(5 ether), swapCalldata));

        licredity.unlock{value: 5 ether}(address(executor), planner.encode(_deadline));

        assertGt(IERC20(address(USDC)).balanceOf(SWAP_RECEIVER), 0);
    }

    function test_PoolManager_Odos_token() public {
        IERC20(USDC).approve(address(executor), type(uint256).max);
        _getUsdc(address(this), 5000e6);

        uint256 positionId = licredity.openPosition();

        bytes memory swapCalldata = _getOdosSwapCalldata("token");

        ExecutePlan memory planner = ExecutePlanner.init();
        planner.add(Actions.APPROVE, abi.encode(address(USDC), ODOS));
        planner.add(Actions.DEPOSIT_FUNGIBLE, abi.encode(positionId, true, address(USDC), 5000e6));
        planner.add(
            Actions.WITHDRAW_FUNGIBLE, abi.encode(positionId, ActionConstants.ADDRESS_THIS, address(USDC), 5000e6)
        );
        planner.add(Actions.ODOS_SWAP, abi.encodePacked(abi.encode(0), swapCalldata));

        assertEq(SWAP_RECEIVER.balance, 0);
        licredity.unlock(address(executor), planner.encode(_deadline));
        assertGt(SWAP_RECEIVER.balance, 0);
    }
}
