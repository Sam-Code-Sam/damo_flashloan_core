// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

/**
 * @dev 以下接口固定下来了，不要随意改动
 */
interface IPureFlash { 
     function OnFlashLoan(address token,uint256 amount, uint256 rAmount,bytes calldata userdata) external;
}

interface IPureVault{
    function startFlashLoan(address dealer,uint256 amount,bytes calldata userdata) external;
}

interface IVaultFactory { 
    function getVault(address token) external returns(address);
    function getVaultBalance(address token) external returns(uint256); 
}