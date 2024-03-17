// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Estate} from "./Estate.sol";
import {VaultFactory} from "./VaultFactory.sol";
import {CreatePool} from "./CreatePool.sol";
import {Vault} from "./Vault.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Constants} from "v4-core/src/../test/utils/Constants.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {EstateHook} from "./hooks/EstateHook.sol";
import {HookMiner} from "./utils/HookMiner.sol";

contract Manager is Ownable {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    string public constant APP_ID = "app_staging_482e634f656d2dfd3243bf8d49c4ab7d";
    string public constant ACTION_ID = "user-verification";
    uint160 constant SQRT_RATIO_1_1 = Constants.SQRT_RATIO_1_1;
    bytes constant ZERO_BYTES = Constants.ZERO_BYTES;

    Estate public estate;
    VaultFactory public vaultFactory;
    CreatePool public createPool;

    PoolManager public manager;
    PoolSwapTest public swapRouter;
    PoolModifyLiquidityTest public modifyLiquidityRouter;
    string public appId;
    string public actionId;

    fallback() external {}

    receive() external payable {}

    constructor(
        address _initialOwner,
        string memory _appId,
        string memory _actionId,
        PoolManager _manager,
        PoolSwapTest _swapRouter,
        PoolModifyLiquidityTest _modifyLiquidityRouter
    ) Ownable(_initialOwner) {
        appId = _appId;
        actionId = _actionId;
        manager = _manager;
        swapRouter = _swapRouter;
        modifyLiquidityRouter = _modifyLiquidityRouter;
        vaultFactory = new VaultFactory(address(this));
    }

    struct SetupParams {
        string name;
        string symbol;
        string uri;
        Estate.AssetDetails assetDetails;
        uint256 supply;
    }

    function setup(SetupParams calldata params) public onlyOwner returns (PoolKey memory) 
    // returns (
    //     Estate estate_,
    //     Vault vault_,
    //     CreatePool createPool_,
    //     PoolKey memory key_,
    //     PoolId id_,
    //     BalanceDelta liquidityResult_
    // )
    {
        // create estate
        estate = new Estate({_name: params.name, _symbol: params.symbol, _initialOwner: address(this)});

        // mint estate
        uint256 tokenId = estate.mint({to: address(this), uri: params.uri, assetDetails: params.assetDetails});

        // approve tokenId to the vault factory
        estate.approve(address(vaultFactory), tokenId);

        // create vault (erc20 token)
        Vault vault = Vault(
            vaultFactory.createVault({
                _collection: address(estate),
                _tokenId: tokenId,
                _supply: params.supply,
                _name: params.name,
                _symbol: params.symbol
            })
        );

        address[2] memory toApprove = [address(swapRouter), address(modifyLiquidityRouter)];
        for (uint256 i = 0; i < toApprove.length; i++) {
            vault.approve(toApprove[i], Constants.MAX_UINT256);
        }

        vault.transfer(msg.sender, 10_000 * 1e18);

        // Deploy the hook to an address with the correct flags
        uint160 flags = uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG);
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this), flags, type(EstateHook).creationCode, abi.encode(address(manager), APP_ID, ACTION_ID)
        );

        EstateHook estateHook = new EstateHook{salt: salt}(IPoolManager(address(manager)), APP_ID, ACTION_ID);
        require(address(estateHook) == hookAddress, "EstateHookTest: hook address mismatch");

        // Create the pool
        PoolKey memory key = PoolKey({
            currency0: CurrencyLibrary.NATIVE, // ETH
            currency1: Currency.wrap(address(vault)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(estateHook))
        });
        PoolId poolId = key.toId();
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

        // // create pool
        // createPool = new CreatePool({
        //     _initialOwner: address(this),
        //     _appId: appId,
        //     _actionId: actionId,
        //     _manager: manager,
        //     _modifyLiquidityRouter: modifyLiquidityRouter
        // });

        // console2.log("createPool: ", address(createPool));

        // console2.log("msg.sender in manager: ", msg.sender);
        // console2.log("msg.sender in manager balance: ", address(msg.sender).balance);
        // console2.log("msg.sender in manager vault balance: ", vault.balanceOf(msg.sender));

        // // createPoolAndProvideLiquidity
        // (PoolKey memory key, PoolId id, BalanceDelta liquidityResult) = createPool.createPoolAndProvideLiquidity({
        //     _currency0: CurrencyLibrary.NATIVE, // ETH
        //     _currency1: Currency.wrap(address(vault)),
        //     _fee: 3000,
        //     _sqrtPriceX96: SQRT_RATIO_1_1,
        //     _initData: ZERO_BYTES,
        //     _tickLower: -60,
        //     _tickUpper: 60,
        //     _liquidityDelta: 10 ether,
        //     _msgValue: 2 ether
        // });

        // // Provide liquidity to the pool //

        // // Provide 10e18 worth of liquidity on the range of [-60, 60]
        // BalanceDelta result = modifyLiquidityRouter.modifyLiquidity{value: 20 ether}(
        //     key, IPoolManager.ModifyLiquidityParams(-60, 60, 1000 ether), ZERO_BYTES
        // );
        // console2.log("provideLiq1 amount0", result.amount0());
        // console2.log("provideLiq1 amount1", result.amount1());

        // // Provide 10e18 worth of liquidity on the range of [-120, 120]
        // result = modifyLiquidityRouter.modifyLiquidity{value: 2 ether}(
        //     key, IPoolManager.ModifyLiquidityParams(-120, 120, 100 ether), ZERO_BYTES
        // );
        // console2.log("provideLiq2 amount0", result.amount0());
        // console2.log("provideLiq2 amount1", result.amount1());

        return key;
        // return (estate, vault, createPool, key, id, liquidityResult);
    }
}
