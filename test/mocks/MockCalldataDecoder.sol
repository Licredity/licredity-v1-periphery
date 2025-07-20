// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {CalldataDecoder} from "src/libraries/CalldataDecoder.sol";

contract MockCalldataDecoder {
    using CalldataDecoder for bytes;

    function decodeActionsRouterParams(bytes calldata _bytes)
        internal
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

    function decodeSeizeTokenId(bytes calldata params) external pure returns (uint256 tokenId) {
        return CalldataDecoder.decodeSeizeTokenId(params);
    }

    function decodeCallValueAndData(bytes calldata params)
        external
        pure
        returns (uint256 positionValue, bytes calldata positionParams)
    {
        return CalldataDecoder.decodeCallValueAndData(params);
    }
}
