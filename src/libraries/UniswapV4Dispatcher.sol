// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UniswapV4Dispatcher {
    uint256 constant OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN = 0xffffffe0;
    uint256 constant UNLOCK_SELECTOR = 0x48c89491;
    uint256 constant MODIFIER_LIQUIDITY_SELECTOR = 0xdd46508f;

    uint256 constant SWAP_SELECTOR = 0xf3cd914c;

    function uniswapPoolManagerCall(address uniswapV4PoolManager, bytes calldata swapCalldata) internal {
        assembly ("memory-safe") {
            let fmp := mload(0x40)

            // 0x00: selector
            // 0x20: unlockdata offset(0x20)
            // 0x40: swapCalldata.length
            // 0x60: beginning of swapCalldata
            mstore(fmp, UNLOCK_SELECTOR)
            mstore(add(fmp, 0x20), 0x20)
            mstore(add(fmp, 0x40), swapCalldata.length)
            calldatacopy(add(fmp, 0x60), swapCalldata.offset, swapCalldata.length)

            let success :=
                call(gas(), uniswapV4PoolManager, 0, add(fmp, 0x1c), add(swapCalldata.length, 0x44), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x2fd8bc31) // `UniswapV4SwapFail()`
                revert(0x1c, 0x04)
            }
        }
    }

    function positionManagerCall(address positionManager, uint256 positionValue, bytes calldata positionCalldata)
        internal
    {
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
                call(gas(), positionManager, positionValue, add(fmp, 0x1c), add(positionParamsLength, 0x64), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x0cb6ac70) // `PositionManagerCallFail()`
                revert(0x1c, 0x04)
            }
        }
    }

    function uniswapPoolSwapCall(address uniswapV4PoolManager, bytes calldata swapCalldata) internal {
        assembly ("memory-safe") {
            let fmp := mload(0x40)
            mstore(fmp, SWAP_SELECTOR)

            calldatacopy(add(fmp, 0x20), swapCalldata.offset, swapCalldata.length)

            let success :=
                call(gas(), uniswapV4PoolManager, 0, add(fmp, 0x1c), add(swapCalldata.length, 0x04), 0x00, 0x00)

            if iszero(success) {
                mstore(0x00, 0x2fd8bc31) // `UniswapV4SwapFail()`
                revert(0x1c, 0x04)
            }
        }
    }
}
