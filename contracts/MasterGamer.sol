// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./HonToken.sol";

interface IMigratorChef {
    // Perform LP token migration from legacy UniswapV2 to SushiSwap.
    // Take the current LP token address and return the new LP token address.
    // Migrator should have full access to the caller's LP token.
    // Return the new LP token address.
    //
    // XXX Migrator must have allowance access to UniswapV2 LP tokens.
    // SushiSwap must mint EXACTLY the same amount of SushiSwap LP tokens or
    // else something bad will happen. Traditional UniswapV2 does not
    // do that so be careful!
    function migrate(IERC20 token) external returns (IERC20);
}


// MasterGamer is an Alpha Nerd. He can make Hon and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once Hon is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterGamer is Ownable {
  using SafeERC20 for IERC20;
  using SafeMath for uint256;
  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many LP tokens the user has provided.
    uint256 rewardDebt; // Reward debt. See explanation below.
    /**
      We do some fancy math here. Basically, any point in time, the amount of HONs
      entitled to a user but is pending to be distributed is:

      pending reward = (user.amount * pool.accHonPerShare) - user.rewardDebt

      Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
      1. The pool's `accHonPerShare` (and `lastRewardTimestamp`) gets updated.
      2. User receives the pending reward sent to his/her address.
      3. User's `amount` gets updated.
      4. User's `rewardDebt` gets updated.
     */
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 lpToken;               // Address of LP token contract.
    uint256 allocPoint;           // How many allocation points assigned to this pool. HONs to distribute per period.
    uint256 lastRewardTimestamp;  // Last timestamp that HONs distribution occurs.
    uint256 accHonPerShare;       // Accumulated HONs per share, times 1e12. See below.
    uint256 depositFeePerMillion; // Deposit fee in per million
  }

  // HON Token
  HonToken public immutable hon;
  // Dev address.
  address public devaddr;
  // Treasury address.
  address public treasuryaddr;
  // Fee address
  address public feeaddr;

  // Timestamp when bonus HON ends
  uint256 public bonusEndTimestamp;
  // HON tokens created per period
  uint256 public honPerPeriod;
  // Bonus multiplier for early HON makers.
  uint256 public constant BONUS_MULTIPLIER = 1;
  // Dev share is 15%
  uint256 public constant DEV_SHARE = 20;
  // Treasury share is 20%
  uint256 public constant TREASURY_SHARE = 15;
  // ONE YEAR
  uint256 public constant ONE_YEAR = 365 days;
  // Annual Reward Reduction 20%
  uint256 public constant REWARD_REDUCTION = 20;
  // Keep track of last reduction year
  uint256 public LAST_REDUCTION_YEAR;
  
  // The migrator contract. It has a lot of power. Can only be set through governance (owner).
  IMigratorChef public migrator;
  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Pool exists information
  mapping (address=>bool) public poolExists;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation poitns. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;
  // The starting timestamp when HON mining starts.
  uint256 public startTimestamp;
  // How often reward HON is distributed in minutes.
  uint256 public immutable rewardPeriodMinutes;

  /**
   * Events
   */
  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(
    address indexed user,
    uint256 indexed pid,
    uint256 amount
  );
  event RewardReduced(uint256 _honPerPeriod);

  constructor(
    HonToken _hon,
    address _devaddr,
    address _treasuryaddr,
    address _feeaddr,
    uint256 _honPerPeriod,
    uint256 _startPeriodMinutes,
    uint256 _rewardPeriodMinutes,
    uint256 _bonusPeriodMinutes
  ) {
    hon = _hon;
    devaddr = _devaddr;
    treasuryaddr = _treasuryaddr;
    feeaddr = _feeaddr;
    honPerPeriod = _honPerPeriod;
    startTimestamp = block.timestamp + (_startPeriodMinutes * 1 minutes);
    bonusEndTimestamp = startTimestamp + (_bonusPeriodMinutes * 1 minutes);
    rewardPeriodMinutes = _rewardPeriodMinutes;
    LAST_REDUCTION_YEAR = startTimestamp;
  }

  // Count of pools
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }
   
  /**
    * @dev If current timestamp is newer then assign the pool's reward timestamp
    * next time point. We have the same time points for every pool 
    * Sequential time points are seperated with rewardPeriodMinutes
    */
  function add(
    uint256 _allocPoint,
    IERC20 _lpToken,
    uint256 _depositFeePerMillion,
    bool _withUpdate
  ) external onlyOwner {
    require(poolExists[address(_lpToken)] == false, "LP token has already been added");
    require(_depositFeePerMillion < 1e6, "The deposit fee should be between 0 and 999,999");
    if (_withUpdate) {
      massUpdatePools();
    }

    uint256 lastRewardTimestamp = startTimestamp;
    uint256 currentTimestamp = block.timestamp;
    if (currentTimestamp > startTimestamp) {
      uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;
      uint256 periodCount = currentTimestamp.sub(startTimestamp).div(rewardPeriodTime);
      lastRewardTimestamp = periodCount.add(1).mul(rewardPeriodTime).add(startTimestamp);
    }

    totalAllocPoint = totalAllocPoint.add(_allocPoint);
    poolInfo.push(
      PoolInfo({
        lpToken: _lpToken,
        allocPoint: _allocPoint,
        lastRewardTimestamp: lastRewardTimestamp,
        accHonPerShare: 0,
        depositFeePerMillion: _depositFeePerMillion
      })
    );
    poolExists[address(_lpToken)] = true;
  }
  
  // Update the given pool's HON allocation point plus depositfee. Can only be called by the owner.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    uint256 _depositFeePerMillion,
    bool _withUpdate
  ) external onlyOwner {
    require(_depositFeePerMillion < 1e6, "The deposit fee should be between 0 and 999,999");
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
      _allocPoint
    );
    poolInfo[_pid].allocPoint = _allocPoint;
    poolInfo[_pid].depositFeePerMillion = _depositFeePerMillion;
  }

  // Set the migrator contract. Can only be called by the owner.
  function setMigrator(IMigratorChef _migrator) external onlyOwner {
    migrator = _migrator;
  }

  // Migrate lp token to another lp contract. Can be called by anyone. We trust that migrator contract is good.
  function migrate(uint256 _pid) public {
    require(address(migrator) != address(0), "migrate: no migrator");
    PoolInfo storage pool = poolInfo[_pid];
    IERC20 lpToken = pool.lpToken;
    uint256 bal = lpToken.balanceOf(address(this));
    lpToken.safeApprove(address(migrator), bal);
    IERC20 newLpToken = migrator.migrate(lpToken);
    require(bal == newLpToken.balanceOf(address(this)), "migrate: bad");
    pool.lpToken = newLpToken;
  }

  // Return reward multiplier over the given _from to _to timestamp.
  function getMultiplier(uint256 _from, uint256 _to)
    public
    view
    returns (uint256)
  {
    // Convert minutes to timestamp for further usage
    uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;

    if (_to <= bonusEndTimestamp) {
      return _to.sub(_from).div(rewardPeriodTime).mul(BONUS_MULTIPLIER);
    } else if (_from >= bonusEndTimestamp) {
      return _to.sub(_from).div(rewardPeriodTime);
    } else {
      return
        bonusEndTimestamp.sub(_from).div(rewardPeriodTime).mul(BONUS_MULTIPLIER).add(
          _to.sub(bonusEndTimestamp).div(rewardPeriodTime)
        );
    }
  }

  // View function to see pending HONs of the user on frontend.
  function pendingHon(uint256 _pid, address _user)
    external
    view
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accHonPerShare = pool.accHonPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));

    if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
      uint256 multiplier = 
        getMultiplier(pool.lastRewardTimestamp, block.timestamp);
      uint256 honReward = 
        multiplier.mul(honPerPeriod).mul(pool.allocPoint).div(
          totalAllocPoint
        );
      accHonPerShare = accHonPerShare.add(
        honReward.mul(1e12).div(lpSupply)
      );
    }
    return user.amount.mul(accHonPerShare).div(1e12).sub(user.rewardDebt);
  }

  // Update reward vairables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  // If one year is elapsed simply reduce the rewards
  function reduceRewards() internal {
    uint256 elapsed_time = block.timestamp - LAST_REDUCTION_YEAR;
    if (elapsed_time > ONE_YEAR)
    {
      honPerPeriod = honPerPeriod - honPerPeriod.mul(REWARD_REDUCTION).div(100);
      LAST_REDUCTION_YEAR += ONE_YEAR;
      emit RewardReduced(honPerPeriod);
    }
  }

  // Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    // If the next reward period has not been elapsed do nothing
    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }

    // Reduce the rewards
    reduceRewards();

    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    uint256 tmpLastRewardTimestamp = pool.lastRewardTimestamp;
    uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;
    uint256 periodCount = block.timestamp.sub(tmpLastRewardTimestamp).div(rewardPeriodTime);
    
    // Shift the reward time the next timestamp
    tmpLastRewardTimestamp = periodCount.add(1).mul(rewardPeriodTime).add(tmpLastRewardTimestamp);
    
    if (lpSupply == 0) {
      pool.lastRewardTimestamp = tmpLastRewardTimestamp;
      return;
    }

    uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
    uint256 honReward = 
      multiplier.mul(honPerPeriod).mul(pool.allocPoint).div(
        totalAllocPoint
      );
    
    // Transfer dev & treasury share
    safeHonTransfer(devaddr, honReward.mul(DEV_SHARE).div(100));
    safeHonTransfer(treasuryaddr, honReward.mul(TREASURY_SHARE).div(100));
    pool.accHonPerShare = pool.accHonPerShare.add(
      honReward.mul(1e12).div(lpSupply)
    );
    pool.lastRewardTimestamp = tmpLastRewardTimestamp;
  }

  // Deposit LP tokens to MasterGamer for HON allocation.
  function deposit(uint256 _pid, uint256 _amount) external {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = 
        user.amount.mul(pool.accHonPerShare).div(1e12).sub(
          user.rewardDebt
        );
      safeHonTransfer(msg.sender, pending);
    }
    if (_amount > 0) {
      pool.lpToken.safeTransferFrom(
        address(msg.sender),
        address(this),
        _amount
      );
      if (pool.depositFeePerMillion > 0) {
        uint256 depositFee = _amount.mul(pool.depositFeePerMillion).div(1e6);
        pool.lpToken.safeTransfer(feeaddr, depositFee);
        user.amount = user.amount.add(_amount).sub(depositFee);
      } else {
        user.amount = user.amount.add(_amount);
      }
    }
    user.rewardDebt = user.amount.mul(pool.accHonPerShare).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  // Withdraw LP tokens from MasterGamer.
  function withdraw(uint256 _pid, uint256 _amount) external {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: failed!");
    updatePool(_pid);
    uint256 pending = 
      user.amount.mul(pool.accHonPerShare).div(1e12).sub(
        user.rewardDebt
      );
    safeHonTransfer(msg.sender, pending);
    user.amount = user.amount.sub(_amount);
    user.rewardDebt = user.amount.mul(pool.accHonPerShare).div(1e12);
    pool.lpToken.safeTransfer(address(msg.sender), _amount);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  // Safe HON transfer function, just in case if rounding error causes pool to not have enough HONs.
  function safeHonTransfer(address _to, uint256 _amount) internal {
    uint256 honBal = hon.balanceOf(address(this));
    if (_amount > honBal) {
      hon.transfer(_to, honBal);
    } else {
      hon.transfer(_to, _amount);
    }
  }

  // Update dev address by the previous dev.
  function dev(address _devaddr) external {
    require(_devaddr != address(0), "dev address must not be address(0)");
    require(msg.sender == devaddr, "dev: you shall not pass !");
    devaddr = _devaddr;
  }

  // Update treasury address by the dev.
  function treasury(address _treasuryaddr) external {
    require(_treasuryaddr != address(0), "treasury address must not be address(0)");
    require(msg.sender == devaddr, "dev: you shall not pass !");
    treasuryaddr = _treasuryaddr;
  }

  // Update fee address by the dev.
  function fee(address _feeaddr) external {
    require(_feeaddr != address(0), "fee address must not be address(0)");
    require(msg.sender == devaddr, "dev: you shall not pass !");
    feeaddr = _feeaddr;
  }
}
