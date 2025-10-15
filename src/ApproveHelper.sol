// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {IApproveHelper} from "./interfaces/IApproveHelper.sol";
import {IAllowanceTransfer} from "./interfaces/external/IAllowanceTransfer.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract ApproveHelper is IApproveHelper {
    IAllowanceTransfer immutable PERMIT2;

    constructor(IAllowanceTransfer _permit2) {
        PERMIT2 = _permit2;
    }

    function approvePermit2(address token, address spender, uint160 amount, uint48 expiration) external {
        IERC20(token).approve(address(PERMIT2), amount);
        PERMIT2.approve(token, spender, amount, expiration);
    }

    function approve(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }
}
