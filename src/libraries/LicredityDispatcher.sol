// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LicredityStateView} from "./LicredityStateView.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {FullMath} from "@licredity-v1-core/libraries/FullMath.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {IERC721} from "@forge-std/interfaces/IERC721.sol";

library LicredityDispatcher {
    using FullMath for uint256;
    using LicredityStateView for ILicredity;

    function depositFungible(ILicredity licredity, uint256 positionId, address payer, address token, uint256 amount)
        internal
    {
        if (Fungible.wrap(address(token)).isNative()) {
            licredity.depositFungible{value: amount}(positionId);
        } else {
            licredity.stageFungible(Fungible.wrap(address(token)));
            IERC20(token).transferFrom(payer, address(licredity), amount);
            licredity.depositFungible(positionId);
        }
    }

    function getNonFungible(address token, uint256 tokenId) internal pure returns (NonFungible nft) {
        assembly ("memory-safe") {
            nft := or(shl(96, token), and(tokenId, 0xffffffffffffffff))
        }
    }

    function depositNonFungible(ILicredity licredity, uint256 positionId, address payer, address token, uint256 tokenId)
        internal
    {
        NonFungible nft = getNonFungible(token, tokenId);
        licredity.stageNonFungible(nft);
        IERC721(token).transferFrom(payer, address(licredity), tokenId);
        licredity.depositNonFungible(positionId);
    }

    function withdrawFungible(
        ILicredity licredity,
        uint256 positionId,
        address recipient,
        address token,
        uint256 amount
    ) internal {
        licredity.withdrawFungible(positionId, recipient, Fungible.wrap(token), amount);
    }

    function withdrawNonFungible(
        ILicredity licredity,
        uint256 positionId,
        address recipient,
        address token,
        uint256 tokenId
    ) internal {
        NonFungible nft = getNonFungible(token, tokenId);
        licredity.withdrawNonFungible(positionId, recipient, nft);
    }

    function increaseDebtAmount(ILicredity licredity, uint256 positionId, address recipient, uint256 amount) internal {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();
        uint256 shareDelta = amount.fullMulDiv(totalShares, totalAssets);

        licredity.increaseDebtShare(positionId, shareDelta, recipient);
    }

    function increaseDebtShare(ILicredity licredity, uint256 positionId, address recipient, uint256 delta) internal {
        licredity.increaseDebtShare(positionId, delta, recipient);
    }

    function decreaseDebtAmount(
        ILicredity licredity,
        uint256 positionId,
        address payer,
        uint256 amount,
        bool useBalance
    ) internal {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();
        uint256 shareDelta = amount.fullMulDiv(totalShares, totalAssets);

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, shareDelta, true);
        } else {
            if (payer != address(this)) {
                IERC20(address(licredity)).transferFrom(payer, address(this), amount);
            }

            licredity.decreaseDebtShare(positionId, shareDelta, false);
        }
    }

    function decreaseDebtShare(ILicredity licredity, uint256 positionId, address payer, uint256 delta, bool useBalance)
        internal
    {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();

        uint256 amount = delta.fullMulDivUp(totalAssets, totalShares);

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, delta, true);
        } else {
            if (payer != address(this)) {
                IERC20(address(licredity)).transferFrom(payer, address(this), amount);
            }

            licredity.decreaseDebtShare(positionId, delta, false);
        }
    }

    /// @dev seize with nft owner transfer
    function seize(ILicredity licredity, uint256 positionId) internal {
        licredity.seize(positionId, address(this));
    }
}
