// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {PositionInfo, PositionInfoLibrary} from "src/types/PositionInfo.sol";

contract PositionInfoTest is Test {
    function test_Position_packedAndUnpacked(address poolAddress, uint64 positionId) public pure {
        PositionInfo info = PositionInfoLibrary.from(poolAddress, positionId);

        assertEq(address(info.pool()), poolAddress);
        assertEq(info.positionId(), positionId);
    }
}
