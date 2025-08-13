// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {LicredityStateView} from "../libraries/LicredityStateView.sol";
import {ActionConstants} from "../libraries/ActionConstants.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {Fungible} from "@licredity-v1-core/types/Fungible.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {FullMath} from "@licredity-v1-core/libraries/FullMath.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";
import {IERC721} from "@forge-std/interfaces/IERC721.sol";

abstract contract LicredityRouter {
    using FullMath for uint256;
    using LicredityStateView for ILicredity;

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
            _pay(Currency.wrap(token), payer, address(licredity), amount);
            licredity.depositFungible(positionId);
        }
    }

    function getNonFungible(address token, uint256 tokenId) internal pure returns (NonFungible nft) {
        assembly ("memory-safe") {
            nft := or(shl(96, token), and(tokenId, 0xffffffffffffffff))
        }
    }

    function _depositNonFungible(
        ILicredity licredity,
        uint256 positionId,
        address payer,
        address token,
        uint256 tokenId
    ) internal {
        NonFungible nft = getNonFungible(token, tokenId);
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
        NonFungible nft = getNonFungible(token, tokenId);
        licredity.withdrawNonFungible(positionId, recipient, nft);
    }

    function _increaseDebtAmount(ILicredity licredity, uint256 positionId, address recipient, uint256 amount)
        internal
    {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();
        uint256 shareDelta = amount.fullMulDiv(totalShares, totalAssets);

        licredity.increaseDebtShare(positionId, shareDelta, recipient);
    }

    function _increaseDebtShare(ILicredity licredity, uint256 positionId, address recipient, uint256 delta) internal {
        licredity.increaseDebtShare(positionId, delta, recipient);
    }

    function _decreaseDebtAmount(
        ILicredity licredity,
        uint256 positionId,
        address payer,
        uint256 amount,
        bool useBalance
    ) internal {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();
        uint256 shareDelta;

        if (amount == ActionConstants.OPEN_DELTA) {
            shareDelta = licredity.getPositionDebtShare(positionId);
        } else {
            shareDelta = amount.fullMulDiv(totalShares, totalAssets);
        }

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, shareDelta, true);
        } else {
            if (payer != address(this)) {
                _pay(Currency.wrap(address(licredity)), payer, address(this), amount);
            }

            licredity.decreaseDebtShare(positionId, shareDelta, false);
        }
    }

    function _decreaseDebtShare(ILicredity licredity, uint256 positionId, address payer, uint256 delta, bool useBalance)
        internal
    {
        (uint256 totalShares, uint256 totalAssets) = licredity.getTotalDebt();

        if (delta == ActionConstants.OPEN_DELTA) {
            delta = licredity.getPositionDebtShare(positionId);
        }

        if (useBalance) {
            licredity.decreaseDebtShare(positionId, delta, true);
        } else {
            uint256 amount = delta.fullMulDivUp(totalAssets, totalShares);

            if (payer != address(this)) {
                _pay(Currency.wrap(address(licredity)), payer, address(this), amount);
            }

            licredity.decreaseDebtShare(positionId, delta, false);
        }
    }

    function _seize(ILicredity licredity, uint256 positionId) internal {
        licredity.seize(positionId, address(this));
    }

    function _exchange(ILicredity licredity, address payer, address recipient, uint256 amount) internal {
        Fungible baseFungible = LicredityStateView.getBaseFungible(licredity);

        if (baseFungible.isNative()) {
            licredity.exchangeFungible{value: amount}(recipient, true);
        } else {
            licredity.stageFungible(baseFungible);
            _pay(Currency.wrap(Fungible.unwrap(baseFungible)), payer, address(licredity), amount);
            licredity.exchangeFungible(recipient, true);
        }
    }

    /// @notice Abstract function for contracts to implement paying tokens to the poolManager
    /// @param token The token to settle. This is known not to be the native currency
    /// @param payer The address who should pay tokens
    /// @param recipient The address who should receive tokens
    /// @param amount The number of tokens to send

    function _pay(Currency token, address payer, address recipient, uint256 amount) internal virtual;
}
