// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {Hook} from "../src/Hook.sol";

contract Deploy is Script {
    function run() public {
        vm.startBroadcast();
        new Hook();
        vm.stopBroadcast();
    }
}
