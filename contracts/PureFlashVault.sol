// SPDX-License-Identifier: MIT
pragma solidity ^0.7.0;

import "./@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "./@openzeppelin/contracts/math/SafeMath.sol";
import "./@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./@interface/IPureFlash.sol";
import "./@interface/IPureVault.sol";
import "./@libs/ERC20Detailed.sol";

contract PureFlashVault is ERC20,ReentrancyGuard,IPureVault{
  using SafeMath  for uint256;
  using SafeERC20 for IERC20;
  
  IERC20 m_token;
  string  m_symbol;
  address m_factory;
  address m_profitpool;
  uint256 m_profit_rate;
  uint256 m_loan_fee;
  uint256 constant MAX_LOAN_FEE = 100*10000;
  //记录存款数据
  uint256 m_total_deposits;
  mapping(address=>uint256) m_users_deposit;
  //记录用户的历史利润
  mapping(address=>uint256) m_users_hprofit;
  constructor(address factory,string memory sym,address token,address profitpool,uint256 profitrate,uint256 loadfee)  
  ERC20(string(abi.encodePacked("PFL-", ERC20Detailed(token).name())),
        string(abi.encodePacked("u", ERC20Detailed(token).symbol())) ){
       m_symbol = sym;
       m_factory = factory;
       m_token = IERC20(token);
       m_profitpool = profitpool;
       m_profit_rate = profitrate;
       m_loan_fee = loadfee;
  }

   modifier onlyFactory(){
       require(msg.sender == m_factory,"NEED_FROM_FACTORY");
       _;
   }
   

   function changeSymbol(string memory sym) onlyFactory external override returns(bool){
      m_symbol = sym;
      return true;
   }

   function setPool(address profitpool) onlyFactory external override returns(bool){
      m_profitpool = profitpool;
     return true;
   }
   function setProfitRate(uint256 profitrate) onlyFactory external override returns(bool){
       m_profit_rate = profitrate;
       return true;
   }
   function setLoanFee(uint256 loanfee)  onlyFactory external override  returns(bool){
       m_loan_fee = loanfee;
       return true;
   } 

   function balance() public view override returns(uint256){
        return m_token.balanceOf(address(this));
    }
    
    function vaultInfo() public view 
    returns(string memory sym,address addr,uint256 tvl,uint256 fee,uint256 s,uint256 td){
        sym  = m_symbol;
        addr = address(m_token);
        tvl  = balance();
        fee  = minFee(100*1e18);
        s    = sharePrice();
        td   = m_total_deposits;
    }

    //获取某个用户的所有相关信息，便于UI显示
    function userInfo(address user) public view 
    returns(string memory sym,address addr,uint256 tvl,uint256 b,uint256 d,uint256 td,uint256 s,uint256 hp){
        sym  = m_symbol;
        addr = address(m_token);
        tvl  = balance();
        b    = balanceOf(user);
        d    = m_users_deposit[user];
        td   = m_total_deposits;
        s    = sharePrice();
        hp    = m_users_hprofit[user];
    }
    /**
     * @dev 获取每份基础资产对应的份额
     */
    function sharePrice() public view returns (uint256) {
        return totalSupply() > 0 ? balance().mul(1e18).div(totalSupply()) : 0;
    }
  
     function depositFor(uint256 amount,address user) nonReentrant public returns(uint256){
     //将amount数量的fea转入当前池子
        m_token.safeTransferFrom(msg.sender, address(this), amount);
        uint256 pool = balance();
         // 份额 = 0
        uint256 shares = 0;
        // 如果当前合约的总量为0,或者总的份额为0(防止合约上有余额)
        if (pool == 0 || totalSupply() == 0) {
            // 份额 = 数额
            shares = amount;
        } else {
            // 份额 = 数额 * 总量 / 池子数量
            shares = (amount.mul(totalSupply())).div(pool);
        }
        // 为调用者铸造份额
        _mint(user, shares); 
        //保存存款数据
        m_total_deposits = m_total_deposits.add(amount);
        m_users_deposit[user] = m_users_deposit[user].add(amount);
        return shares;
   }

    //这里不应该用nonReentrant
    function deposit(uint256 amount) /*nonReentrant*/ public returns(uint256){
        return depositFor(amount,msg.sender); 
   }

    function withdraw(uint256 shares) nonReentrant public returns(uint256){
         address user = msg.sender;
        // 当前合约和控制器合约在基础资产的余额 * 份额 / 总量
        uint256 amount = (balance().mul(shares)).div(totalSupply());
        // 销毁份额
        _burn(user, shares); 
        //打款给用户
        m_token.safeTransfer(user, amount);
        //记录更改前的deposit值
        uint256 oldDeposit = m_users_deposit[user];
         //当取出金额大于本金时，记录历史利润
        if(amount > oldDeposit){
            m_users_hprofit[user] =  m_users_hprofit[user].add(amount.sub(oldDeposit));
        }
        //更新存款数据(可能有，存款为0，但是利润不为0的情况)，这种情况不能revert       
        m_total_deposits = m_total_deposits > amount ? m_total_deposits.sub(amount) : 0;
        m_users_deposit[user] = oldDeposit > amount ? oldDeposit.sub(amount) : 0;
       
        return amount;
  }

  //动态利息算法：千分之三*当前借贷量/池子总量
  function minFee(uint256 amount) public view returns(uint256){
     uint256 pool = m_token.balanceOf(address(this));
     return  pool > 0 ? m_loan_fee.mul(amount).div(pool).div(MAX_LOAN_FEE) : 0;
  }

  function startFlashLoan(address dealer,uint256 amount,bytes calldata data) nonReentrant public{
    uint256 preBalance = m_token.balanceOf(address(this));
    //把借贷的资产转给贷款人
    m_token.safeTransfer(dealer,amount);
    //调用借贷者自己的借贷函数
    uint256 rAmount = amount.add(minFee(amount));
    IPureFlash(dealer).OnFlashLoan(address(m_token),amount,rAmount, data);
    //开始检查是否返款
    uint256 curBalance = m_token.balanceOf(address(this));
    uint256 profit = curBalance.sub(preBalance);
    //利润一定要大于当前最低利息
    require(profit>minFee(amount),"NEED_TRANSFER_BACK");
    //利润的10%发送给社区
    uint256 pfProfit = profit.mul(m_profit_rate).div(10000);
    m_token.safeTransfer(m_profitpool,pfProfit);

  }
}
