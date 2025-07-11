// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library UniswapV4Dispatcher {
    uint256 constant OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN = 0xffffffe0;
    uint256 constant SWAP_SELECTOR = 0xf3cd914c;

    function multiSwapCall(address uniswapV4PoolManager, bytes[] calldata swapParams) internal {
        assembly ("memory-safe") {
            if not(iszero(swapParams.length)) {
                let fmp := mload(0x40)
                mstore(fmp, SWAP_SELECTOR)

                let tailOffset := shl(5, swapParams.length)

                for { let offset := 0 } lt(offset, tailOffset) { offset := add(offset, 32) } {
                    let itemLengthOffset := calldataload(add(swapParams.offset, offset))
                    let itemLengthPointer := add(swapParams.offset, itemLengthOffset)
                    let length := calldataload(itemLengthPointer)

                    let swapDataPointer := add(itemLengthPointer, 0x20)

                    // TODO: hookData is right-padded with zeros, so copy length is (length + 0x20)
                    calldatacopy(add(fmp, 0x20), swapDataPointer, add(length, 0x20))

                    let success := call(gas(), uniswapV4PoolManager, 0, add(fmp, 0x1c), add(length, 0x20), 0x00, 0x00)

                    if iszero(success) {
                        mstore(0x00, 0x2fd8bc31) // `UniswapV4SwapFail()`
                        revert(0x1c, 0x04)
                    }
                }
            }
        }
    }
}
