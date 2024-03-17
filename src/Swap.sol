// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

contract Swap {
    using CurrencyLibrary for Currency;

    uint160 public constant MIN_PRICE_LIMIT = TickMath.MIN_SQRT_RATIO + 1;
    uint160 public constant MAX_PRICE_LIMIT = TickMath.MAX_SQRT_RATIO - 1;

    PoolSwapTest public swapRouter;
    PoolManager public manager;

    constructor(PoolSwapTest _swapRouter, PoolManager _manager) {
        swapRouter = _swapRouter;
        manager = _manager;
    }

    /// @notice Helper function for a simple Native-token swap that allows for unlimited price impact
    function swapNativeInput(
        PoolKey memory _key,
        bool _zeroForOne,
        int256 _amountSpecified, // negative number indicates exact input swap!
        bytes memory _hookData,
        uint256 _msgValue
    ) public returns (BalanceDelta) {
        require(_key.currency0.isNative(), "currency0 is not native. Use swap() instead");
        if (_zeroForOne == false) require(_msgValue == 0, "msgValue must be 0 for oneForZero swaps");

        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: _zeroForOne,
            amountSpecified: _amountSpecified,
            sqrtPriceLimitX96: _zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({withdrawTokens: true, settleUsingTransfer: true, currencyAlreadySent: false});

        return swapRouter.swap{value: _msgValue}(_key, params, testSettings, _hookData);
    }
}
