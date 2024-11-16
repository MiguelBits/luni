// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
//BOLD
import {BorrowerOperations} from "liquity-bold/src/BorrowerOperations.sol";
import {ERC20} from "liquity-bold/lib/Solady/src/tokens/ERC20.sol";
//UNIV4
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {SortTokens, MockERC20} from "v4-core/test/utils/SortTokens.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
//HOOK
import {Hook} from "../src/Hook.sol";
import {HookMiner} from "v4-template/test/utils/HookMiner.sol";

contract Deploy is Script {

    //BOLD///////////////////////////////////////////////////////////////////////////////////////
    address public constant BOLD = 0x66bB78C022A0c759Ed5a679cfC840F0269f17B8f;
    address public constant WETH = 0xED7CAcC195890754B28932261Ea3235B1dCa8D15;
    
    address public constant USER = 0x5C89102bcBf5Fa85f9aec152b0a3Ef89634DEcB5;
    uint256 public constant AMOUNT_COLLATERAL = 1000000000000000000000000;
    uint256 public constant AMOUNT_BOLD = 1000000000000000000000000000;

    address public constant BORROWER_OPERATIONS = 0xf2baef98FF6b2bA5F75B22C85a56D0aDd238c347;

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
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public returns(Hook hookContract) {
        
        currency0 = Currency.wrap(WETH);
        currency1 = Currency.wrap(BOLD);
        (currency0, currency1) = SortTokens.sort(MockERC20(WETH), MockERC20(BOLD));

        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
        );
        //TODO: VERY IMPORTANT TO CHANGE
        bytes memory constructorArgs = abi.encode(POOLMANAGER, BorrowerOperations(BORROWER_OPERATIONS)); //Add all the necessary constructor arguments from the hook
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(Hook).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        hookContract = new Hook{salt: salt}(IPoolManager(POOLMANAGER), BorrowerOperations(BORROWER_OPERATIONS));
        
        require(address(hookContract) == hookAddress, "CounterScript: hook address mismatch");

        pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        }); 
    }
}
