// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";

contract MockCalldataDecoder {
    using CalldataDecoder for bytes;

    function decodeActionsRouterParams(bytes calldata _bytes)
        external
        pure
        returns (bytes calldata actions, bytes[] calldata params)
    {
        return CalldataDecoder.decodeActionsRouterParams(_bytes);
    }

    function decodeDeposit(bytes calldata params) external pure returns (bool boolean, address token, uint256 amount) {
        return CalldataDecoder.decodeDeposit(params);
    }

    function decodeWithdraw(bytes calldata params)
        external
        pure
        returns (address recipient, address token, uint256 amount)
    {
        return CalldataDecoder.decodeWithdraw(params);
    }

    function decodeIncreaseDebt(bytes calldata params) external pure returns (address recipient, uint256 amount) {
        return CalldataDecoder.decodeIncreaseDebt(params);
    }

    function decodeDecreaseDebt(bytes calldata params)
        external
        pure
        returns (bool boolean, uint256 amount, bool useBalance)
    {
        return CalldataDecoder.decodeDecreaseDebt(params);
    }

    function decodePositionId(bytes calldata params) external pure returns (uint256 tokenId) {
        return CalldataDecoder.decodePositionId(params);
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
