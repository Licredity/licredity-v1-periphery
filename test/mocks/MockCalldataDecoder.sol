// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";

contract MockCalldataDecoder {
    using CalldataDecoder for bytes;

    function decodeOffset(bytes calldata _bytes, uint256 position) external pure returns (uint256 offset) {
        return CalldataDecoder.decodeOffset(_bytes, position);
    }

    function decodeActionsRouterParams(uint256 offset, bytes calldata _bytes)
        external
        pure
        returns (bytes calldata actions, bytes[] calldata params)
    {
        return CalldataDecoder.decodeActionsRouterParams(_bytes, offset);
    }

    function decodeBoolAddressAndUint256(bytes calldata params)
        external
        pure
        returns (bool boolean, address token, uint256 amount)
    {
        return CalldataDecoder.decodeBoolAddressAndUint256(params);
    }

    function decodeAddressAndAddress(bytes calldata params) external pure returns (address token, address spender) {
        return CalldataDecoder.decodeAddressAndAddress(params);
    }

    function decodeBoolUint256AddressAndUint256(bytes calldata params)
        external
        pure
        returns (uint256 id, bool boolean, address token, uint256 amount)
    {
        return CalldataDecoder.decodeBoolUint256AddressAndUint256(params);
    }

    function decodeWithdraw(bytes calldata params)
        external
        pure
        returns (uint256 id, address recipient, address token, uint256 amount)
    {
        return CalldataDecoder.decodeWithdraw(params);
    }

    function decodeIncreaseDebt(bytes calldata params)
        external
        pure
        returns (uint256 id, address recipient, uint256 amount)
    {
        return CalldataDecoder.decodeIncreaseDebt(params);
    }

    function decodeDecreaseDebt(bytes calldata params)
        external
        pure
        returns (uint256 id, uint256 amount, bool useBalance)
    {
        return CalldataDecoder.decodeDecreaseDebt(params);
    }

    function decodeSeizedPosition(bytes calldata params) external pure returns (uint256 tokenId, address recipient) {
        return CalldataDecoder.decodeSeizedPosition(params);
    }

    function decodeCurrencyAddressAndUint256(bytes calldata params)
        external
        pure
        returns (Currency currency, address addr, uint256 amount)
    {
        return CalldataDecoder.decodeCurrencyAddressAndUint256(params);
    }

    function decodeCurrencyAndAddress(bytes calldata params)
        external
        pure
        returns (Currency currency, address _address)
    {
        return CalldataDecoder.decodeCurrencyAndAddress(params);
    }

    function decodeCallValueAndData(bytes calldata params)
        external
        pure
        returns (uint256 positionValue, bytes calldata positionParams)
    {
        return CalldataDecoder.decodeCallValueAndData(params);
    }
}
