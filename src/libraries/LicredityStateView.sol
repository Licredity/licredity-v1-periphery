// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";

library LicredityStateView {
    uint256 public constant TOTAL_DEBT_SHARE_OFFSET = 16;
    uint256 public constant TOTAL_DEBT_BALANCE_OFFSET = 17;
    uint256 public constant POSITIONS_OFFSET = 25;

    function getTotalDebt(ILicredity manager) internal view returns (uint256 totalShares, uint256 totalAssets) {
        totalShares = uint256(manager.extsload(bytes32(TOTAL_DEBT_SHARE_OFFSET)));
        totalAssets = uint256(manager.extsload(bytes32(TOTAL_DEBT_BALANCE_OFFSET)));
    }

    function _getPositionSlot(uint256 positionId) internal pure returns (bytes32 slot) {
        assembly ("memory-safe") {
            mstore(0x00, positionId)
            mstore(0x20, POSITIONS_OFFSET)
            slot := keccak256(0x00, 0x40)
        }
    }

    function getPositionDebtShare(ILicredity manager, uint256 positionId) internal view returns (uint256 debtShare) {
        bytes32 stateSlot = _getPositionSlot(positionId);
        bytes32 debtSlot = bytes32(uint256(stateSlot) + 1);

        debtShare = uint256(manager.extsload(debtSlot));
    }
}
