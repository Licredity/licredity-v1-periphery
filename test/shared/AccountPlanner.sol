// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct AccountPlan {
    bytes actions;
    bytes[] params;
}

using AccountPlanner for AccountPlan global;

library AccountPlanner {
    function init() internal pure returns (AccountPlan memory plan) {
        return AccountPlan({actions: bytes(""), params: new bytes[](0)});
    }

    function add(AccountPlan memory plan, uint256 action, bytes memory param)
        internal
        pure
        returns (AccountPlan memory)
    {
        bytes memory actions = new bytes(plan.params.length + 1);
        bytes[] memory params = new bytes[](plan.params.length + 1);

        for (uint256 i; i < params.length - 1; i++) {
            params[i] = plan.params[i];
            actions[i] = plan.actions[i];
        }
        params[params.length - 1] = param;
        actions[params.length - 1] = bytes1(uint8(action));

        plan.actions = actions;
        plan.params = params;

        return plan;
    }

    function encode(AccountPlan memory plan) internal pure returns (bytes memory action) {
        return abi.encode(plan.actions, plan.params);
    }
}
