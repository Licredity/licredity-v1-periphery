// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {UniswapV4Router} from "./base/UniswapV4Router.sol";
import {LicredityRouter} from "./base/LicredityRouter.sol";
import {Multicall_v4} from "./base/Multicall_v4.sol";
import {ApproveHelper} from "./ApproveHelper.sol";
import {Actions} from "./types/Actions.sol";
import {CalldataDecoder} from "./libraries/CalldataDecoder.sol";
import {ActionConstants} from "./libraries/ActionConstants.sol";
import {ILicredityExecutor} from "./interfaces/ILicredityAccount.sol";
import {IAllowanceTransfer} from "./interfaces/external/IAllowanceTransfer.sol";
import {IUniswapV4PositionManager} from "./interfaces/external/IUniswapV4PositionManager.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract LicredityExecutor is ILicredityExecutor, UniswapV4Router, LicredityRouter, ApproveHelper, Multicall_v4 {
    using CalldataDecoder for bytes;

    address transient msgSender;

    constructor(IPoolManager _uniswapV4poolManager, address _uniswapV4PostionManager, IAllowanceTransfer _permit2)
        UniswapV4Router(_uniswapV4poolManager, _uniswapV4PostionManager)
        ApproveHelper(_permit2)
        LicredityRouter()
    {}

    modifier isNotLocked(address sender) {
        require(msgSender == address(0), ContractLocked());
        msgSender = sender;
        _;
        msgSender = address(0);
    }

    function checkDeadline(uint256 deadline) internal view {
        if (deadline < block.timestamp) {
            revert DeadlinePassed(deadline);
        }
    }

    function execute(address sender, bytes calldata data) external payable isNotLocked(sender) returns (bytes memory) {
        uint256 deadline = data.decodeOffset(0x00);
        (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams(0x20);
        checkDeadline(deadline);

        uint256 numActions = actions.length;
        require(numActions == params.length, InputLengthMismatch());

        for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            uint256 action = uint8(actions[actionIndex]);

            _handleLicredityAction(ILicredity(msg.sender), action, params[actionIndex]);
        }

        return "";
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender == address(POOL_MANAGER)) {
            (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams(0x00);
            uint256 numActions = actions.length;
            require(numActions == params.length, InputLengthMismatch());

            for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
                uint256 action = uint8(actions[actionIndex]);

                _handleUniswapV4Action(action, params[actionIndex]);
            }
        } else {
            revert NotSafeCallback();
        }

        return "";
    }

    function _handleUniswapV4Action(uint256 action, bytes calldata params) internal {
        if (action == Actions.UNISWAP_V4_SWAP) {
            _swap(params);
            return;
        } else if (action == Actions.UNISWAP_V4_SETTLE) {
            (Currency currency, uint256 amount, bool payerIsUser) = params.decodeCurrencyUint256AndBool();
            _settle(currency, _mapPayer(payerIsUser), _mapSettleAmount(amount, currency));
            return;
        } else if (action == Actions.UNISWAP_V4_TAKE) {
            (Currency currency, address recipient, uint256 amount) = params.decodeCurrencyAddressAndUint256();
            _take(currency, _mapRecipient(recipient), _mapTakeAmount(amount, currency));
            return;
        } else if (action == Actions.UNISWAP_V4_SWEEP) {
            (Currency currency, address to) = params.decodeCurrencyAndAddress();
            _sweep(currency, _mapRecipient(to));
            return;
        }
    }

    function _handleLicredityAction(ILicredity licredity, uint256 action, bytes calldata params) internal {
        if (action == Actions.DEPOSIT_FUNGIBLE) {
            (uint256 positionId, bool payerIsUser, address token, uint256 amount) =
                params.decodeBoolUint256AddressAndUint256();
            _depositFungible(licredity, positionId, _mapPayer(payerIsUser), token, amount);

            return;
        } else if (action == Actions.DEPOSIT_NON_FUNGIBLE) {
            (uint256 positionId, bool payerIsUser, address token, uint256 tokenId) =
                params.decodeBoolUint256AddressAndUint256();
            _depositNonFungible(licredity, positionId, _mapPayer(payerIsUser), token, _mapTokenId(token, tokenId));

            return;
        } else if (action == Actions.WITHDRAW_FUNGIBLE) {
            (uint256 positionId, address recipient, address token, uint256 amount) = params.decodeWithdraw();
            _withdrawFungible(licredity, positionId, _mapRecipient(recipient), token, amount);

            return;
        } else if (action == Actions.WITHDRAW_NON_FUNGIBLE) {
            (uint256 positionId, address recipient, address token, uint256 tokenId) = params.decodeWithdraw();
            _withdrawNonFungible(licredity, positionId, _mapRecipient(recipient), token, tokenId);
            return;
        } else if (action == Actions.INCREASE_DEBT_AMOUNT) {
            (uint256 positionId, address recipient, uint256 amount) = params.decodeIncreaseDebt();
            _increaseDebtAmount(licredity, positionId, _mapRecipient(recipient), amount);
            return;
        } else if (action == Actions.INCREASE_DEBT_SHARE) {
            (uint256 positionId, address recipient, uint256 shares) = params.decodeIncreaseDebt();
            _increaseDebtShare(licredity, positionId, _mapRecipient(recipient), shares);
            return;
        } else if (action == Actions.DECREASE_DEBT_AMOUNT) {
            (uint256 positionId, uint256 amount, bool useBalance) = params.decodeDecreaseDebt();
            _decreaseDebtAmount(licredity, positionId, amount, useBalance);
            return;
        } else if (action == Actions.DECREASE_DEBT_SHARE) {
            (uint256 positionId, uint256 shares, bool useBalance) = params.decodeDecreaseDebt();
            _decreaseDebtShare(licredity, positionId, shares, useBalance);
            return;
        } else if (action == Actions.SEIZE) {
            (uint256 positionId, address recipient) = params.decodeSeizedPosition();
            _seize(licredity, positionId, _mapRecipient(recipient));
            return;
        } else if (action == Actions.EXCHANGE) {
            (bool payerIsUser, address recipient, uint256 amount) = params.decodeBoolAddressAndUint256();
            _exchangeFungible(licredity, _mapPayer(payerIsUser), _mapRecipient(recipient), amount);
            return;
        } else if (action == Actions.UNISWAP_V4_POSITION_MANAGER_CALL) {
            (uint256 positionValue, bytes calldata positionParams) = params.decodeCallValueAndData();
            _positionManagerCall(positionValue, positionParams);
            return;
        } else if (action == Actions.UNISWAP_V4_POOL_MANAGER_CALL) {
            _uniswapPoolManagerCall(params);
            return;
        } else if (action == Actions.DYN_CALL) {
            // abi.decode(params, (address target, uint256 value, bytes data));
            assembly ("memory-safe") {
                let fmp := mload(0x40)
                let target := calldataload(params.offset)

                // Check if target is whitelisted
                mstore(0x00, target)
                mstore(0x20, isWhitelistedRouter.slot)
                let routerSlot := keccak256(0x00, 0x40)

                if iszero(sload(routerSlot)) {
                    mstore(0x00, 0xceb35066) // `DynCallTargetError()`
                    revert(0x1c, 0x04)
                }

                let value := calldataload(add(params.offset, 0x20))
                let dataLen := calldataload(add(params.offset, 0x60))

                calldatacopy(fmp, add(params.offset, 0x80), dataLen)

                let success := call(gas(), target, value, fmp, dataLen, 0x00, 0x00)

                if iszero(success) {
                    mstore(0x00, 0x674ac132) // `CallFailure()`
                    revert(0x1c, 0x04)
                }
            }
        }
    }

    /// @notice Calculates the address for a action
    function _mapRecipient(address recipient) internal view returns (address) {
        if (recipient == ActionConstants.MSG_SENDER) {
            return msgSender;
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }

    function _mapTokenId(address token, uint256 tokenId) internal view returns (uint256) {
        if (tokenId == ActionConstants.DEPOSIT_TOKEN_ID) {
            uint256 nextUniswapV4PositionTokenId = IUniswapV4PositionManager(token).nextTokenId();
            return nextUniswapV4PositionTokenId - 1;
        } else {
            return tokenId;
        }
    }

    /// @notice Calculates the payer for an action
    function _mapPayer(bool payerIsUser) internal view returns (address) {
        return payerIsUser ? msgSender : address(this);
    }

    function _pay(Currency currency, address payer, address recipient, uint256 amount)
        internal
        override(LicredityRouter, UniswapV4Router)
    {
        if (payer == address(this)) {
            currency.transfer(recipient, amount);
        } else {
            IERC20(Currency.unwrap(currency)).transferFrom(payer, recipient, amount);
        }
    }

    receive() external payable {}
}
