// SPDX-License-Identifier: Unlicense
pragma solidity ^0.7.0;
 


interface IERC20Info {
     
    function name() external  returns (string memory);
    function symbol() external  returns (string memory);
    function decimals() external  returns (uint8);
}