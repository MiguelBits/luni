// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";

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

contract HookTest is Test {

    //BOLD///////////////////////////////////////////////////////////////////////////////////////
    address public constant BOLD = 0x3EF4A137b3470f0B8fFe6391eDb72d78a3Ac1E63;
    address public constant WETH = 0xbCDdC15adbe087A75526C0b7273Fcdd27bE9dD18;
    
    address public constant USER = address(1);
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

    function setUp() public {
        vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/_oXBG8AigQRseN1k3i4srkLBxFeP6EJN");

        currency0 = Currency.wrap(WETH);
        currency1 = Currency.wrap(BOLD);
        (currency0, currency1) = SortTokens.sort(MockERC20(WETH), MockERC20(BOLD));

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        bytes memory constructorArgs = abi.encode(POOLMANAGER); //Add all the necessary constructor arguments from the hook
        deployCodeTo("Hook.sol:Hook", constructorArgs, flags);

        hookContract = Hook(flags);
        pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        }); 
        console2.log("pool hook address: %s", address(hookContract));
        //add pool
    }

    function test_openTrove() public {

        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(WETH, USER, AMOUNT_COLLATERAL*2);

        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        //deal(BOLD, USER, 10 ether);
        /*
            0	_owner	address	0x3b1b0C2Bf68D0e2304960E1F32c607771B8CFE01
            1	_ownerIndex	uint256	0
            2	_collAmount	uint256	1000000000000000000000000
            3	_boldAmount	uint256	1000000000000000000000000000
            4	_upperHint	uint256	0
            5	_lowerHint	uint256	0
            6	_annualInterestRate	uint256	50000000000000000
            7	_maxUpfrontFee	uint256	115792089237316195423570985008687907853269984665640564039457584007913129639935
            8	_addManager	address	0x0000000000000000000000000000000000000000
            9	_removeManager	address	0x0000000000000000000000000000000000000000
            10	_receiver	address	0x0000000000000000000000000000000000000000
        */
        vm.startPrank(USER);

        //approve
        ERC20(WETH).approve(BORROWER_OPERATIONS, type(uint256).max);
        BorrowerOperations(BORROWER_OPERATIONS).openTrove(
            USER,
            0,
            AMOUNT_COLLATERAL,
            AMOUNT_BOLD,
            0,
            0,
            50000000000000000,
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000,
            0x0000000000000000000000000000000000000000
        );

        vm.stopPrank();

        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));
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

    function test_addLiquidity() public {
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
        
        console2.log("liquidity: %s", liquidity);
                console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(WETH, USER, token0Amount);

        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(BOLD, USER, token1Amount);

        console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));

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

        // if the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

        // multicall
        vm.startPrank(USER);

        tokenApprovals();

        // multicall to atomically create pool & add liquidity
        posm.multicall{value: valueToPass}(params);

        vm.stopPrank();

    }

    function _swap(int256 amountSpecified) public {

        // slippage tolerance to allow for unlimited price impact
        uint160 MIN_PRICE_LIMIT = TickMath.MIN_SQRT_PRICE + 1;
        uint160 MAX_PRICE_LIMIT = TickMath.MAX_SQRT_PRICE - 1;
        bool zeroForOne = true;
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: amountSpecified,
            sqrtPriceLimitX96: zeroForOne ? MIN_PRICE_LIMIT : MAX_PRICE_LIMIT // unlimited impact
        });

        // in v4, users have the option to receieve native ERC20s or wrapped ERC1155 tokens
        // here, we'll take the ERC20s
        PoolSwapTest.TestSettings memory testSettings =
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false});

        deal(WETH, USER, uint256(amountSpecified)*2);
        deal(BOLD, USER, uint256(amountSpecified)*2);
        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));

        bytes memory hookData = new bytes(0);

        ERC20 token0 = ERC20(WETH);
        ERC20 token1 = ERC20(BOLD);

        vm.startPrank(USER);

        //approve
        token0.approve(address(swapRouter), type(uint256).max);
        token1.approve(address(swapRouter), type(uint256).max);

        swapRouter.swap(pool, params, testSettings, hookData);
        vm.stopPrank();

    }

    function test_openTrove_and_swap() public {
    
        //add liquidity
        test_addLiquidity();
        //open trove
        test_openTrove();
        
        //swap
        _swap(1e18);

    }

}