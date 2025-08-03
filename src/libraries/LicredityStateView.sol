// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";

library LicredityStateView {
    uint256 internal constant BASE_FUNGIBLE_OFFSET = 13;
    uint256 internal constant TOTAL_DEBT_SHARE_OFFSET = 16;
    uint256 internal constant TOTAL_DEBT_BALANCE_OFFSET = 17;

    function getTotalDebt(ILicredity manager) internal view returns (uint256 totalShares, uint256 totalAssets) {
        totalShares = uint256(manager.extsload(bytes32(TOTAL_DEBT_SHARE_OFFSET)));
        totalAssets = uint256(manager.extsload(bytes32(TOTAL_DEBT_BALANCE_OFFSET)));
    }

    function getBaseFungible(ILicredity manager) internal view returns (Fungible baseFungible) {
        baseFungible = Fungible.wrap(address(uint160(uint256(manager.extsload(bytes32(BASE_FUNGIBLE_OFFSET))))));
    }
}
