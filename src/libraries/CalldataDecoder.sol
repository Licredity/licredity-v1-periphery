// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library CalldataDecoder {
    error SliceOutOfBounds();

    /// @notice mask used for offsets and lengths to ensure no overflow
    /// @dev no sane abi encoding will pass in an offset or length greater than type(uint32).max
    ///      (note that this does deviate from standard solidity behavior and offsets/lengths will
    ///      be interpreted as mod type(uint32).max which will only impact malicious/buggy callers)
    uint256 constant OFFSET_OR_LENGTH_MASK = 0xffffffff;
    uint256 constant OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN = 0xffffffe0;

    /// @notice equivalent to SliceOutOfBounds.selector, stored in least-significant bits
    uint256 constant SLICE_ERROR_SELECTOR = 0x3b99b53d;

    /// @dev equivalent to: abi.decode(params, (bytes, bytes[])) in calldata (requires strict abi encoding)
    function decodeActionsRouterParams(bytes calldata _bytes)
        internal
        pure
        returns (bytes calldata actions, bytes[] calldata params)
    {
        assembly ("memory-safe") {
            // Strict encoding requires that the data begin with:
            // 0x00: 0x40 (offset to `actions.length`)
            // 0x20: 0x60 + actions.length (offset to `params.length`)
            // 0x40: `actions.length`
            // 0x60: beginning of actions

            // Verify actions offset matches strict encoding
            let invalidData := xor(calldataload(_bytes.offset), 0x40)
            actions.offset := add(_bytes.offset, 0x60)
            actions.length := and(calldataload(add(_bytes.offset, 0x40)), OFFSET_OR_LENGTH_MASK)

            // Round actions length up to be word-aligned, and add 0x60 (for the first 3 words of encoding)
            let paramsLengthOffset := add(and(add(actions.length, 0x1f), OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN), 0x60)
            // Verify params offset matches strict encoding
            invalidData := or(invalidData, xor(calldataload(add(_bytes.offset, 0x20)), paramsLengthOffset))
            let paramsLengthPointer := add(_bytes.offset, paramsLengthOffset)
            params.length := and(calldataload(paramsLengthPointer), OFFSET_OR_LENGTH_MASK)
            params.offset := add(paramsLengthPointer, 0x20)

            // Expected offset for `params[0]` is params.length * 32
            // As the first `params.length` slots are pointers to each of the array element lengths
            let tailOffset := shl(5, params.length)
            let expectedOffset := tailOffset

            for { let offset := 0 } lt(offset, tailOffset) { offset := add(offset, 32) } {
                let itemLengthOffset := calldataload(add(params.offset, offset))
                // Verify that the offset matches the expected offset from strict encoding
                invalidData := or(invalidData, xor(itemLengthOffset, expectedOffset))
                let itemLengthPointer := add(params.offset, itemLengthOffset)
                let length :=
                    add(and(add(calldataload(itemLengthPointer), 0x1f), OFFSET_OR_LENGTH_MASK_AND_WORD_ALIGN), 0x20)
                expectedOffset := add(expectedOffset, length)
            }

            // if the data encoding was invalid, or the provided bytes string isnt as long as the encoding says, revert
            if or(invalidData, lt(add(_bytes.length, _bytes.offset), add(params.offset, expectedOffset))) {
                mstore(0, SLICE_ERROR_SELECTOR)
                revert(0x1c, 4)
            }
        }
    }

    function decodeDeposit(bytes calldata params)
        internal
        pure
        returns (address payer, address token, uint256 amount)
    {
        assembly ("memory-safe") {
            payer := calldataload(params.offset)
            token := calldataload(add(params.offset, 0x20))
            amount := calldataload(add(params.offset, 0x40))
        }
    }

    function decodeWithdraw(bytes calldata params)
        internal
        pure
        returns (address recipient, address token, uint256 amount)
    {
        assembly ("memory-safe") {
            recipient := calldataload(params.offset)
            token := calldataload(add(params.offset, 0x20))
            amount := calldataload(add(params.offset, 0x40))
        }
    }

    function decodeIncreaseDebt(bytes calldata params) internal pure returns (address recipient, uint256 amount) {
        assembly ("memory-safe") {
            recipient := calldataload(params.offset)
            amount := calldataload(add(params.offset, 0x20))
        }
    }

    function decodeDecreaseDebt(bytes calldata params)
        internal
        pure
        returns (address payer, uint256 amount, bool useBalance)
    {
        assembly ("memory-safe") {
            payer := calldataload(params.offset)
            amount := calldataload(add(params.offset, 0x20))
            useBalance := calldataload(add(params.offset, 0x40))
        }
    }

    function decodeSeizeTokenId(bytes calldata params) internal pure returns (uint256 tokenId) {
        assembly ("memory-safe") {
            tokenId := calldataload(params.offset)
        }
    }
}
