// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./interfaces/IYieldFarm.sol";

// Locking Proxy Contract
contract LiquidityLocker is Ownable {
  using SafeERC20 for IERC20;

  struct PoolInfo {
    IERC20 lpToken;
    uint256 totalAmount;
  }

  struct UserInfo {
    uint256 amount;
    uint256 rewardPaid;
  }

  IERC20 public immutable rewardToken;
  IYieldFarm public immutable lockedFarm;
  uint256 public immutable unlockTimestamp;

  uint256 public totalReward;

  PoolInfo[] public pools;
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;

  constructor(uint256 unlock, IERC20 token, IYieldFarm farm) {
    rewardToken = token;
    lockedFarm = farm;
    unlockTimestamp = unlock;
  }

  /// @dev Add a new liquidity pool
  function add(IERC20 _lpToken) external onlyOwner {
    pools.push(PoolInfo({lpToken: _lpToken, totalAmount: 0}));
  }

  /// @dev Approve LP tokens for MasterGamer to use
  function approveLp(uint256 _pid) external onlyOwner {
    require(_pid < pools.length, "Pool does not exist.");
    IERC20 poolToken = pools[_pid].lpToken;
    poolToken.approve(address(lockedFarm), type(uint256).max);
  }

  /// @dev Deposit LP tokens to MasterGamer then lock them.
  function deposit(uint256 _pid, uint256 _amount) external {
    require(_pid < pools.length, "Pool does not exist.");
    UserInfo storage user = userInfo[_pid][msg.sender];
    PoolInfo storage pool = pools[_pid];

    // Get pool rewards
    getRewards(_pid);

    // Update user&pool LP amounts
    pool.totalAmount += _amount;
    user.amount += _amount;

    // First transfer tokens to LiquidityLocker
    pool.lpToken.transferFrom(msg.sender, address(this), _amount);
    // Then deposit tokens to MasterGamer
    lockedFarm.deposit(_pid, _amount);
  }

  /// @dev Withdraw LP tokens from MasterGamer if unlocked.
  function withdraw(uint256 _pid, uint256 _amount) external {
    require(block.timestamp > unlockTimestamp);
    require(_pid < pools.length, "Pool does not exist.");
    UserInfo storage user = userInfo[_pid][msg.sender];
    PoolInfo storage pool = pools[_pid];

    require(_amount <= user.amount, "Not enough balance!");

    // Get pool rewards
    getRewards(_pid);

    // Update user&pool LP amounts
    pool.totalAmount -= _amount;
    user.amount -= _amount;

    // First withdraw tokens from MasterGamer
    lockedFarm.withdraw(_pid, _amount);
    // Then transfer tokens to User
    pool.lpToken.safeTransfer(msg.sender, _amount);
  }

  /// @dev Get Hon Rewards
  function getRewards(uint256 _pid) public {
    UserInfo storage user = userInfo[_pid][msg.sender];
    PoolInfo storage pool = pools[_pid];
    if(pool.totalAmount > 0)
    {
      uint256 pending = lockedFarm.pendingHon(_pid, address(this));
      totalReward += pending;

      // Zero deposit to get reward
      lockedFarm.deposit(_pid, 0);
      uint256 userReward = ((user.amount * totalReward) / pool.totalAmount ) - user.rewardPaid;
      user.rewardPaid += userReward;
      require(rewardToken.balanceOf(address(this)) >= userReward, "Reward is not received yet, try again.");

      // Send the reward
      rewardToken.safeTransfer(msg.sender, userReward);
    }
  }
}
