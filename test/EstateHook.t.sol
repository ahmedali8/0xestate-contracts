// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {MockERC20} from "solmate/test/utils/mocks/MockERC20.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {EstateHook} from "../src/hooks/EstateHook.sol";
import {Constants} from "v4-core/test/utils/Constants.sol";

contract EstateHookTest is Test, Deployers {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    string public constant APP_ID = "app_staging_482e634f656d2dfd3243bf8d49c4ab7d";
    string public constant ACTION_ID = "user-verification";

    Currency currency;
    MockERC20 token;

    EstateHook estate;
    PoolId poolId;

    function setUp() public {
        // creates the pool manager, utility routers, and test tokens
        Deployers.deployFreshManagerAndRouters();

        token = new MockERC20("TEST", "TEST", 18);
        currency = Currency.wrap(address(token));

        token.mint(address(this), 10_000_000_000 * 1e18);

        address[6] memory toApprove = [
            address(swapRouter),
            address(modifyLiquidityRouter),
            address(donateRouter),
            address(takeRouter),
            address(claimsRouter),
            address(nestedActionRouter.executor())
        ];

        for (uint256 i = 0; i < toApprove.length; i++) {
            token.approve(toApprove[i], Constants.MAX_UINT256);
        }

        vm.prank(address(this));
        token.transfer(msg.sender, 10_000 * 1e18);

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), flags, type(EstateHook).creationCode, abi.encode(address(manager), APP_ID, ACTION_ID)
        );

        estate = new EstateHook{salt: salt}(IPoolManager(address(manager)), APP_ID, ACTION_ID);
        require(address(estate) == hookAddress, "EstateHookTest: hook address mismatch");

        // Create the pool
        key = PoolKey({
            currency0: CurrencyLibrary.NATIVE, // ETH
            currency1: currency,
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(estate))
        });
        poolId = key.toId();
        manager.initialize(key, SQRT_RATIO_1_1, ZERO_BYTES);

        // Provide liquidity to the pool //

        // Provide 10e18 worth of liquidity on the range of [-60, 60]
        BalanceDelta result = modifyLiquidityRouter.modifyLiquidity{value: 20 ether}(
            key, IPoolManager.ModifyLiquidityParams(-60, 60, 1000 ether), ZERO_BYTES
        );
        console2.log("provideLiq1 amount0", result.amount0());
        console2.log("provideLiq1 amount1", result.amount1());

        // Provide 10e18 worth of liquidity on the range of [-120, 120]
        result = modifyLiquidityRouter.modifyLiquidity{value: 2 ether}(
            key, IPoolManager.ModifyLiquidityParams(-120, 120, 100 ether), ZERO_BYTES
        );
        console2.log("provideLiq2 amount0", result.amount0());
        console2.log("provideLiq2 amount1", result.amount1());
    }

    // msg.sender is swapRouter (PoolSwapTest)
    function testSwap() public {
        address user1 = address(0x1234);
        vm.deal(user1, 10 ether);
        vm.startPrank({msgSender: user1});

        // Perform a test swap //
        bool zeroForOne = true;
        int256 amountSpecified = -1 ether; // negative number indicates exact input swap!

        // Random data for testing
        address _signal = 0xAb8483F64d9C6d1EcF9b849Ae677dD3315835cb2;
        uint256 _root = 123456;
        uint256 _nullifierHash = 789012;
        uint8[8] memory _proof8 = [1, 2, 3, 4, 5, 6, 7, 8];
        uint256[8] memory _proof;
        for (uint256 i = 0; i < 8; i++) {
            _proof[i] = uint256(_proof8[i]);
        }
        // Encode the data
        bytes memory mockHookData = abi.encode(_signal, _root, _nullifierHash, _proof);

        BalanceDelta swapDelta = Deployers.swapNativeInput({
            _key: key,
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            // hookData: ZERO_BYTES,
            hookData: mockHookData,
            msgValue: 1 ether
        });

        console2.log("swapDelta amount0", swapDelta.amount0());
        console2.log("swapDelta amount1", swapDelta.amount1());

        assertEq(int256(swapDelta.amount0()), amountSpecified);
        assert(int256(swapDelta.amount1()) > 0);
    }
}
