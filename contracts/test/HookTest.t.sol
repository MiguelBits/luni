// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "./Helpers.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";

contract HookTest is Helpers {
    using PoolIdLibrary for PoolKey;
    using TickMath for uint160;

    uint256 public tokenId;
    PoolId poolId;

    function setUp() public {
        //vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/_oXBG8AigQRseN1k3i4srkLBxFeP6EJN");

        currency1 = Currency.wrap(WETH);
        currency0 = Currency.wrap(BOLD);
        (currency0, currency1) = SortTokens.sort(MockERC20(WETH), MockERC20(BOLD));
        console.log("currency0: %s", Currency.unwrap(currency0));
        console.log("currency1: %s", Currency.unwrap(currency1));

        // Deploy the hook to an address with the correct flags
        address flags = address(
            uint160(
                Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
            ) ^ (0x4444 << 144) // Namespace the hook to avoid collisions
        );
        //TODO: VERY IMPORTANT TO CHANGE
        bytes memory constructorArgs = abi.encode(POOLMANAGER, BorrowerOperations(BORROWER_OPERATIONS)); //Add all the necessary constructor arguments from the hook
        deployCodeTo("Hook.sol:Hook", constructorArgs, flags);

        hookContract = Hook(flags);
        poolKey = PoolKey({
            currency0: currency0,
            currency1: currency1,
            fee: lpFee,
            tickSpacing: tickSpacing,
            hooks: hookContract
        }); 
        console2.log("pool hook address: %s", address(hookContract));
        
        //create initialize pool params
        bytes[] memory multicallParams = new bytes[](2);
        multicallParams[0] = abi.encodeWithSelector(
            posm.initializePool.selector,
            poolKey,
            startingPrice
        );
        
        bytes memory actions = abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));

        //mint liquidity position params
        uint256 amount0Max = token0Amount + 1 wei;
        uint256 amount1Max = token1Amount + 1 wei;
        bytes memory hookData = new bytes(0);

        int24 tick = startingPrice.getTickAtSqrtPrice();
        console.log("tick: %d", tick);
        tickLower = (tick - 1000) / tickSpacing * tickSpacing; // Round down to nearest valid tick
        tickUpper = (tick + 1000) / tickSpacing * tickSpacing; // Round down to nearest valid tick

        // Converts token amounts to liquidity units
        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            startingPrice,
            TickMath.getSqrtPriceAtTick(tickLower),
            TickMath.getSqrtPriceAtTick(tickUpper),
            token0Amount,
            token1Amount
        );
        console.log("liquidity: %d", liquidity);

        bytes[] memory mintParams = new bytes[](2);
        mintParams[0] = abi.encode(poolKey, tickLower, tickUpper, liquidity, amount0Max, amount1Max, USER, hookData);
        mintParams[1] = abi.encode(poolKey.currency0, poolKey.currency1);

        //mint liquidity position multicall params
        uint256 deadline = block.timestamp + 60;
        multicallParams[1] = abi.encodeWithSelector(
            posm.modifyLiquidities.selector, abi.encode(actions, mintParams), deadline
        );

        //give USER tokens to mint liquidity position
        deal(WETH, USER, token1Amount);
        deal(BOLD, USER, token0Amount);
        console.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        console.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));

        vm.startPrank(USER);

        // approve PERMIT2 as a spender
        IERC20(WETH).approve(address(PERMIT2), type(uint256).max);
        IERC20(BOLD).approve(address(PERMIT2), type(uint256).max);
        // approve `PositionManager` as a spender
        IAllowanceTransfer(address(PERMIT2)).approve(WETH, address(posm), type(uint160).max, type(uint48).max);
        IAllowanceTransfer(address(PERMIT2)).approve(BOLD, address(posm), type(uint160).max, type(uint48).max);

        posm.multicall(multicallParams);

        vm.stopPrank();

        console.log("liquidity added");
        (, tick,,) = state.getSlot0(poolKey.toId());
        console.log("tick: %d", tick);
    }
    /*
    function test_getCurrentTick() public {
        uint160 startingPrice = 79228162514264337593543950336 * uint160(sqrt(2000)); // your price
        int24 tick = startingPrice.getTickAtSqrtPrice();
        console.log("Current Tick for 1/2000 price:", tick);
    }*/

    function test_setup() public {
        console.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        console.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));

        uint128 liquidity = state.getLiquidity(poolKey.toId());
        console.log("liquidity: %d", liquidity);
    
        bool zeroForOne = false;
        uint128 inputAmount = 1e18;

        uint256 amountOut = getQuoteExactInputSingle(inputAmount, zeroForOne);
        console.log("amountOut: %s", amountOut);
    }

    function test_openTrove() public {

       // console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(WETH, USER, AMOUNT_COLLATERAL*2);

        //console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

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

        //bold balance before open trove
        //console.log("b4 user balance", ERC20(BOLD).balanceOf(USER));

        vm.startPrank(USER);

        //approve
        ERC20(WETH).approve(BORROWER_OPERATIONS, type(uint256).max);
        BorrowerOperations(BORROWER_OPERATIONS).openTrove(
            address(2),
            0,
            AMOUNT_COLLATERAL,
            AMOUNT_BOLD,
            0,
            0,
            50000000000000000,
            type(uint256).max,
            address(2),
            address(2),
            address(2)
        );

        vm.stopPrank();
        //console.log("af user balance", ERC20(BOLD).balanceOf(USER));

        //console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        //console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));
    }

    ///@dev end with bold in wallet
    ///@notice swap weth for bold
    function test_swapHook_wethForBold() public {

        //log balances of user
        console.log("B4 USER SWAP bold:", ERC20(BOLD).balanceOf(USER));
        console.log("B4 USER SWAP weth:", ERC20(WETH).balanceOf(USER));

        bool zeroForOne = false; //swap weth for bold
        uint256 weth_amount = 10e18;
        uint256 bold_amount = 2000e18;

        //calculate upfront fee
        uint256 upfrontFee = 37500000000000000;
        //uint256 upfrontFee = calculateUpfrontFee(0, bold_amount, 0.05 ether); //0.05 ether is the lowest annual interest rate possible
        //console.log("upfrontFee: %d", upfrontFee);

        deal(WETH, USER, weth_amount + upfrontFee);

        //swap
        _swap(weth_amount, bold_amount, zeroForOne, upfrontFee);

        //log balances of user
        console.log("AF USER SWAP bold: %d", ERC20(BOLD).balanceOf(USER));
        console.log("AF USER SWAP weth: %d", ERC20(WETH).balanceOf(USER));
    }

}