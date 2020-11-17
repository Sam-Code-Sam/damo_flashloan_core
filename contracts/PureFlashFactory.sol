// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./@openzeppelin/contracts/math/Math.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./@interface/IPureFlash.sol";
import "./@interface/IPureVault.sol";
import "./@libs/SafeOwnable.sol";
import "./PureFlashVault.sol";


contract PureFlashFactory is SafeOwnable{
  using SafeERC20 for IERC20;
  using Math for uint256;
  address[] public m_valts;
  mapping(address=>address) public m_token_valts;
  //保险柜默认参数
  address m_token;
  address m_profit_pool;
  uint256 m_profit_rate;  //基准值：10000
  uint256 m_loan_fee;     //基准值： MAX_LOAN_FEE = 100*10000;
  //创建保险柜的奖励
  uint256 m_create_reward;
  constructor(address token,address profitpool){
     m_token = token;
     m_profit_pool = profitpool;
     m_profit_rate = 1000; //10%
     m_loan_fee = 100*30;  //千分之3
     m_create_reward = 10*1e18;//10个pfl
  }
  
  
  function setToken(address token,uint256 createReward) onlyOwner public{
         m_token = token;
         m_create_reward = createReward;
  } 

  //设置创建保险柜的默认参数
  function defaultFee(address profitpool,uint256 profitrate,uint256 loanfee) onlyOwner public{
        m_profit_pool = profitpool;
        m_profit_rate = profitrate;
        m_loan_fee = loanfee;
  }
  
  function changeSymbol(address token,string memory sym) onlyOwner external returns(bool){
    address valt = m_token_valts[token];
    require(valt != address(0),"NO_TOKEN_VALT");
    return IPureVault(valt).changeSymbol(sym);
  }


  function setPool(address token,address profitpool) onlyOwner public returns(bool){
    address valt = m_token_valts[token];
    require(valt != address(0),"NO_TOKEN_VALT");
    return IPureVault(valt).setPool(profitpool);
  }
  
  function setProfitRate(address token,uint256 profitrate) onlyOwner public returns(bool){
    address valt = m_token_valts[token];
    require(valt != address(0),"NO_TOKEN_VALT");
    return IPureVault(valt).setProfitRate(profitrate);
  }

  function setLoanFee(address token,uint256 loanfee) onlyOwner public returns(bool){
    address valt = m_token_valts[token];
    require(valt != address(0),"NO_TOKEN_VALT");
    return IPureVault(valt).setLoanFee(loanfee);
  }


  function valtCount() public view returns(uint256){
    return m_valts.length;
  }

  function getVault(address token) public view returns(address){
        return m_token_valts[token];
  }

  function getVaultBalance(address token) public view returns(uint256){
      address valt = m_token_valts[token];
      require(valt != address(0),"NO_TOKEN_VALT");
      return IPureVault(valt).balance();
  }

   //取amount，balance,approved三个值中的最小值
  function getMinDepositAmount(address token,address user,uint256 amount) private pure returns(uint256){
       uint256 approved = IERC20(token).allowance(user,address(this));
       uint256 balance = IERC20(token).balanceOf(user);
       return amount.min(approved).min(balance);
  }
 
  //通用存款方法，存入的时候如果没有对应的保险柜，则自动创建
  function createValt(string memory sym,address token,uint256 amount) public{
      address valt = m_token_valts[token];
      require(valt == address(0),"EXIST_VALT"); 
      //constructor(address factory,address token,address profitpool,uint256 profitrate,uint256 loadfee)
      PureFlashVault newValt = new PureFlashVault(address(this),sym,token,m_profit_pool,m_profit_rate,m_loan_fee);
      address addr =  address(newValt);
      m_token_valts[token]  = addr;
      m_valts.push(addr); 
      //deposit
      if(amount >0){ 
          //取amount，balance,approved三个值中的最小值，防止因为deposit金额问题导致revert
          uint256 depositAmount = getMinDepositAmount(token,msg.sender,amount);
          if(depositAmount > 0){
              //先把创建者要deposit的金额中转到facotry
              IERC20(token).safeTransferFrom(msg.sender,address(this),amount);
              //facotry再为创建者deposit，并且把lp-token给创建者
              newValt.depositFor(amount,msg.sender);
          }
      }
      //为创建者发放token奖励
      if(m_create_reward > 0){
          uint256 pflBalance = IERC20(m_token).balanceOf(address(this));
          if(pflBalance > m_create_reward){
              IERC20(m_token).safeTransfer(msg.sender,m_create_reward);
          }
      }
  } 

}
