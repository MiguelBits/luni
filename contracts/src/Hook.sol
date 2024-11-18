// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

//TODO: Useful for debugging. Remove when deploying to a live network.
import "forge-std/console.sol";

import {ILuniHook} from "./interfaces/ILuniHook.sol";

import {ERC20} from "solmate/src/tokens/ERC20.sol";

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {CurrencySettler} from "v4-core/test/utils/CurrencySettler.sol";

//BOLD
import {BorrowerOperations} from "liquity-bold/src/BorrowerOperations.sol";

contract Hook is BaseHook, ILuniHook {
    using PoolIdLibrary for PoolKey;
    using CurrencySettler for Currency;

    BorrowerOperations public borrowOps;

    constructor(IPoolManager _poolManager, BorrowerOperations _borrowOps) BaseHook(_poolManager) {
        borrowOps = _borrowOps;
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    // -----------------------------------------------
    // NOTE: see IHooks.sol for function documentation
    // -----------------------------------------------

    function beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata swapParams, bytes calldata hookData)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        console.log("beforeSwap");

        //console.log("swapParams.zeroForOne: %s", (swapParams.zeroForOne ? "true" : "false"));
        //console.log("address currency0: %s", Currency.unwrap(key.currency0));
        //console.log("address currency1: %s", Currency.unwrap(key.currency1));

        LuniHookData memory _data = abi.decode(hookData, (LuniHookData));
        //console.log("debtAmount: %s", _data.debtAmount);
        //console.log("caller: %s", _data.caller);

        if(_data.debtAmount == 0) {
            return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
        }

        //prepare variables for if statements
        ERC20 tokenWETH = ERC20(Currency.unwrap(key.currency1));
        ERC20 tokenBOLD = ERC20(Currency.unwrap(key.currency0));    
        BalanceDelta delta;
        console.log("swapParams.amountSpecified: %s", swapParams.amountSpecified);

        if (!swapParams.zeroForOne) { //swap token1 for token0
            console.log("SWAP TOKEN1 FOR TOKEN0");
            //console.log("token1 address: %s", address(tokenWETH));
            //transfer token1 to contract
            tokenWETH.transferFrom(_data.caller, address(this), uint256(swapParams.amountSpecified) + _data.upfrontFee); //TODO: change
            //console.log("token1 balance of contract: %s", tokenWETH.balanceOf(address(this)));
            //approve token1 to borrowOps
            tokenWETH.approve(address(borrowOps), type(uint256).max); //TODO: change

            //console.log("OPEN TROVE");

            //console.log("BEFORE BOLD balance of USER: %s", tokenBOLD.balanceOf(_caller));
            //console.log("BOLD balance of CONTRACT: %s", tokenBOLD.balanceOf(address(this)));

            //borrow BOLD 
            //console.log("b4 USER balance", tokenBOLD.balanceOf(_caller));
            borrowOps.openTrove(
                _data.caller, //_owner
                0, //_ownerIndex
                uint256(swapParams.amountSpecified), //_collAmount
                _data.debtAmount, //_boldAmount
                0, //_upperHint
                0, //_lowerHint
                50000000000000000, //_annualInterestRate
                type(uint256).max, //_maxUpfrontFee
                _data.caller, //_addManager
                _data.caller, //_removeManager
                _data.caller //_receiver
            );
            //console.log("OPENed TROVE");
            
            tokenBOLD.transfer(_data.caller, _data.debtAmount);
            //console.log("af USER balance", tokenBOLD.balanceOf(msg.sender));
            
            //swap BOLD for WETH
            //new swap params
            IPoolManager.SwapParams memory newSwapParams = IPoolManager.SwapParams(
                false,
                int256(_data.debtAmount),
                TickMath.MAX_SQRT_PRICE - 1
            );

            //console.log("b4 USER swap balance", tokenBOLD.balanceOf(_caller));
            //console.log("b4 USER swap balance", tokenWETH.balanceOf(address(this)));

            delta = poolManager.swap(
                key,
                newSwapParams,
                abi.encode(0, _data.caller)
            );

        }
        else { //swap token0 for token1
            //console.log("SWAP TOKEN0 FOR TOKEN1");
            
        }
        
        //_calculateUniswapDeltas(delta, key, _data.caller);
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function afterSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata , BalanceDelta delta, bytes calldata hookData)
        external
        override
        returns (bytes4, int128)
    {
        console.log("afterSwap");

        LuniHookData memory _data = abi.decode(hookData, (LuniHookData));

        if(_data.debtAmount == 0) {
            return (BaseHook.afterSwap.selector, 0);
        }
        
        console.log("delta.amount0(): %s", delta.amount0());
        console.log("delta.amount1(): %s", delta.amount1());

        _calculateUniswapDeltas(delta, key, _data.caller);

        return (BaseHook.afterSwap.selector, 0);
    }

    function _calculateUniswapDeltas(BalanceDelta delta, PoolKey memory key, address _caller) internal {
        // Handle token0 (BOLD) settlement
        int256 amount0 = delta.amount0();
        if (amount0 < 0) {
            // Negative delta means tokens owed to the user
            key.currency0.settle(poolManager, _caller, uint256(-amount0), false);
        } else if (amount0 > 0) {
            // Positive delta means tokens owed to the pool
            key.currency0.take(poolManager, _caller, uint256(amount0), false);
        }

        // Handle token1 (WETH) settlement if needed
        int256 amount1 = delta.amount1(); 
        if (amount1 < 0) {
            key.currency1.settle(poolManager, _caller, uint256(-amount1), false);
        } else if (amount1 > 0) {
            key.currency1.take(poolManager, _caller, uint256(amount1), false);
        }

        console.log("delta.amount0(): %s", delta.amount0());
        console.log("delta.amount1(): %s", delta.amount1());
    }

}
