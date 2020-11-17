//"SPDX-License-Identifier: UNLICENSED" 
pragma solidity ^0.7.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IPureFlash {
    function OnFlashLoan(address token,uint256 amount, uint256 rAmount,bytes calldata userdata) external;
}