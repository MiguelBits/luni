pragma solidity 0.8.24;

interface ILuniHook {
    struct LuniHookData {
        uint256 collateralAmount;
        uint256 debtAmount;
        uint256 upfrontFee;
        address caller;
    }
}