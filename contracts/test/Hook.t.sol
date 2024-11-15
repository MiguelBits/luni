// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

//BOLD
import {BorrowerOperations} from "liquity-bold/src/BorrowerOperations.sol";
import {ERC20} from "liquity-bold/lib/Solady/src/tokens/ERC20.sol";
//UNIV4
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-core/test/utils/LiquidityAmounts.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
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
    IPoolManager public poolManager = IPoolManager(0x8C4BcBE6b9eF47855f97E675296FA3F6fafa5F1A);
    using CurrencyLibrary for Currency;
    Currency public currency0;
    Currency public currency1;

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
    uint256 public token0Amount = 1e18;
    uint256 public token1Amount = 1e18;

    // range of the position
    int24 tickLower = -600; // must be a multiple of tickSpacing
    int24 tickUpper = 600;
    /////////////////////////////////////


    //HOOK/////////////////////////////////////////////////////////////////////////////////////
    Hook public hook;

    function setUp() public {
        vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/_oXBG8AigQRseN1k3i4srkLBxFeP6EJN");
        
        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(WETH, USER, AMOUNT_COLLATERAL*2);

        console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        //deal(BOLD, USER, 10 ether);

        currency0 = Currency.wrap(WETH);
        currency1 = Currency.wrap(BOLD);
        //TODO: (currency0, currency1) = SortTokens.sort(ERC20(WETH), ERC20(BOLD));

        //TODO: hook = new Hook(poolManager);

        /*
        PoolKey memory pool = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        });*/
    }

    function test_openTrove() public {
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
        if (!currency0.isAddressZero()) {
            //TODO: token0.approve(address(PERMIT2), type(uint256).max);
            //TODO: PERMIT2.approve(address(token0), address(posm), type(uint160).max, type(uint48).max);
        }
        if (!currency1.isAddressZero()) {
            //TODO: token1.approve(address(PERMIT2), type(uint256).max);
            //TODO: PERMIT2.approve(address(token1), address(posm), type(uint160).max, type(uint48).max);
        }
    }

    function test_addLiquidity() public {
        bytes memory hookData = new bytes(0);

        // --------------------------------- //

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
        /* TODO:
        (bytes memory actions, bytes[] memory mintParams) =
            _mintLiquidityParams(pool, tickLower, tickUpper, liquidity, amount0Max, amount1Max, address(this), hookData);
        */
        // multicall parameters
        bytes[] memory params = new bytes[](2);

        // initialize pool
        //TODO: params[0] = abi.encodeWithSelector(posm.initializePool.selector, pool, startingPrice, hookData);

        /*//TODO: mint liquidity
        params[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector, abi.encode(actions, mintParams), block.timestamp + 60
        );*/

        // if the pool is an ETH pair, native tokens are to be transferred
        uint256 valueToPass = currency0.isAddressZero() ? amount0Max : 0;

        // multicall
        vm.startPrank(USER);

        tokenApprovals();

        // multicall to atomically create pool & add liquidity
        //TODO : posm.multicall{value: valueToPass}(params);

        vm.stopPrank();

    }

    function test_openTrove_and_swap() public {
    
        //TODO: add liquidity
        //TODO: open trove
        //TODO: swap
        //TODO: open trove

    }

}