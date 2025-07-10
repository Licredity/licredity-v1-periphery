// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {IPositionManagerConfig} from "./interfaces/IPositionManagerConfig.sol";
import {IAllowanceTransfer} from "./interfaces/external/IAllowanceTransfer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract PositionManagerConfig is IPositionManagerConfig {
    address internal governor;
    address internal nextGovernor;
    IAllowanceTransfer immutable permit2;

    mapping(ILicredity pool => bool) internal isWhitelisted;

    modifier onlyGovernor() {
        _onlyGovernor();
        _;
    }

    function _onlyGovernor() internal view {
        // require(caller() == governor, NotGovernor());
        assembly ("memory-safe") {
            if iszero(eq(caller(), sload(governor.slot))) {
                mstore(0x00, 0xee3675d4) // 'NotGovernor()'
                revert(0x1c, 0x04)
            }
        }
    }

    constructor(address _governor, IAllowanceTransfer _permit2) {
        governor = _governor;
        permit2 = _permit2;
    }

    /// @notice Appoints the next governor
    /// @param _nextGovernor The next governor
    function appointNextGovernor(address _nextGovernor) external onlyGovernor {
        assembly ("memory-safe") {
            sstore(nextGovernor.slot, and(_nextGovernor, 0xffffffffffffffffffffffffffffffffffffffff))

            // emit AppointNextGovernor(_nextGovernor);
            log2(0x00, 0x00, 0x192874f7d03868e0e27e79172ef01f27e1200fd3a5b08d7b3986fbe037125ee8, _nextGovernor)
        }
    }

    /// @notice Confirms the new governor
    function confirmNextGovernor() external {
        assembly ("memory-safe") {
            // require(caller() == nextGovernor, NotNextGovernor());
            if iszero(eq(caller(), sload(nextGovernor.slot))) {
                mstore(0x00, 0x7dc8c6f8) // 'NotNextGovernor()'
                revert(0x1c, 0x04)
            }

            let lastGovernor := sload(governor.slot)

            // transfer governor role to the next governor and clear nextGovernor
            sstore(governor.slot, caller())
            sstore(nextGovernor.slot, 0x00)

            // emit ConfirmNextGovernor(lastGovernor, caller());
            log3(0x00, 0x00, 0x7c33d066bdd1139ec2077fef5825172051fa827c50f89af128ae878e44e44632, lastGovernor, caller())
        }
    }

    function updatePoolWhitelist(address pool, bool isWhitelist) external onlyGovernor {
        assembly ("memory-safe") {
            pool := and(pool, 0xffffffffffffffffffffffffffffffffffffffff)
            mstore(0x00, pool)
            mstore(0x20, isWhitelisted.slot)
            let pooSlot := keccak256(0x00, 0x40)
            sstore(pooSlot, isWhitelist)

            mstore(0x00, isWhitelist)
            log2(0x00, 0x20, 0x91ef39ee8c3c89707b54eb6b6f42111e61eb0e8f3c3bd73e3c3b9c0340d4715f, pool)
        }
    }

    function updateTokenPermit2(address token, address spender, uint160 amount, uint48 expiration)
        external
        onlyGovernor
    {
        IERC20(token).approve(address(permit2), amount);
        permit2.approve(token, spender, amount, expiration);
    }

    function updateTokenApporve(address token, address spender, uint160 amount) external onlyGovernor {
        IERC20(token).approve(spender, amount);
    }
}
