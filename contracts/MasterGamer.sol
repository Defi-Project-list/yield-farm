// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./HonToken.sol";

// MasterGamer is an Alpha Nerd. He can distribute Hon and he is a fair guy.
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
    IERC20 lpToken; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. HONs to distribute per period.
    uint256 lastRewardTimestamp; // Last timestamp that HONs distribution occurs.
    uint256 accHonPerShare; // Accumulated HONs per share, times 1e12. See below.
    uint256 depositFeePerMillion; // Deposit fee in per million
  }
  // HON Token
  HonToken public immutable hon;
  // Dev address.
  address public devaddr;
  // Fee address
  address public feeaddr;

  // ONE YEAR
  uint256 public constant ONE_YEAR = 365 days;
  // Annual Reward Increase 25%
  uint256 public constant REWARD_INCREASE = 25;
  // Keep track of last increase year
  uint256 public LAST_INCREASE_YEAR;
  // HON tokens created per period, increased annually
  uint256 public honPerPeriod;

  // Info of each pool.
  PoolInfo[] public poolInfo;
  // Pool exists information
  mapping(address => bool) public poolExists;
  // Info of each user that stakes LP tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint;
  // The starting timestamp when HON mining starts.
  uint256 public startTimestamp;
  // How often reward HON is distributed in minutes.
  uint256 public immutable rewardPeriodMinutes;

  /// @dev Events
  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event RewardsIncreased(uint256 _honPerPeriod);
  event DevChanged(address _devaddr);
  event FeeChanged(address _feeaddr);

  constructor(
    HonToken _hon,
    address _devaddr,
    address _feeaddr,
    uint256 _honPerPeriod,
    uint256 _startPeriodMinutes,
    uint256 _rewardPeriodMinutes
  ) {
    hon = _hon;
    devaddr = _devaddr;
    feeaddr = _feeaddr;
    honPerPeriod = _honPerPeriod;
    startTimestamp = block.timestamp + (_startPeriodMinutes * 1 minutes);
    rewardPeriodMinutes = _rewardPeriodMinutes;
    LAST_INCREASE_YEAR = startTimestamp;
  }

  /// @dev Check if poolId exists
  modifier validatePoolByPid(uint256 _pid) {
    require(_pid < poolInfo.length, "Pool does not exist.");
    _;
  }

  /// @dev TODO: only dev access
  modifier onlyDev() {
    require(msg.sender == devaddr, "dev: you shall not pass !");
    _;
  }

  /// @dev Count of pools
  function poolLength() external view returns (uint256) {
    return poolInfo.length;
  }

  /**
   * @dev If current timestamp is newer than startTimestamp
   * then assign the pool's reward timestamp next time point.
   * We have the same time points for every pool.
   * Sequential time points are seperated with rewardPeriodMinutes
   * tp0----<rPM>----tp1----<rPM>----tp2------tp(N-1)----<rPM>----tpN
   */
  function add(
    uint256 _allocPoint,
    IERC20 _lpToken,
    uint256 _depositFeePerMillion,
    bool _withUpdate
  ) external onlyOwner {
    require(!poolExists[address(_lpToken)], "LP token has already been added");
    require(_depositFeePerMillion < 1e6, "The deposit fee should be between 0 and 999,999");
    if (_withUpdate) {
      massUpdatePools();
    }

    uint256 lastRewardTimestamp = startTimestamp;
    uint256 currentTimestamp = block.timestamp;
    if (currentTimestamp > startTimestamp) {
      uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;
      uint256 periodCount = (currentTimestamp.sub(startTimestamp)).div(rewardPeriodTime);
      lastRewardTimestamp = ((periodCount.add(1)).mul(rewardPeriodTime)).add(startTimestamp);
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

  /// @dev Update the given pool's HON allocation point plus deposit fee.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    uint256 _depositFeePerMillion,
    bool _withUpdate
  ) external onlyOwner validatePoolByPid(_pid) {
    require(_depositFeePerMillion < 1e6, "The deposit fee should be between 0 and 999,999");
    if (_withUpdate) {
      massUpdatePools();
    }
    totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(_allocPoint);
    poolInfo[_pid].allocPoint = _allocPoint;
    poolInfo[_pid].depositFeePerMillion = _depositFeePerMillion;
  }

  /// @dev Return reward multiplier over the given _from to _to timestamp.
  function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
    uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;
    return (_to.sub(_from)).div(rewardPeriodTime);
  }

  /// @dev View function to see pending HONs of the user on frontend.
  function pendingHon(uint256 _pid, address _user)
    external
    view
    validatePoolByPid(_pid)
    returns (uint256)
  {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accHonPerShare = pool.accHonPerShare;
    uint256 lpSupply = pool.lpToken.balanceOf(address(this));

    if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
      uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
      uint256 honReward = (multiplier.mul(honPerPeriod).mul(pool.allocPoint)).div(totalAllocPoint);
      accHonPerShare = accHonPerShare.add((honReward.mul(1e12)).div(lpSupply));
    }
    return ((user.amount.mul(accHonPerShare)).div(1e12)).sub(user.rewardDebt);
  }

  /// @dev Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() public {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      updatePool(pid);
    }
  }

  /// @dev If one year is elapsed simply increase the rewards.
  function increaseRewards() internal {
    uint256 elapsed_time = block.timestamp - LAST_INCREASE_YEAR;
    if (elapsed_time > ONE_YEAR) {
      honPerPeriod = honPerPeriod + (honPerPeriod.mul(REWARD_INCREASE)).div(100);
      LAST_INCREASE_YEAR += ONE_YEAR;
      emit RewardsIncreased(honPerPeriod);
    }
  }

  /// @dev Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) public validatePoolByPid(_pid) {
    PoolInfo storage pool = poolInfo[_pid];
    // If the next reward period has not been elapsed do nothing
    if (block.timestamp <= pool.lastRewardTimestamp) {
      return;
    }

    // Reduce the rewards
    increaseRewards();

    uint256 lpSupply = pool.lpToken.balanceOf(address(this));
    uint256 tmpLastRewardTimestamp = pool.lastRewardTimestamp;
    uint256 rewardPeriodTime = rewardPeriodMinutes * 1 minutes;
    uint256 periodCount = (block.timestamp.sub(tmpLastRewardTimestamp)).div(rewardPeriodTime);

    // Shift the reward time to the next timestamp
    tmpLastRewardTimestamp = periodCount.add(1).mul(rewardPeriodTime).add(tmpLastRewardTimestamp);

    if (lpSupply == 0) {
      pool.lastRewardTimestamp = tmpLastRewardTimestamp;
      return;
    }

    uint256 multiplier = getMultiplier(pool.lastRewardTimestamp, block.timestamp);
    uint256 honReward = (multiplier.mul(honPerPeriod).mul(pool.allocPoint)).div(totalAllocPoint);

    // Transfer dev & treasury share
    pool.accHonPerShare = pool.accHonPerShare.add((honReward.mul(1e12)).div(lpSupply));
    pool.lastRewardTimestamp = tmpLastRewardTimestamp;
  }

  /// @dev Deposit LP tokens to MasterGamer for HON allocation.
  function deposit(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    updatePool(_pid);
    if (user.amount > 0) {
      uint256 pending = ((user.amount.mul(pool.accHonPerShare)).div(1e12)).sub(user.rewardDebt);
      safeHonTransfer(msg.sender, pending);
    }
    if (_amount > 0) {
      // First get deposited tokens
      pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
      // Cut the pool fee from deposited then send to the feeaddr
      if (pool.depositFeePerMillion > 0) {
        uint256 depositFee = (_amount.mul(pool.depositFeePerMillion)).div(1e6);
        require(_amount > depositFee, "Insufficent deposit amount.");
        pool.lpToken.safeTransfer(feeaddr, depositFee);
        user.amount = (user.amount.add(_amount)).sub(depositFee);
      } else {
        user.amount = user.amount.add(_amount);
      }
    }
    user.rewardDebt = (user.amount.mul(pool.accHonPerShare)).div(1e12);
    emit Deposit(msg.sender, _pid, _amount);
  }

  /// @dev Withdraw LP tokens from MasterGamer.
  function withdraw(uint256 _pid, uint256 _amount) external validatePoolByPid(_pid) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    require(user.amount >= _amount, "withdraw: failed!");
    updatePool(_pid);
    uint256 pending = ((user.amount.mul(pool.accHonPerShare)).div(1e12)).sub(user.rewardDebt);
    safeHonTransfer(msg.sender, pending);
    user.amount = user.amount.sub(_amount);
    user.rewardDebt = (user.amount.mul(pool.accHonPerShare)).div(1e12);
    pool.lpToken.safeTransfer(address(msg.sender), _amount);
    emit Withdraw(msg.sender, _pid, _amount);
  }

  /// @dev Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external validatePoolByPid(_pid) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    pool.lpToken.safeTransfer(address(msg.sender), user.amount);
    emit EmergencyWithdraw(msg.sender, _pid, user.amount);
    user.amount = 0;
    user.rewardDebt = 0;
  }

  /// @dev Safe HON transfer function, just in case if rounding error causes pool to not have enough HONs.
  function safeHonTransfer(address _to, uint256 _amount) internal {
    uint256 honBal = hon.balanceOf(address(this));
    if (_amount > honBal) {
      hon.transfer(_to, honBal);
    } else {
      hon.transfer(_to, _amount);
    }
  }

  /// @dev Update dev address by the previous dev.
  function dev(address _devaddr) external onlyDev {
    require(_devaddr != address(0), "dev address must not be address(0)");
    devaddr = _devaddr;
    emit DevChanged(_devaddr);
  }

  /// @dev Update fee address by the dev.
  function fee(address _feeaddr) external onlyDev {
    require(_feeaddr != address(0), "fee address must not be address(0)");
    feeaddr = _feeaddr;
    emit FeeChanged(_feeaddr);
  }
}
