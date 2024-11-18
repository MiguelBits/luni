// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;


import "./Helpers.sol";

contract HookTest is Helpers {

    function setUp() public {
        //vm.createSelectFork("https://eth-sepolia.g.alchemy.com/v2/_oXBG8AigQRseN1k3i4srkLBxFeP6EJN");
        vm.deal(USER, 1000 ether);

        currency1 = Currency.wrap(WETH);
        currency0 = Currency.wrap(BOLD);
        (currency0, currency1) = SortTokens.sort(MockERC20(WETH), MockERC20(BOLD));

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
            115792089237316195423570985008687907853269984665640564039457584007913129639935,
            address(2),
            address(2),
            address(2)
        );

        vm.stopPrank();
        //console.log("af user balance", ERC20(BOLD).balanceOf(USER));

        //console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));
        //console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));
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
        ERC20 token1  = ERC20(WETH);
        ERC20 token0 = ERC20(BOLD);
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
        
        //console2.log("liquidity: %s", liquidity);
        //console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(WETH, USER, token1Amount);

        //console2.log("WETH balance of USER: %s", ERC20(WETH).balanceOf(USER));

        deal(BOLD, USER, token0Amount);

        //console2.log("BOLD balance of USER: %s", ERC20(BOLD).balanceOf(USER));

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

        //log liquidity

    }

    ///@dev end with bold in wallet
    ///@notice swap weth for bold
    function test_swapHook_wethForBold() public {
        //add liquidity
        test_addLiquidity();

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