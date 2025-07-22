// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ActionConstants} from "../libraries/ActionConstants.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@uniswap-v4-core/libraries/TransientStateLibrary.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

abstract contract UniswapV4Router {
    using TransientStateLibrary for IPoolManager;

    /// @notice Emitted trying to take a negative delta.
    error DeltaNotNegative(Currency currency);

    IPoolManager public immutable poolManager;
    address public immutable positionManager;

    uint256 constant OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN = 0xffffffe0;

    uint256 constant UNLOCK_SELECTOR = 0x48c89491;
    uint256 constant MODIFIER_LIQUIDITY_SELECTOR = 0xdd46508f;
    uint256 constant SWAP_SELECTOR = 0xf3cd914c;

    constructor(IPoolManager _poolManager, address _positionManager) {
        poolManager = _poolManager;
        positionManager = _positionManager;
    }

    function _positionManagerCall(uint256 positionValue, bytes calldata positionCalldata) internal {
        address _positionManager = positionManager;

        assembly ("memory-safe") {
            let fmp := mload(0x40)

            // 0x00: selector
            // 0x20: unlockdata offset(0x40)
            // 0x40: deadline(block.timestamp)
            // 0x60: positionManagerCallData.length
            // 0x80: beginning of positionManagerCallData
            mstore(fmp, MODIFIER_LIQUIDITY_SELECTOR)
            mstore(add(fmp, 0x20), 0x40)
            mstore(add(fmp, 0x40), timestamp())

            let positionParamsLength := positionCalldata.length
            mstore(add(fmp, 0x60), positionParamsLength)
            calldatacopy(add(fmp, 0x80), positionCalldata.offset, positionParamsLength)

            let success :=
                call(gas(), _positionManager, positionValue, add(fmp, 0x1c), add(positionParamsLength, 0x64), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x0cb6ac70) // `PositionManagerCallFail()`
                revert(0x1c, 0x04)
            }
        }
    }

    function _uniswapPoolManagerCall(bytes calldata unlockData) internal {
        IPoolManager _poolManager = poolManager;

        assembly ("memory-safe") {
            let fmp := mload(0x40)

            // 0x00: selector
            // 0x20: unlockData offset(0x20)
            // 0x40: unlockData.length
            // 0x60: beginning of unlockData
            mstore(fmp, UNLOCK_SELECTOR)
            mstore(add(fmp, 0x20), 0x20)
            mstore(add(fmp, 0x40), unlockData.length)
            calldatacopy(add(fmp, 0x60), unlockData.offset, unlockData.length)

            let success := call(gas(), _poolManager, 0, add(fmp, 0x1c), add(unlockData.length, 0x44), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x1458ce24) // `UniswapV4UnlockFail()`
                revert(0x1c, 0x04)
            }
        }
    }

    function _swap(bytes calldata swapCalldata) internal {
        IPoolManager _poolManager = poolManager;

        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, SWAP_SELECTOR)

            calldatacopy(add(fmp, 0x20), swapCalldata.offset, swapCalldata.length)

            let success := call(gas(), _poolManager, 0, add(fmp, 0x1c), add(swapCalldata.length, 0x04), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x2fd8bc31) // `UniswapV4SwapFail()`
                revert(0x1c, 0x04)
            }
        }
    }

    function _settle(Currency currency, address payer, uint256 amount) internal {
        if (amount == 0) return;

        poolManager.sync(currency);
        if (currency.isAddressZero()) {
            poolManager.settle{value: amount}();
        } else {
            _pay(currency, payer, address(poolManager), amount);
            poolManager.settle();
        }
    }

    /// @notice Abstract function for contracts to implement paying tokens to the poolManager
    /// @param token The token to settle. This is known not to be the native currency
    /// @param payer The address who should pay tokens
    /// @param recipient The address who should receive tokens
    /// @param amount The number of tokens to send
    function _pay(Currency token, address payer, address recipient, uint256 amount) internal virtual;

    /// @notice Obtain the full amount owed by this contract (negative delta)
    /// @param currency Currency to get the delta for
    /// @return amount The amount owed by this contract as a uint256
    function _getFullDebt(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = poolManager.currencyDelta(address(this), currency);
        // If the amount is positive, it should be taken not settled.
        if (_amount > 0) revert DeltaNotNegative(currency);
        // Casting is safe due to limits on the total supply of a pool
        amount = uint256(-_amount);
    }

    /// @notice Calculates the amount for a settle action
    function _mapSettleAmount(uint256 amount, Currency currency) internal view returns (uint256) {
        if (amount == ActionConstants.CONTRACT_BALANCE) {
            return currency.balanceOfSelf();
        } else if (amount == ActionConstants.OPEN_DELTA) {
            return _getFullDebt(currency);
        } else {
            return amount;
        }
    }
}
