// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ActionConstants} from "../libraries/ActionConstants.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible, NonFungibleLibrary} from "@licredity-v1-core/types/NonFungible.sol";
import {FullMath} from "@licredity-v1-core/libraries/FullMath.sol";
import {PositionStateView} from "@licredity-v1-core/libraries/PositionStateView.sol";
import {IERC721} from "@forge-std/interfaces/IERC721.sol";

abstract contract LicredityRouter {
    using FullMath for uint256;
    using PositionStateView for ILicredity;

    function _depositFungible(ILicredity licredity, uint256 positionId, address payer, address token, uint256 amount)
        internal
    {
        if (amount == ActionConstants.OPEN_DELTA) {
            amount = Fungible.wrap(token).balanceOf(address(this));
        }

        if (Fungible.wrap(token).isNative()) {
            licredity.depositFungible{value: amount}(positionId);
        } else {
            licredity.stageFungible(Fungible.wrap(token));
            _pay(Fungible.wrap(token), payer, address(licredity), amount);
            licredity.depositFungible(positionId);
        }
    }

    function _depositNonFungible(
        ILicredity licredity,
        uint256 positionId,
        address payer,
        address token,
        uint256 tokenId
    ) internal {
        NonFungible nft = NonFungibleLibrary.from(token, tokenId);
        licredity.stageNonFungible(nft);
        IERC721(token).transferFrom(payer, address(licredity), tokenId);
        licredity.depositNonFungible(positionId);
    }

    function _withdrawFungible(
        ILicredity licredity,
        uint256 positionId,
        address recipient,
        address token,
        uint256 amount
    ) internal {
        licredity.withdrawFungible(positionId, recipient, Fungible.wrap(token), amount);
    }

    function _withdrawNonFungible(
        ILicredity licredity,
        uint256 positionId,
        address recipient,
        address token,
        uint256 tokenId
    ) internal {
        NonFungible nft = NonFungibleLibrary.from(token, tokenId);
        licredity.withdrawNonFungible(positionId, recipient, nft);
    }

    function _increaseDebtAmount(ILicredity licredity, uint256 positionId, address recipient, uint256 amount)
        internal
    {
        uint256 totalShares = licredity.totalDebtShare();
        uint256 totalAssets = licredity.totalDebtBalance();

        uint256 shareDelta = amount.fullMulDiv(totalShares, totalAssets);

        licredity.increaseDebtShare(positionId, shareDelta, recipient);
    }

    function _increaseDebtShare(ILicredity licredity, uint256 positionId, address recipient, uint256 delta) internal {
        licredity.increaseDebtShare(positionId, delta, recipient);
    }

    function _decreaseDebtAmount(ILicredity licredity, uint256 positionId, uint256 amount, bool useBalance) internal {
        uint256 totalShares = licredity.totalDebtShare();
        uint256 totalAssets = licredity.totalDebtBalance();

        uint256 shareDelta;

        if (amount == ActionConstants.OPEN_DELTA) {
            shareDelta = licredity.getPositionDebtShare(positionId);
        } else {
            shareDelta = amount.fullMulDiv(totalShares, totalAssets);
        }

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, shareDelta, true);
        } else {
            licredity.decreaseDebtShare(positionId, shareDelta, false);
        }
    }

    function _decreaseDebtShare(ILicredity licredity, uint256 positionId, uint256 delta, bool useBalance) internal {
        if (delta == ActionConstants.OPEN_DELTA) {
            delta = licredity.getPositionDebtShare(positionId);
        }

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, delta, true);
        } else {
            licredity.decreaseDebtShare(positionId, delta, false);
        }
    }

    function _seize(ILicredity licredity, uint256 positionId, address recipient) internal {
        licredity.seizePosition(positionId, recipient);
    }

    function _exchangeFungible(ILicredity licredity, address payer, address recipient, uint256 amount) internal {
        Fungible baseFungible = licredity.baseFungible();

        if (baseFungible.isNative()) {
            licredity.exchangeFungible{value: amount}(recipient, true);
        } else {
            licredity.stageFungible(baseFungible);
            _pay(baseFungible, payer, address(licredity), amount);
            licredity.exchangeFungible(recipient, true);
        }
    }

    /// @notice Abstract function for contracts to implement paying tokens to the poolManager
    /// @param token The token to settle. This is known not to be the native currency
    /// @param payer The address who should pay tokens
    /// @param recipient The address who should receive tokens
    /// @param amount The number of tokens to send

    function _pay(Fungible token, address payer, address recipient, uint256 amount) internal virtual;
}
