// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ActionConstants} from "../libraries/ActionConstants.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {TransientStateLibrary} from "@uniswap-v4-core/libraries/TransientStateLibrary.sol";

abstract contract UniswapV4Router {
    using TransientStateLibrary for IPoolManager;

    /// @notice Emitted trying to settle a positive delta.
    error DeltaNotPositive(Currency currency);
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

    /// @notice Sweeps the entire contract balance of specified currency to the recipient
    function _sweep(Currency currency, address to) internal {
        uint256 balance = currency.balanceOfSelf();
        if (balance > 0) currency.transfer(to, balance);
    }

    /// @notice Pay and settle a currency to the PoolManager
    /// @dev The implementing contract must ensure that the `payer` is a secure address
    /// @param currency Currency to settle
    /// @param payer Address of the payer
    /// @param amount Amount to send
    /// @dev Returns early if the amount is 0
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

    /// @notice Take an amount of currency out of the PoolManager
    /// @param currency Currency to take
    /// @param recipient Address to receive the currency
    /// @param amount Amount to take
    /// @dev Returns early if the amount is 0
    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        poolManager.take(currency, recipient, amount);
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

    /// @notice Obtain the full credit owed to this contract (positive delta)
    /// @param currency Currency to get the delta for
    /// @return amount The amount owed to this contract as a uint256
    function _getFullCredit(Currency currency) internal view returns (uint256 amount) {
        int256 _amount = poolManager.currencyDelta(address(this), currency);
        // If the amount is negative, it should be settled not taken.
        if (_amount < 0) revert DeltaNotPositive(currency);
        amount = uint256(_amount);
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

    /// @notice Calculates the amount for a take action
    function _mapTakeAmount(uint256 amount, Currency currency) internal view returns (uint256) {
        if (amount == ActionConstants.OPEN_DELTA) {
            return _getFullCredit(currency);
        } else {
            return amount;
        }
    }
}
