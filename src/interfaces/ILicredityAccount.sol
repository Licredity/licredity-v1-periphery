// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {IApproveHelper} from "./IApproveHelper.sol";
import {IUnlockExecutor} from "@licredity-v1-core/interfaces/IUnlockExecutor.sol";

interface ILicredityExecutor is IUnlockExecutor, IApproveHelper {
    error ContractLocked();
    error DeadlinePassed(uint256 deadline);
    error InputLengthMismatch();
    error NotSafeCallback();
    error UnknownAction(uint256 action);
}
