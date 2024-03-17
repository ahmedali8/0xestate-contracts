// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {SwapFeeLibrary} from "v4-core/src/libraries/SwapFeeLibrary.sol";
import {HookMiner} from "./utils/HookMiner.sol";
import {EstateHook} from "./hooks/EstateHook.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";

contract CreatePool is Ownable {
    using SwapFeeLibrary for uint24;
    using CurrencyLibrary for Currency;
    using PoolIdLibrary for PoolKey;

    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;

    PoolManager public manager;
    PoolModifyLiquidityTest public modifyLiquidityRouter;
    EstateHook public estateHook;

    string public appId;
    string public actionId;

    constructor(
        address _initialOwner,
        string memory _appId,
        string memory _actionId,
        PoolManager _manager,
        PoolModifyLiquidityTest _modifyLiquidityRouter
    ) Ownable(_initialOwner) {
        appId = _appId;
        actionId = _actionId;
        manager = _manager;
        modifyLiquidityRouter = _modifyLiquidityRouter;
    }

    // deploy the hook if estateHook is empty address
    function deployHookIfNeeded() public {
        if (estateHook == EstateHook(address(0))) {
            deployHook();
        }
    }

    // create a new pool and provide liquidity
    function createPoolAndProvideLiquidity(
        Currency _currency0,
        Currency _currency1,
        uint24 _fee,
        uint160 _sqrtPriceX96,
        bytes memory _initData,
        int24 _tickLower,
        int24 _tickUpper,
        int256 _liquidityDelta,
        uint256 _msgValue
    ) public payable returns (PoolKey memory key, PoolId id, BalanceDelta liquidityResult) {
        deployHookIfNeeded();
        (key, id) = initPool(_currency0, _currency1, estateHook, _fee, _sqrtPriceX96, _initData);
        address token = Currency.unwrap(_currency1);
        // liquidityResult =
        //     provideLiquidity(key, _sqrtPriceX96, _liquidityDelta, _tickLower, _tickUpper, _msgValue, token);
    }

    // deploy the hook
    function deployHook() public {
        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), flags, type(EstateHook).creationCode, abi.encode(address(manager), appId, actionId)
        );

        estateHook = new EstateHook{salt: salt}(IPoolManager(address(manager)), appId, actionId);
        require(address(estateHook) == hookAddress, "EstateHookTest: hook address mismatch");
    }

    // create a new pool
    function initPool(
        Currency _currency0,
        Currency _currency1,
        IHooks _hooks,
        uint24 _fee,
        uint160 _sqrtPriceX96,
        bytes memory _initData
    ) internal returns (PoolKey memory _key, PoolId _id) {
        _key = PoolKey(_currency0, _currency1, _fee, 60, _hooks);
        _id = _key.toId();
        manager.initialize(_key, _sqrtPriceX96, _initData);
    }

    function provideLiquidity(
        PoolKey memory _key,
        uint160 _sqrtPriceX96,
        int256 _liquidityDelta,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 _msgValue,
        address token
    ) public returns (BalanceDelta _result) {
        console2.log("msg.sender in provideLiquidity: ", msg.sender);
        console2.log("msg.sender in providerLiquidity balance: ", address(msg.sender).balance);
        console2.log("msg.sender in provideLiquidity token balance: ", IERC20(token).balanceOf(msg.sender));

        _result = modifyLiquidityRouter.modifyLiquidity{value: _msgValue}(
            _key,
            IPoolManager.ModifyLiquidityParams({
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                liquidityDelta: _liquidityDelta
            }),
            ZERO_BYTES
        );
    }
}
