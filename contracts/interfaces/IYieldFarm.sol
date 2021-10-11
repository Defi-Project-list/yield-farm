// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

/// @dev Interface to interact with yield farms
interface IYieldFarm {
  /// @dev Update the given pool's HON allocation point plus deposit fee.
  function set(
    uint256 _pid,
    uint256 _allocPoint,
    uint256 _depositFeePerMillion,
    bool _withUpdate
  ) external;

  /// @dev Return reward multiplier over the given _from to _to timestamp.
  function getMultiplier(uint256 _from, uint256 _to) external view returns (uint256);

  /// @dev View function to see pending HONs of the user on frontend.
  function pendingHon(uint256 _pid, address _user) external view returns (uint256);

  /// @dev Update reward variables for all pools. Be careful of gas spending!
  function massUpdatePools() external;

  /// @dev Update reward variables of the given pool to be up-to-date.
  function updatePool(uint256 _pid) external;

  /// @dev Deposit LP tokens to MasterGamer for HON allocation.
  function deposit(uint256 _pid, uint256 _amount) external;

  /// @dev Withdraw LP tokens from MasterGamer.
  function withdraw(uint256 _pid, uint256 _amount) external;

  /// @dev Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) external;
}
