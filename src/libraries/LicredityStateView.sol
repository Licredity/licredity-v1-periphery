// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";

library LicredityStateView {
    uint256 public constant POSITIONS_OFFSET = 23;

    function getTotalDebt(ILicredity manager) internal view returns (uint256 totalShares, uint256 totalAssets) {
        totalShares = manager.totalDebtShare();
        totalAssets = manager.totalDebtBalance();
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

    function getBaseFungible(ILicredity manager) internal view returns (Fungible baseFungible) {
        baseFungible = manager.baseFungible();
    }
}
