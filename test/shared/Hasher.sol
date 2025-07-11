// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

type Hasher is bytes32;

using HasherLibrary for Hasher global;

library HasherLibrary {
    function update(Hasher self, bytes memory _value) internal pure returns (Hasher _hash) {
        _hash = Hasher.wrap(keccak256(abi.encode(self, _value)));
    }
}
