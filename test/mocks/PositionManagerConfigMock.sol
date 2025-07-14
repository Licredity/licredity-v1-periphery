// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.30;

import {ILicredity} from "@licredity-v1-core/interfaces/ILicredity.sol";
import {PositionManagerConfig} from "src/PositionManagerConfig.sol";
import {IAllowanceTransfer} from "src/interfaces/external/IAllowanceTransfer.sol";

contract PositionManagerConfigMock is PositionManagerConfig {
    constructor(address _governor, IAllowanceTransfer _permit2) PositionManagerConfig(_governor, _permit2) {}

    function loadGovernor() external view returns (address) {
        return governor;
    }

    function loadNextGovernor() external view returns (address) {
        return nextGovernor;
    }

    function loadPoolWhitelist(ILicredity pool) external view returns (bool) {
        return isWhitelisted[pool];
    }
}
