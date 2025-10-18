// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

struct ExecutePlan {
    bytes actions;
    bytes[] params;
}

using ExecutePlanner for ExecutePlan global;

library ExecutePlanner {
    function init() internal pure returns (ExecutePlan memory plan) {
        return ExecutePlan({actions: bytes(""), params: new bytes[](0)});
    }

    function add(ExecutePlan memory plan, uint256 action, bytes memory param)
        internal
        pure
        returns (ExecutePlan memory)
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

    function encode(ExecutePlan memory plan, uint256 deadline) internal pure returns (bytes memory action) {
        return abi.encode(deadline, plan.actions, plan.params);
    }
}
