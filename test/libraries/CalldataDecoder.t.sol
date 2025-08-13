// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {MockCalldataDecoder} from "../mocks/MockCalldataDecoder.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";

contract CalldataDecoderTest is Test {
    MockCalldataDecoder decoder;

    function setUp() public {
        decoder = new MockCalldataDecoder();
    }

    function test_fuzz_decodeActionsRouterParams(bytes memory _actions, bytes[] memory _actionParams) public view {
        bytes memory params = abi.encode(_actions, _actionParams);
        (bytes memory actions, bytes[] memory actionParams) = decoder.decodeActionsRouterParams(params);

        assertEq(actions, _actions);
        assertEq(actionParams, _actionParams);
    }

    function test_decodeActionsRouterParams_sliceOutOfBounds() public {
        // create actions and parameters
        bytes memory _actions = hex"12345678";
        bytes[] memory _actionParams = new bytes[](4);
        _actionParams[0] = hex"11111111";
        _actionParams[1] = hex"22";
        _actionParams[2] = hex"3333333333333333";
        _actionParams[3] = hex"4444444444444444444444444444444444444444444444444444444444444444";

        bytes memory params = abi.encode(_actions, _actionParams);

        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeActionsRouterParams(invalidParams);
    }

    function test_decodeActionsRouterParams_emptyParams() public view {
        // create actions and parameters
        bytes memory _actions = hex"";
        bytes[] memory _actionParams = new bytes[](0);

        bytes memory params = abi.encode(_actions, _actionParams);

        (bytes memory actions, bytes[] memory actionParams) = decoder.decodeActionsRouterParams(params);
        assertEq(actions, _actions);
        assertEq(actionParams.length, _actionParams.length);
        assertEq(actionParams.length, 0);
    }

    function test_fuzz_decodeCallValueAndData(uint256 _positionCallValue, bytes memory _positionCalldata)
        external
        view
    {
        bytes memory params = abi.encode(_positionCallValue, _positionCalldata);
        (uint256 positionValue, bytes memory positionParams) = decoder.decodeCallValueAndData(params);

        assertEq(positionValue, _positionCallValue);
        assertEq(positionParams, _positionCalldata);
    }

    function test_decodeCallValueAndData_outOfBounds() external {
        uint256 positionValue = 1 ether;
        bytes memory positionCalldata = hex"4444444444444444444444444444444444444444444444444444444444444444";

        bytes memory params = abi.encode(positionValue, positionCalldata);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeCallValueAndData(invalidParams);
    }

    function test_decodeCallValueAndData_emptyParams() external view {
        bytes memory params = abi.encode(0, hex"");
        (uint256 positionValue, bytes memory positionParams) = decoder.decodeCallValueAndData(params);
        assertEq(positionValue, 0);
        assertEq(positionParams.length, 0);
    }

    function test_fuzz_decodeDeposit(bool _boolean, address _token, uint256 _amount) external view {
        bytes memory params = abi.encode(_boolean, _token, _amount);
        (bool boolean, address token, uint256 amount) = decoder.decodeBoolAddressAndUint256(params);

        assertEq(boolean, _boolean);
        assertEq(token, _token);
        assertEq(amount, _amount);
    }

    function test_decodeDeposit_outOfBounds() external {
        bool boolean = true;
        address token = address(0x1);
        uint256 amount = 1 ether;

        bytes memory params = abi.encode(boolean, token, amount);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeBoolAddressAndUint256(invalidParams);
    }

    function test_fuzz_decodeWithdraw(address _recipient, address _token, uint256 _amount) external view {
        bytes memory params = abi.encode(_recipient, _token, _amount);
        (address recipient, address token, uint256 amount) = decoder.decodeWithdraw(params);

        assertEq(recipient, _recipient);
        assertEq(token, _token);
        assertEq(amount, _amount);
    }

    function test_decodeWithdraw_outOfBounds() external {
        address recipient = address(0x1);
        address token = address(0x1);
        uint256 amount = 1 ether;

        bytes memory params = abi.encode(recipient, token, amount);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeWithdraw(invalidParams);
    }

    function test_fuzz_decodeIncreaseDebt(address _recipient, uint256 _amount) external view {
        bytes memory params = abi.encode(_recipient, _amount);
        (address recipient, uint256 amount) = decoder.decodeIncreaseDebt(params);

        assertEq(recipient, _recipient);
        assertEq(amount, _amount);
    }

    function test_decodeIncreaseDebt_outOfBounds() external {
        address recipient = address(0x1);
        uint256 amount = 1 ether;

        bytes memory params = abi.encode(recipient, amount);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeIncreaseDebt(invalidParams);
    }

    function test_fuzz_decodeDecreaseDebt(bool _boolean, uint256 _amount, bool _useBalance) external view {
        bytes memory params = abi.encode(_boolean, _amount, _useBalance);
        (bool boolean, uint256 amount, bool useBalance) = decoder.decodeDecreaseDebt(params);

        assertEq(boolean, _boolean);
        assertEq(amount, _amount);
        assertEq(useBalance, _useBalance);
    }

    function test_decodeDecreaseDebt_outOfBounds() external {
        bool boolean = true;
        uint256 amount = 1 ether;
        bool useBalance = true;

        bytes memory params = abi.encode(boolean, amount, useBalance);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeDecreaseDebt(invalidParams);
    }

    function test_fuzz_decodePositionId(uint256 _tokenId) external view {
        bytes memory params = abi.encode(_tokenId);
        uint256 tokenId = decoder.decodePositionId(params);

        assertEq(tokenId, _tokenId);
    }

    function test_decodePositionId_outOfBounds() external {
        uint256 tokenId = 1000;

        bytes memory params = abi.encode(tokenId);
        bytes memory invalidParams = _removeFinalByte(params);

        assertEq(invalidParams.length, params.length - 1);
        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodePositionId(invalidParams);
    }

    function test_fuzz_decodeCurrencyAddressAndUint256(Currency _currency, address _addr, uint256 _amount)
        public
        view
    {
        bytes memory params = abi.encode(_currency, _addr, _amount);
        (Currency currency, address addr, uint256 amount) = decoder.decodeCurrencyAddressAndUint256(params);

        assertEq(Currency.unwrap(currency), Currency.unwrap(_currency));
        assertEq(addr, _addr);
        assertEq(amount, _amount);
    }

    function test_decodeCurrencyAddressAndUint256_outOutBounds() public {
        uint256 value = 12345678;
        Currency currency = Currency.wrap(address(0x12341234));
        address addy = address(0x67896789);

        bytes memory params = abi.encode(currency, addy, value);
        bytes memory invalidParams = _removeFinalByte(params);
        assertEq(invalidParams.length, params.length - 1);

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeCurrencyAddressAndUint256(invalidParams);
    }

    function test_fuzz_decodeCurrencyAndAddress(Currency _currency, address __address) public view {
        bytes memory params = abi.encode(_currency, __address);
        (Currency currency, address _address) = decoder.decodeCurrencyAndAddress(params);

        assertEq(Currency.unwrap(currency), Currency.unwrap(_currency));
        assertEq(_address, __address);
    }

    function test_decodeCurrencyAndAddress_outOutBounds() public {
        Currency currency = Currency.wrap(address(0x12341234));
        address addy = address(0x23453456);

        bytes memory params = abi.encode(currency, addy);
        bytes memory invalidParams = _removeFinalByte(params);
        assertEq(invalidParams.length, params.length - 1);

        vm.expectRevert(CalldataDecoder.SliceOutOfBounds.selector);
        decoder.decodeCurrencyAndAddress(invalidParams);
    }

    function _removeFinalByte(bytes memory params) internal pure returns (bytes memory result) {
        result = new bytes(params.length - 1);
        // dont copy the final byte
        for (uint256 i = 0; i < params.length - 2; i++) {
            result[i] = params[i];
        }
    }
}
