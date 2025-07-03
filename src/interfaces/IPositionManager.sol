// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.24;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

interface IPositionManager {
    error ContractLocked();
    error DeadlinePassed(uint256 deadline);
    error PoolNotWhitelisted();

    /// @notice Creates a new position in pool and returns its NFT tokenId
    /// @param pool The pool
    /// @return tokenId
    function mint(ILicredity pool) external returns (uint256 tokenId);

    /// @notice Burns a position
    /// @param tokenId The tokenId
    function burn(uint256 tokenId) external;

    /// @notice Executes encoded commands along with provided inputs. Reverts if deadline has expired.
    /// @param commands A set of concatenated commands, each 1 byte in length
    /// @param inputs An array of byte strings containing abi encoded inputs for each command
    /// @param deadline The deadline by which the transaction must be executed
    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline) external payable;
}
