// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {ERC721} from "./base/ERC721.sol";
import {PositionManagerConfig} from "./PositionManagerConfig.sol";
import {PositionInfo, PositionInfoLibrary} from "./types/PositionInfo.sol";
import {ActionsData, Actions} from "./types/Actions.sol";
import {ActionConstants} from "./libraries/ActionsConstants.sol";
import {CalldataDecoder} from "./libraries/CalldataDecoder.sol";
import {LicredityDispatcher} from "./libraries/LicredityDispatcher.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap-v4-core/interfaces/callback/IUnlockCallback.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract PositionManager is IPositionManager, IUnlockCallback, ERC721, PositionManagerConfig {
    using CalldataDecoder for bytes;
    using LicredityDispatcher for ILicredity;

    IPoolManager public immutable uniswapV4PoolManager;

    address transient lockedBy;
    ILicredity transient usingLicredity;
    uint256 transient usingLicredityPositionId;

    uint256 public nextTokenId = 1;

    mapping(uint256 tokenId => PositionInfo info) internal positionInfo;

    constructor(address _governor, IPoolManager _poolManager)
        ERC721("Licredity v1 Position NFT", "LICREDITY-V1-POSM")
        PositionManagerConfig(_governor)
    {
        uniswapV4PoolManager = _poolManager;
    }

    // TODO: May be not implemented
    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

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

    modifier onlyIfApproved(address caller, uint256 tokenId) {
        require(_isApprovedOrOwner(caller, tokenId), NotApproved(caller));
        _;
    }

    function msgSender() internal view returns (address) {
        return lockedBy;
    }

    function mint(ILicredity pool) external returns (uint256 tokenId) {
        require(isWhitelisted[pool], PoolNotWhitelisted());

        unchecked {
            tokenId = nextTokenId++;
        }
        _mint(msg.sender, tokenId);

        uint256 positionId = pool.open();
        positionInfo[tokenId] = PositionInfoLibrary.from(address(pool), positionId);
    }

    function burn(uint256 tokenId) external onlyIfApproved(msg.sender, tokenId) {
        PositionInfo info = positionInfo[tokenId];
        ILicredity pool = ILicredity(info.pool());

        _burn(tokenId);
        pool.close(info.positionId());
    }

    function depositFungible(uint256 tokenId, address token, uint256 amount) external payable {
        PositionInfo info = positionInfo[tokenId];
        info.pool().depositFungible(info.positionId(), msg.sender, token, amount);
    }

    function depositNonFungible(uint256 tokenId, address token, uint256 depsoittTokenId) external {
        PositionInfo info = positionInfo[tokenId];
        info.pool().depositNonFungible(info.positionId(), msg.sender, token, depsoittTokenId);
    }

    function execute(ActionsData[] calldata inputs, uint256 deadline)
        external
        payable
        isNotLocked
        checkDeadline(deadline)
    {
        for (uint256 i = 0; i < inputs.length; i++) {
            ActionsData calldata input = inputs[i];
            if (input.tokenId != 0) {
                require(_isApprovedOrOwner(msgSender(), input.tokenId), NotApproved(msgSender()));
                usingLicredity = positionInfo[input.tokenId].pool();
                usingLicredityPositionId = positionInfo[input.tokenId].positionId();

                usingLicredity.unlock(input.unlockData);
            } else {
                uniswapV4PoolManager.unlock(input.unlockData);
            }
        }
    }

    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        (bytes calldata actions, bytes[] calldata params) = data.decodeActionsRouterParams();
        uint256 numActions = actions.length;
        require(numActions == params.length, InputLengthMismatch());
        if (msg.sender == address(uniswapV4PoolManager)) {
            // for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
            //     uint256 action = uint8(actions[actionIndex]);

            //     _handleUniswapV4Action(action, params[actionIndex]);
            // }
        } else {
            for (uint256 actionIndex = 0; actionIndex < numActions; actionIndex++) {
                uint256 action = uint8(actions[actionIndex]);

                _handleLicredityAction(action, params[actionIndex]);
            }
        }

        return "";
    }

    function _handleLicredityAction(uint256 action, bytes calldata params) internal {
        if (action == Actions.DEPOSIT_FUNGIBLE) {
            (bool payerIsUser, address token, uint256 amount) = params.decodeDeposit();
            usingLicredity.depositFungible(usingLicredityPositionId, _mapPayer(payerIsUser), token, amount);

            return;
        } else if (action == Actions.DEPOSIT_NON_FUNGIBLE) {
            (bool payerIsUser, address token, uint256 tokenId) = params.decodeDeposit();
            usingLicredity.depositNonFungible(usingLicredityPositionId, _mapPayer(payerIsUser), token, tokenId);

            return;
        } else if (action == Actions.WITHDRAW_FUNGIBLE) {
            (address recipient, address token, uint256 amount) = params.decodeWithdraw();
            usingLicredity.withdrawFungible(usingLicredityPositionId, _mapRecipient(recipient), token, amount);

            return;
        } else if (action == Actions.WITHDRAW_NON_FUNGIBLE) {
            (address recipient, address token, uint256 tokenId) = params.decodeWithdraw();
            usingLicredity.withdrawNonFungible(usingLicredityPositionId, _mapRecipient(recipient), token, tokenId);
            return;
        } else if (action == Actions.INCREASE_DEBT_AMOUNT) {
            (address recipient, uint256 amount) = params.decodeIncreaseDebt();
            usingLicredity.increaseDebtAmount(usingLicredityPositionId, _mapRecipient(recipient), amount);
            return;
        } else if (action == Actions.INCREASE_DEBT_SHARE) {
            (address recipient, uint256 shares) = params.decodeIncreaseDebt();
            usingLicredity.increaseDebtShare(usingLicredityPositionId, _mapRecipient(recipient), shares);
            return;
        } else if (action == Actions.DECREASE_DEBT_AMOUNT) {
            (bool payerIsUser, uint256 amount, bool useBalance) = params.decodeDecreaseDebt();
            usingLicredity.decreaseDebtAmount(usingLicredityPositionId, _mapPayer(payerIsUser), amount, useBalance);
            return;
        } else if (action == Actions.DECREASE_DEBT_SHARE) {
            (bool payerIsUser, uint256 shares, bool useBalance) = params.decodeDecreaseDebt();
            usingLicredity.decreaseDebtShare(usingLicredityPositionId, _mapPayer(payerIsUser), shares, useBalance);
            return;
        } else if (action == Actions.SEIZE) {
            uint256 seizedTokenId = params.decodeSeizeTokenId();
            uint256 seizedPositionId = positionInfo[seizedTokenId].positionId();

            usingLicredity.seize(seizedPositionId);
            usingLicredityPositionId = seizedPositionId;

            _transfer(msgSender(), seizedTokenId);
            return;
        } else if (action == Actions.DYN_CALL) {
            assembly ("memory-safe") {
                let fmp := mload(0x40)
                let target := calldataload(params.offset)
                let value := calldataload(add(params.offset, 0x20))
                let dataLen := calldataload(add(params.offset, 0x60))

                calldatacopy(fmp, add(params.offset, 0x80), dataLen)

                let success := call(gas(), target, value, fmp, dataLen, 0x00, 0x00)

                if iszero(success) {
                    mstore(0x00, 0x674ac132) // `CallFailure()`
                    revert(0x1c, 0x04)
                }
            }

            return;
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
}
