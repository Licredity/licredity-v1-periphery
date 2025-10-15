// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {IPositionManagerConfig} from "./interfaces/IPositionManagerConfig.sol";
import {IAllowanceTransfer} from "./interfaces/external/IAllowanceTransfer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract PositionManagerConfig is IPositionManagerConfig {
    IAllowanceTransfer immutable PERMIT2;

    mapping(address router => bool) internal isWhitelistedRouter;

    constructor(IAllowanceTransfer _permit2) {
        PERMIT2 = _permit2;
    }

    function updateTokenPermit2(address token, address spender, uint160 amount, uint48 expiration) external {
        IERC20(token).approve(address(PERMIT2), amount);
        PERMIT2.approve(token, spender, amount, expiration);
    }

    function updateTokenApporve(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }

    // TODO: Delete after import router swap actions
    function updateRouterWhitelist(address router, bool isWhitelist) external {
        assembly ("memory-safe") {
            router := and(router, 0xffffffffffffffffffffffffffffffffffffffff)
            mstore(0x00, router)
            mstore(0x20, isWhitelistedRouter.slot)
            let routerSlot := keccak256(0x00, 0x40)
            sstore(routerSlot, isWhitelist)

            mstore(0x00, isWhitelist)
            log2(0x00, 0x20, 0x1d385e8b5fc7b838eaf8aa9fc35810021a7fbda8f135edd7cc17fc4a6bb69d77, router)
        }
    }
}
