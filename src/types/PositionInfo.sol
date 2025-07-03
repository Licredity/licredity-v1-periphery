// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

/// @title PositionInfo
/// @notice Represents a position
/// @dev 160 bits pool address | 32 bits empty | 64 bits position id
type PositionInfo is bytes32;

using PositionInfoLibrary for PositionInfo global;

library PositionInfoLibrary {
    function pool(PositionInfo self) internal pure returns (ILicredity _pool) {
        assembly ("memory-safe") {
            _pool := shr(96, self)
        }
    }

    function positionId(PositionInfo self) internal pure returns (uint256 _positionId) {
        assembly ("memory-safe") {
            _positionId := and(self, 0xffffffffffffffff)
        }
    }

    function from(address _pool, uint256 _positionId) internal pure returns (PositionInfo self) {
        assembly ("memory-safe") {
            self := or(shl(96, _pool), _positionId)
        }
    }
}
