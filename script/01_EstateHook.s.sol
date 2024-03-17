// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolDonateTest} from "v4-core/src/test/PoolDonateTest.sol";
import {EstateHook} from "../src/hooks/EstateHook.sol";
import {HookMiner} from "../src/utils/HookMiner.sol";

contract EstateHookScript is Script {
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);
    address constant POOLMANAGER = address(0xd962b16F4ec712D705106674E944B04614F077be);

    string public constant APP_ID = "app_staging_482e634f656d2dfd3243bf8d49c4ab7d";
    string public constant ACTION_ID = "user-verification";

    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);

        // Mine a salt that will produce a hook address with the correct flags
        (address hookAddress, bytes32 salt) = HookMiner.find(
            CREATE2_DEPLOYER, flags, type(EstateHook).creationCode, abi.encode(address(POOLMANAGER), APP_ID, ACTION_ID)
        );

        // Deploy the hook using CREATE2
        vm.broadcast();
        EstateHook estate = new EstateHook{salt: salt}(IPoolManager(address(POOLMANAGER)), APP_ID, ACTION_ID);
        require(address(estate) == hookAddress, "EstateHookScript: hook address mismatch");
    }
}

// https://sepolia.base.org
// PoolManager deployed to 0xd962b16F4ec712D705106674E944B04614F077be
// PoolModifyLiquidityTest deployed to 0x5bA874E13D2Cf3161F89D1B1d1732D14226dBF16
// PoolSwapTest deployed to 0x60AbEb98b3b95A0c5786261c1Ab830e3D2383F9e
