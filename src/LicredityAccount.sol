// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {UniswapV4Router} from "./base/UniswapV4Router.sol";
import {LicredityRouter} from "./base/LicredityRouter.sol";
import {PositionManagerConfig} from "./PositionManagerConfig.sol";
import {ActionsData, Actions} from "./types/Actions.sol";
import {CalldataDecoder} from "./libraries/CalldataDecoder.sol";
import {ActionConstants} from "./libraries/ActionConstants.sol";
import {NonFungible} from "@licredity-v1-core/types/NonFungible.sol";
import {Currency} from "@uniswap-v4-core/types/Currency.sol";
import {ILicredityAccount} from "./interfaces/ILicredityAccount.sol";
import {IAllowanceTransfer} from "./interfaces/external/IAllowanceTransfer.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract LicredityAccount is ILicredityAccount, UniswapV4Router, LicredityRouter, PositionManagerConfig {
    using CalldataDecoder for bytes;

    address transient lockedBy;
    ILicredity transient usingLicredity;
    uint256 transient usingLicredityPositionId;

    constructor(
        address _governor,
        IPoolManager _uniswapV4poolManager,
        address _uniswapV4PostionManager,
        IAllowanceTransfer _permit2
    )
        UniswapV4Router(_uniswapV4poolManager, _uniswapV4PostionManager)
        PositionManagerConfig(_governor, _permit2)
        LicredityRouter()
    {}

    modifier isNotLocked() {
        require(lockedBy == address(0), ContractLocked());
        lockedBy = msg.sender;
        _;
        lockedBy = address(0);
    }

    modifier checkDeadline(uint256 deadline) {
        require(block.timestamp <= deadline, DeadlinePassed(deadline));
        _;
    }

    function msgSender() internal view returns (address) {
        return lockedBy;
    }

    function open(ILicredity market) external onlyGovernor returns (uint256 positionId) {
        return market.open();
    }

    function close(ILicredity market, uint256 positionId) external onlyGovernor {
        return market.close(positionId);
    }

    function sweepFungible(Currency currency, address recipient, uint256 amount) external onlyGovernor {
        currency.transfer(recipient, amount);
    }

    function sweepNonFungible(NonFungible nonFungible, address recipient) external onlyGovernor {
        nonFungible.transfer(recipient);
    }

    function execute(ILicredity licredity, bytes calldata inputs, uint256 deadline)
        external
        payable
        isNotLocked
        checkDeadline(deadline)
    {
        usingLicredity = licredity;

        usingLicredity.unlock(inputs);

        usingLicredity = ILicredity(address(0));
        usingLicredityPositionId = 0;
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        if (msg.sender == address(poolManager)) {
            (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams();
            uint256 numActions = actions.length;
            require(numActions == params.length, InputLengthMismatch());

            for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
                uint256 action = uint8(actions[actionIndex]);

                _handleUniswapV4Action(action, params[actionIndex]);
            }
        } else if (msg.sender == address(usingLicredity)) {
            (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams();
            uint256 numActions = actions.length;
            require(numActions == params.length, InputLengthMismatch());

            for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
                uint256 action = uint8(actions[actionIndex]);

                _handleLicredityAction(action, params[actionIndex]);
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

    function _handleLicredityAction(uint256 action, bytes calldata params) internal {
        if (action == Actions.SWITCH) {
            uint256 positionId = params.decodePositionId();
            usingLicredityPositionId = positionId;
            return;
        } else if (action == Actions.DEPOSIT_FUNGIBLE) {
            (bool payerIsUser, address token, uint256 amount) = params.decodeDeposit();
            _depositFungible(usingLicredity, usingLicredityPositionId, _mapPayer(payerIsUser), token, amount);

            return;
        } else if (action == Actions.DEPOSIT_NON_FUNGIBLE) {
            (bool payerIsUser, address token, uint256 tokenId) = params.decodeDeposit();
            _depositNonFungible(usingLicredity, usingLicredityPositionId, _mapPayer(payerIsUser), token, tokenId);

            return;
        } else if (action == Actions.WITHDRAW_FUNGIBLE) {
            (address recipient, address token, uint256 amount) = params.decodeWithdraw();
            _withdrawFungible(usingLicredity, usingLicredityPositionId, _mapRecipient(recipient), token, amount);

            return;
        } else if (action == Actions.WITHDRAW_NON_FUNGIBLE) {
            (address recipient, address token, uint256 tokenId) = params.decodeWithdraw();
            _withdrawNonFungible(usingLicredity, usingLicredityPositionId, _mapRecipient(recipient), token, tokenId);
            return;
        } else if (action == Actions.INCREASE_DEBT_AMOUNT) {
            (address recipient, uint256 amount) = params.decodeIncreaseDebt();
            _increaseDebtAmount(usingLicredity, usingLicredityPositionId, _mapRecipient(recipient), amount);
            return;
        } else if (action == Actions.INCREASE_DEBT_SHARE) {
            (address recipient, uint256 shares) = params.decodeIncreaseDebt();
            _increaseDebtShare(usingLicredity, usingLicredityPositionId, _mapRecipient(recipient), shares);
            return;
        } else if (action == Actions.DECREASE_DEBT_AMOUNT) {
            (bool payerIsUser, uint256 amount, bool useBalance) = params.decodeDecreaseDebt();
            _decreaseDebtAmount(usingLicredity, usingLicredityPositionId, _mapPayer(payerIsUser), amount, useBalance);
            return;
        } else if (action == Actions.DECREASE_DEBT_SHARE) {
            (bool payerIsUser, uint256 shares, bool useBalance) = params.decodeDecreaseDebt();
            _decreaseDebtShare(usingLicredity, usingLicredityPositionId, _mapPayer(payerIsUser), shares, useBalance);
            return;
        } else if (action == Actions.SEIZE) {
            uint256 positionId = params.decodePositionId();
            _seize(usingLicredity, positionId);
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
            return msgSender();
        } else if (recipient == ActionConstants.ADDRESS_THIS) {
            return address(this);
        } else {
            return recipient;
        }
    }

    /// @notice Calculates the payer for an action
    function _mapPayer(bool payerIsUser) internal view returns (address) {
        return payerIsUser ? msgSender() : address(this);
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
