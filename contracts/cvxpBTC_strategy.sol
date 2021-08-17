pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "./interfaces/ICompoundingStrategy.sol";
import "./interfaces/IRewardStaking.sol";
import "./interfaces/IConvexDeposits.sol";
import "./interfaces/IKyberNetworkProxy.sol";
import "./interfaces/ICurveFi_DepositPBTC.sol";

contract cvxpBTCStrategy is ICompoundingStrategy, ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address payable public immutable platform;
    address public immutable poolToken;
    address public immutable poolDeposit;
    address public immutable poolGuage;
    uint256 public immutable pid;
    uint256 public totalDeposits;

    mapping(uint256 => address) public rewardTokens;
    

    constructor(string memory name_, string memory symbol_, address payable platform_, address poolToken_, address deposit_, address guage_, address[] memory rewardTokens_, uint256 pid_) ERC20(name_, symbol_) {
        platform = platform_;
        poolToken = poolToken_;
        poolDeposit = deposit_;
        poolGuage = guage_;
        pid = pid_;

        for(uint i=0; i<rewardTokens_.length; i++){
          rewardTokens[i] = rewardTokens_[i];
        }

        totalDeposits = 0;
    }

    fallback() external payable { require(platform.send(msg.value), "CompoundingStrategy: ether transfer failed."); }

    receive() external payable { require(platform.send(msg.value), "CompoundingStrategy: ether transfer failed."); }

    // Returns virtual price of strategy token.
    function virtualPrice() external view override returns (uint256) {
      uint256 outstandingTokens = IERC20(address(this)).totalSupply();
      if(outstandingTokens>0){
        return totalDeposits.div(outstandingTokens);
      } else {
        return 1;
      }
      
    }

    function _deposit(uint256 amount, bool mint) private {
      _poolToken.safeApprove(poolDeposit, 0);
      _poolToken.safeApprove(poolDeposit, amount);
      IConvexDeposits _deposit = IConvexDeposits(poolDeposit);
      require(_deposit.deposit(pid, amount, true), "CompoundingStrategy: convex deposit deposit failed");
      if(mint){
        uint256 userMint = amount.div(this.virtualPrice());
        super._mint(msg.sender, userMint);
      }
    }

    // Deposit into stategy with pool token.
    function deposit(uint256 amount) external override {
      IERC20 _poolToken = IERC20(poolToken);
      _poolToken.safeTransferFrom(msg.sender, address(this), amount);
      _deposit(amount, true);
      return;
    }

    // Deposit whole user pool token balance into strategy.
    function depositAll() external override {
      uint256 amount = IERC20(poolToken).balanceOf(msg.sender);
      IERC20 _poolToken = IERC20(poolToken);
      _poolToken.safeTransferFrom(msg.sender, address(this), amount);
      _deposit(amount, true);
      return;
    }

    // Withdraw into stategy with pool token.
    function withdraw(uint256 amount) external override {
      require(IERC20(address(this)).transferFrom(msg.sender, address(this), amount), "CompoundingStrategy: transfer of strategy token failed.");
      require(IERC20(address(this)).balanceOf(address(this)) >= amount, "CompoundingStrategy: transfer of strategy token failed.");
      super._burn(address(this), amount);
      return;
    }

    // Withdraw whole user pool token balance into strategy.
    function withdrawAll() external override {
      uint256 amount = IERC20(address(this)).balanceOf(msg.sender);
      require(IERC20(address(this)).transferFrom(msg.sender, address(this), amount), "CompoundingStrategy: transfer of strategy token failed.");
      require(IERC20(address(this)).balanceOf(address(this)) >= amount, "CompoundingStrategy: transfer of strategy token failed.");
      super._burn(address(this), amount);
      return;
    }

    // Harvest function sells all rewards tokens, reinvests into pool token, and stakes them in deposit.
    function harvest() external override {
      IRewardStaking guage = IRewardStaking(poolGuage);
      guage.getReward();
      uint256 profit = 0;
      for(uint i=0; rewardTokens[i] != address(0); i++) {
        IERC20 token = IERC20(rewardTokens[i]);
        IERC20 pbtc = IERC20(0x5228a22e72ccC52d415EcFd199F99D0665E7733b);
        IKyberNetworkProxy kyber = IKyberNetworkProxy(0x818E6FECD516Ecc3849DAf6845e3EC868087B755);
        uint256 amount = IERC20(token).balanceOf(address(this));
        (uint256 expectedRate, uint256 worstRate) = kyber.getExpectedRate(token, pbtc, amount);
        uint256 MAX_INT = 2**256 - 1;
        uint256 new_profit = kyber.trade(token, amount, pbtc, address(this), MAX_INT, worstRate, platform);
        require(new_profit >=0, "CompoundingStrategy: unable to complete trade with kyber");
        profit += new_profit;
      }

      // Deposit into Curve.fi to get LP 0x7F55DDe206dbAD629C080068923b36fe9D6bDBeF PBTC 
      ICurveFi_DepositPBTC curve = ICurveFi_DepositPBTC(0x7F55DDe206dbAD629C080068923b36fe9D6bDBeF);
      uint256 crvLP = curve.add_liquidity([profit, 0], 0);
      _deposit(crvLP, false);
      return;
    }

}