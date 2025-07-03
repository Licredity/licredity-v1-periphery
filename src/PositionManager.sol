// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity =0.8.30;

import {IPositionManager} from "./interfaces/IPositionManager.sol";
import {ERC721} from "./base/ERC721.sol";
import {PositionManagerConfig} from "./PositionManagerConfig.sol";
import {PositionInfo, PositionInfoLibrary} from "./types/PositionInfo.sol";
import {LicredityDispatcher} from "./libraries/LicredityDispatcher.sol";
import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {IPoolManager} from "@uniswap-v4-core/interfaces/IPoolManager.sol";
import {IERC20} from "@forge-std/interfaces/IERC20.sol";

contract PositionManager is IPositionManager, ERC721, PositionManagerConfig {
    using LicredityDispatcher for ILicredity;

    IPoolManager public immutable uniswapV4PoolManager;

    address transient lockedBy;
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

    function burn(uint256 tokenId) external {
        PositionInfo info = positionInfo[tokenId];
        ILicredity pool = ILicredity(info.pool());

        pool.close(info.positionId());
    }

    function depositFungible(uint256 tokenId, IERC20 token, uint256 amount) external {
        PositionInfo info = positionInfo[tokenId];
        info.pool().depositFungible(info.positionId(), msg.sender, token, amount);
    }

    function depositNonFungible(uint256 tokenId, address token, uint256 depsoittTokenId) external {
        PositionInfo info = positionInfo[tokenId];
        info.pool().depositNonFungible(info.positionId(), msg.sender, token, depsoittTokenId);
    }

    function execute(bytes calldata commands, bytes[] calldata inputs, uint256 deadline)
        external
        payable
        isNotLocked
        checkDeadline(deadline)
    {}
}
