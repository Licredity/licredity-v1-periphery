// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {MockCalldataDecoder} from "../mocks/MockCalldataDecoder.sol";

contract CalldataDecoderTest is Test {
    MockCalldataDecoder decoder;

    function setUp() public {
        decoder = new MockCalldataDecoder();
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

    function test_fuzz_decodeDeposit(bool _boolean, address _token, uint256 _amount) external view {
        bytes memory params = abi.encode(_boolean, _token, _amount);
        (bool boolean, address token, uint256 amount) = decoder.decodeDeposit(params);

        assertEq(boolean, _boolean);
        assertEq(token, _token);
        assertEq(amount, _amount);
    }

    function test_fuzz_decodeWithdraw(address _recipient, address _token, uint256 _amount) external view {
        bytes memory params = abi.encode(_recipient, _token, _amount);
        (address recipient, address token, uint256 amount) = decoder.decodeWithdraw(params);

        assertEq(recipient, _recipient);
        assertEq(token, _token);
        assertEq(amount, _amount);
    }

    function test_fuzz_decodeIncreaseDebt(address _recipient, uint256 _amount) external view {
        bytes memory params = abi.encode(_recipient, _amount);
        (address recipient, uint256 amount) = decoder.decodeIncreaseDebt(params);

        assertEq(recipient, _recipient);
        assertEq(amount, _amount);
    }

    function test_fuzz_decodeDecreaseDebt(bool _boolean, uint256 _amount, bool _useBalance) external view {
        bytes memory params = abi.encode(_boolean, _amount, _useBalance);
        (bool boolean, uint256 amount, bool useBalance) = decoder.decodeDecreaseDebt(params);

        assertEq(boolean, _boolean);
        assertEq(amount, _amount);
        assertEq(useBalance, _useBalance);
    }

    function test_fuzz_decodeSeizeTokenId(uint256 _tokenId) external view {
        bytes memory params = abi.encode(_tokenId);
        uint256 tokenId = decoder.decodeSeizeTokenId(params);

        assertEq(tokenId, _tokenId);
    }

    function _removeFinalByte(bytes memory params) internal pure returns (bytes memory result) {
        result = new bytes(params.length - 1);
        // dont copy the final byte
        for (uint256 i = 0; i < params.length - 2; i++) {
            result[i] = params[i];
        }
    }
}
