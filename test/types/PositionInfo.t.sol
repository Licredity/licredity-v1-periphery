// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {PositionInfo, PositionInfoLibrary} from "src/types/PositionInfo.sol";

contract PositionInfoTest is Test {
    function test_Position_packedAndUnpacked(address marketAddress, uint64 positionId) public pure {
        PositionInfo info = PositionInfoLibrary.from(marketAddress, positionId);

        assertEq(address(info.market()), marketAddress);
        assertEq(info.positionId(), positionId);
    }
}
