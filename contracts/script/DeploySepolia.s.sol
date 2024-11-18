// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
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

contract DeploySepoliaScript is Script {

    //BOLD///////////////////////////////////////////////////////////////////////////////////////
    address public BOLD = 0x3EF4A137b3470f0B8fFe6391eDb72d78a3Ac1E63;
    address public WETH = 0xbCDdC15adbe087A75526C0b7273Fcdd27bE9dD18;
    
    address public constant USER = 0x5C89102bcBf5Fa85f9aec152b0a3Ef89634DEcB5;
    uint256 public constant AMOUNT_COLLATERAL = 1000000000000000000000000;
    uint256 public constant AMOUNT_BOLD = 1000000000000000000000000000;

    address public constant BORROWER_OPERATIONS = 0x8fF7d450FA8Af49e386d162D80295606ef881a16;

    //UNIV4////////////////////////////////////////////////////////////////////////////////////
    
    /// @dev populated with default sepolia addresses from: https://docs.uniswap.org/contracts/v4/deployments
    IPoolManager constant POOLMANAGER = IPoolManager(address(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A));
    PositionManager constant posm = PositionManager(payable(address(0x1B1C77B606d13b09C84d1c7394B96b147bC03147)));
    IAllowanceTransfer constant PERMIT2 = IAllowanceTransfer(address(0x000000000022D473030F116dDEE9F6B43aC78BA3));
    // PoolSwapTest Contract address, default to the anvil address
    PoolSwapTest swapRouter = PoolSwapTest(0xe49d2815C231826caB58017e214Bed19fE1c2dD4);

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
    uint160 startingPrice = 1771845812700853221; // floor(sqrt(1) * 2^96)

    // --- liquidity position configuration --- //
    uint256 public token0Amount = 0;
    uint256 public token1Amount = 10e18;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;
    /////////////////////////////////////

    //HOOK/////////////////////////////////////////////////////////////////////////////////////
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function run() public returns(Hook hookContract) {
        
        //deploy mock weth TODO:remove
        MockERC20 weth = new MockERC20("Wrapped Ether", "WETH", 18);
        WETH = address(weth);

        (currency0, currency1) = SortTokens.sort(MockERC20(BOLD), MockERC20(WETH));
        //ERC20(Currency.unwrap(key.currency1))
        console.log("currency0: %s", Currency.unwrap(currency0));
        console.log("currency1: %s", Currency.unwrap(currency1));

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
        
        bytes memory hookData = new bytes(0);

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );

        // slippage limits
        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;

        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, address(this), hookData);
        
        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // initialize pool
        params[0] = abi.encodeWithSelector(posm.initializePool.selector, pool, startingPrice, hookData);

        //mint liquidity
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );

        vm.startBroadcast();
        tokenApprovals();
        vm.stopBroadcast();

        // multicall to atomically create pool & add liquidity
        vm.broadcast();
        posm.multicall(params);
    }

    /// @dev helper function for encoding mint liquidity operation
    /// @dev does NOT encode SWEEP, developers should take care when minting liquidity on an ETH pair
    function _mintLiquidityParams(
        PoolKey memory poolKey,
        int24 _tickLower,
        int24 _tickUpper,
        uint256 liquidity,
        uint256 amount0Max,
        uint256 amount1Max,
        address recipient,
        bytes memory hookData
    ) internal pure returns (bytes memory, bytes[] memory) {
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(poolKey, _tickLower, _tickUpper, liquidity, amount0Max, amount1Max, recipient, hookData);
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1);
        return (actions, params);
    }

    function tokenApprovals() public {
        ERC20 token0 = ERC20(WETH);
        ERC20 token1 = ERC20(BOLD);
        if (!currency0.isAddressZero()) {
            token0.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token0), address(posm), type(uint160).max, type(uint48).max);
        }
        if (!currency1.isAddressZero()) {
            token1.approve(address(PERMIT2), type(uint256).max);
            PERMIT2.approve(address(token1), address(posm), type(uint160).max, type(uint48).max);
        }
    }
}
