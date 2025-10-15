// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IApproveHelper} from "./IApproveHelper.sol";
import {IUnlockExecutor} from "@licredity-v1-core/interfaces/IUnlockExecutor.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

interface ILicredityExecutor is IUnlockExecutor, IApproveHelper {
    error ContractLocked();
    error DeadlinePassed(uint256 deadline);
    error InputLengthMismatch();
    error NotSafeCallback();
}
