// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Hook} from "../src/Hook.sol";

contract Deploy is Script {

    //BOLD///////////////////////////////////////////////////////////////////////////////////////
    address public constant BOLD = 0x66bb78c022a0c759ed5a679cfc840f0269f17b8f;
    address public constant WETH = 0xed7cacc195890754b28932261ea3235b1dca8d15;
    
    address public constant USER = 0x5C89102bcBf5Fa85f9aec152b0a3Ef89634DEcB5;
    uint256 public constant AMOUNT_COLLATERAL = 1000000000000000000000000;
    uint256 public constant AMOUNT_BOLD = 1000000000000000000000000000;

    address public constant BORROWER_OPERATIONS = 0xf2baef98ff6b2ba5f75b22c85a56d0add238c347;

    //UNIV4////////////////////////////////////////////////////////////////////////////////////
    
    /// @dev populated with default sepolia addresses from: https://docs.uniswap.org/contracts/v4/deployments
    IPoolManager constant POOLMANAGER = IPoolManager(address(0xC81462Fec8B23319F288047f8A03A57682a35C1A));
    PositionManager constant posm = PositionManager(payable(address(0xB433cB9BcDF4CfCC5cAB7D34f90d1a7deEfD27b9)));

    // PoolSwapTest Contract address, default to the anvil address
    PoolSwapTest swapRouter = PoolSwapTest(0xe437355299114d35Ffcbc0c39e163B24A8E9cBf1);
    using CurrencyLibrary for Currency;
    Currency public currency0;
    Currency public currency1;
    PoolKey pool;
    /////////////////////////////////////
    // --- Parameters to Configure --- //
    /////////////////////////////////////

    // --- pool configuration --- //
    // fees paid by swappers that accrue to liquidity providers
    uint24 lpFee = 3000; // 0.30%
    int24 tickSpacing = 60;

    // starting price of the pool, in sqrtPriceX96
    uint160 startingPrice = 79228162514264337593543950336; // floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 10e18;
    uint256 public token1Amount = 50000e18;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;
    /////////////////////////////////////


    //HOOK/////////////////////////////////////////////////////////////////////////////////////
    Hook public hookContract;

    function run() public {
        
        currency0 = Currency.wrap(WETH);
        currency1 = Currency.wrap(BOLD);
        (currency0, currency1) = SortTokens.sort(MockERC20(WETH), MockERC20(BOLD));

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        //TODO: VERY IMPORTANT TO CHANGE
        bytes memory constructorArgs = abi.encode(POOLMANAGER, BorrowerOperations(BORROWER_OPERATIONS)); //Add all the necessary constructor arguments from the hook
        
        vm.startBroadcast();
        deployCodeTo("Hook.sol:Hook", constructorArgs, flags);
        vm.stopBroadcast();

        hookContract = Hook(flags);
        pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        }); 
    }
}
