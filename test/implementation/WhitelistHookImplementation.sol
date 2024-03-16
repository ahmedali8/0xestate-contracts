// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {WhitelistHook} from "../../src/WhitelistHook.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

contract WhitelistHookImplementation is WhitelistHook {
    constructor(IPoolManager poolManager, WhitelistHook addressToEtch) WhitelistHook(poolManager) {
        Hooks.validateHookPermissions(addressToEtch, getHookPermissions());
    }

    // make this a no-op in testing
    function validateHookAddress(BaseHook _this) internal pure override {}
}
