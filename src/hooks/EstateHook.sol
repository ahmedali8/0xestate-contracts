// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {console2} from "forge-std/console2.sol";

import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {BalanceDelta, BalanceDeltaLibrary} from "v4-core/src/types/BalanceDelta.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {BaseHook} from "v4-periphery/BaseHook.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {WorldIDVerify} from "../helpers/WorldIDVerify.sol";

contract EstateHook is Ownable, BaseHook, WorldIDVerify {
    using CurrencyLibrary for Currency;
    using BalanceDeltaLibrary for BalanceDelta;

    bool public isWIDVerificationTurnedOn = true;

    uint256 public buyThreshold = 30; // 30%
    uint256 public sellThreshold = 30; // 30%

    mapping(address => bool) public whitelisted;

    error BalanceGreaterThanThreshold();

    constructor(IPoolManager _poolManager, string memory _appId, string memory _actionId)
        Ownable(msg.sender)
        BaseHook(_poolManager)
        WorldIDVerify(_appId, _actionId)
    {}

    function setBuyThreshold(uint256 _buyThreshold) external onlyOwner {
        buyThreshold = _buyThreshold;
    }

    function setSellThreshold(uint256 _sellThreshold) external onlyOwner {
        sellThreshold = _sellThreshold;
    }

    function setIsWIDVerificationTurnedOn(bool _isWIDVerificationTurnedOn) external onlyOwner {
        isWIDVerificationTurnedOn = _isWIDVerificationTurnedOn;
    }

    function beforeSwap(address, PoolKey calldata, IPoolManager.SwapParams calldata, bytes calldata data)
        external
        override
        poolManagerOnly
        returns (bytes4)
    {
        // world coin check
        if (isWIDVerificationTurnedOn) {
            (address _signal, uint256 _root, uint256 _nullifierHash, uint256[8] memory _proof) =
                abi.decode(data, (address, uint256, uint256, uint256[8]));

            verifyWID(_signal, _root, _nullifierHash, _proof);
        }

        return EstateHook.beforeSwap.selector;
    }

    function afterSwap(
        address sender,
        PoolKey calldata key,
        IPoolManager.SwapParams calldata,
        BalanceDelta bal,
        bytes calldata
    ) external override poolManagerOnly returns (bytes4) {
        IERC20 token = IERC20(Currency.unwrap(key.currency1));

        // get totalSupply of token
        uint256 totalSupply = token.totalSupply();
        uint256 balance1 = token.balanceOf(sender);
        uint256 balDelta1 = uint256(int256(bal.amount1()));

        // threshold check
        if (balance1 + balDelta1 > totalSupply * buyThreshold / 100) {
            revert BalanceGreaterThanThreshold();
        }

        return EstateHook.afterSwap.selector;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false
        });
    }
}
