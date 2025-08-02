// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ActionsData} from "src/types/Actions.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IPositionManagerConfig} from "./IPositionManagerConfig.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

interface ILicredityAccount is IPositionManagerConfig {
    error ContractLocked();
    error DeadlinePassed(uint256 deadline);
    error InputLengthMismatch();
    error NotSafeCallback();

    /// @notice Creates a new position in pool and returns its positionId
    /// @param pool Licredity pool address
    /// @return positionId of the new position in licredity pool
    function open(ILicredity pool) external returns (uint256 positionId);

    /// @notice Closes a position in pool
    /// @param pool Licredity pool address
    /// @param positionId positionId of the position in licredity pool
    function close(ILicredity pool, uint256 positionId) external;

    /// @notice Withdraw fungible token from licredity account
    /// @param currency Fungible token
    /// @param recipient Recipient address
    /// @param amount Withdraw Amount
    function sweepFungible(Currency currency, address recipient, uint256 amount) external;

    /// @notice Withdraw non-fungible token from licredity account
    /// @param nonFungible Non-fungible token type
    /// @param recipient Recipient address
    function sweepNonFungible(NonFungible nonFungible, address recipient) external;

    /// @notice Execute actions
    /// @param licredity Licredity pool address
    /// @param inputs Actions data
    /// @param deadline Deadline
    function execute(ILicredity licredity, ActionsData[] calldata inputs, uint256 deadline) external payable;
}
