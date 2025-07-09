// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";

library LicredityStateView {
    uint256 public constant TOTAL_DEBT_SHARE_OFFSET = 18;
    uint256 public constant TOTAL_DEBT_BALANCE_OFFSET = 19;

    function getTotalDebt(ILicredity manager) internal view returns (uint256 totalShares, uint256 totalAssets) {
        totalShares = uint256(manager.extsload(bytes32(TOTAL_DEBT_SHARE_OFFSET)));
        totalAssets = uint256(manager.extsload(bytes32(TOTAL_DEBT_BALANCE_OFFSET)));
    }
}
