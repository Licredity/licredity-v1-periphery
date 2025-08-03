// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ActionsData} from "src/types/Actions.sol";
import {IPositionManagerConfig} from "./IPositionManagerConfig.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

interface IPositionManager is IPositionManagerConfig {
    error ContractLocked();
    error DeadlinePassed(uint256 deadline);
    error PoolNotWhitelisted();
    error InputLengthMismatch();
    error NotApproved(address);
    error NotSafeCallback();
    error DynCallTargetError();

    /// @notice Creates a new position in pool and returns its NFT tokenId
    /// @param pool The pool
    /// @return tokenId
    function mint(ILicredity pool) external returns (uint256 tokenId);

    /// @notice Burns a position
    /// @param tokenId The tokenId
    function burn(uint256 tokenId) external;

    /// @notice Deposits a fungible token
    /// @param tokenId The position tokenId
    /// @param token Deposit token address
    /// @param amount Deposit amount
    function depositFungible(uint256 tokenId, address token, uint256 amount) external payable;

    /// @notice Deposits a non-fungible token
    /// @param tokenId The position tokenId
    /// @param token Deposit NFT address
    /// @param tokenId Deposit NFT tokenId
    function depositNonFungible(uint256 tokenId, address token, uint256 depsoitTokenId) external;

    /// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
    /// @param inputs The encoded commands
    /// @param deadline The deadline by which the transaction must be executed
    function execute(ActionsData[] calldata inputs, uint256 deadline) external payable;
}
