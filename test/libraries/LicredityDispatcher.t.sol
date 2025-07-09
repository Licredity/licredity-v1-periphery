// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test} from "@forge-std/Test.sol";
import {LicredityDispatcher} from "src/libraries/LicredityDispatcher.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";

contract LicredityDispatcherTest is Test {
    function test_fuzz_getNonFungible(address token, uint64 id) public pure {
        NonFungible nft = LicredityDispatcher.getNonFungible(token, id);
        assertEq(nft.tokenAddress(), token);
        assertEq(nft.tokenId(), id);
    }
}
