pragma solidity ^0.7.0;
//"SPDX-License-Identifier: UNLICENSED" 

import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol"; 
import "./@libs/SafeOwnable.sol";
import "./@interface/IExchange.sol";

//池子1--社区利润池--用社区的利润，回购市场上流通的Token
//功能：1、社区应得的利润会转入本合约ETH
//     2、社区利润池定期再回购FEA接口
//     3、社区利润池FEA再流通（多签机制）
contract PureProfitMaker is SafeOwnable{
    //防止算术溢出
    using SafeMath for uint256; 
    using SafeERC20 for IERC20;
 
    address m_token;
     //够着函数
    constructor(address token)  { 
       m_token = token;
    }

    function setToken(address token) onlyOwner public{
         m_token = token;
    } 

     /**社区利润池FEA再流通（多签机制）
     */
     function PFLReFund(uint256 amount) onlyOwner  public returns(bool){
         //社区利润回购后的PFL，再次通过任务的方式分配给社区
         address goverance = msg.sender; 
         IERC20(m_token).safeTransfer(goverance,amount);
     }
     
     //2、社区利润池定期再回购FEA接口
     //exchange 交易所地址，amount，回购的PFL数量
     function BuyPFL(address exchange,address tokenUse,uint256 amountIn,uint256 minOut) onlyOwner public returns(uint256){
         address[] memory path = new address[](2);  
         path[0]  = tokenUse;
         path[1]  = m_token;    
        //对proxy进行额度授权
        IERC20(tokenUse).safeApprove(address(exchange),0);
        IERC20(tokenUse).safeApprove(address(exchange),amountIn);
        //通过交易所兑换 
        uint256[] memory amount = IExchange(exchange).swapExactTokensForTokens(amountIn,minOut,path,address(this),block.timestamp+3600);
        return amount[1];
     }

     

}