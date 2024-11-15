// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";

import {BorrowerOperations} from "liquity-bold/src/BorrowerOperations.sol";

contract OpenTroveTest is Test {

    address public constant BOLD = 0x3EF4A137b3470f0B8fFe6391eDb72d78a3Ac1E63;
    address public constant WETH = 0xbCDdC15adbe087A75526C0b7273Fcdd27bE9dD18;
    
    address public constant USER = makeAddr("USER");

    address public constant BORROWER_OPERATIONS = 0x8fF7d450FA8Af49e386d162D80295606ef881a16;

    function setup() public {
        vm.createSelectFork(vm.envString("SEPOLIA_RPC_URL"));
        deal(WETH, USER, 10 ether);
        //deal(BOLD, USER, 10 ether);
    }
}