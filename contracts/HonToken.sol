// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.3;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./libraries/NativeAssets.sol";

// HonToken with Governance.
contract HonToken is Ownable, ERC20 {
  // Avalanche X-chain address
  uint256 private immutable _assetID;

  // Fixed cap token
  uint256 public immutable maxSupply;
  address payable public stuckAccount;

  /// @dev Hon Token
  constructor(uint256 _maxSupply, uint256 assetID_, address _stuckAccount) ERC20("HonToken", "HON") {
    maxSupply = _maxSupply;
    _assetID = assetID_;
    stuckAccount = payable(_stuckAccount);
  }

  /// @dev ARC20 compatibility events
  event Deposit(address indexed dst, uint256 value);
  event Withdrawal(address indexed src, uint256 value);

  /// @dev ARC20 - Deposit function
  function deposit() external {
    uint256 updatedBalance = NativeAssets.assetBalance(address(this), _assetID);
    // Multiply with 1 gwei to increase decimals from 9(avm) to 18(evm)
    uint256 depositAmount = (updatedBalance * 1 gwei) - totalSupply();
    require(depositAmount > 0, "Deposit amount should be more than zero");
    require(depositAmount + totalSupply() <= maxSupply, "Maximum supply is reached.");

    _mint(msg.sender, depositAmount);
    emit Deposit(msg.sender, depositAmount);
  }

  /// @dev ARC20 - Withdraw function
  function withdraw(uint256 amount) external {
    // Divide by 1 gwei to decrease decimals from 18(evm) to 9(avm)
    // Division always floors
    uint256 native_amount = amount / 1 gwei;
    require(native_amount > 0, "amount must be greater than 1 gwei");
    require(balanceOf(msg.sender) >= native_amount, "insufficent funds");
    _burn(msg.sender, native_amount);
    NativeAssets.assetCall(msg.sender, _assetID, native_amount, "");
    emit Withdrawal(msg.sender, native_amount);
  }

  /// @dev Returns the `assetID` of the underlying asset this contract handles.
  function assetID() external view returns (uint256) {
    return _assetID;
  }

  /// @dev Mint grants delegation power
  function _mint(address account, uint256 amount) internal override {
    super._mint(account, amount);
    _moveDelegates(address(0), _delegates[account], amount);
  }

  /// @dev Burn revokes delegation power
  function _burn(address account, uint256 amount) internal override {
    super._burn(account, amount);
    _moveDelegates(_delegates[account], address(0), amount);
  }

  /// @dev Transfer moves the delegation power
  function transfer(address recipient, uint256 amount) public override returns (bool) {
    super.transfer(recipient, amount);
    _moveDelegates(_delegates[msg.sender], _delegates[recipient], amount);
    return true;
  }

  /// @dev Transfer moves the delegation power
  function transferFrom(
    address sender,
    address recipient,
    uint256 amount
  ) public override returns (bool) {
    super.transferFrom(sender, recipient, amount);
    _moveDelegates(_delegates[sender], _delegates[recipient], amount);
    return true;
  }

  /// @dev Get signer address from tx hash
  function recover(
    bytes32 hash,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) internal pure returns (address) {
    // EIP-2 still allows signature malleability for ecrecover(). Remove this possibility and make the signature
    // unique. Appendix F in the Ethereum Yellow paper (https://ethereum.github.io/yellowpaper/paper.pdf), defines
    // the valid range for s in (281): 0 < s < secp256k1n ÷ 2 + 1, and for v in (282): v ∈ {27, 28}. Most
    // signatures from current libraries generate a unique signature with an s-value in the lower half order.
    //
    // If your library generates malleable signatures, such as s-values in the upper range, calculate a new s-value
    // with 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141 - s1 and flip v from 27 to 28 or
    // vice versa. If your library also generates signatures with 0/1 for v instead 27/28, add 27 to v to accept
    // these malleable signatures as well.
    require(
      uint256(s) <= 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0,
      "ECDSA: invalid signature 's' value"
    );
    require(v == 27 || v == 28, "ECDSA: invalid signature 'v' value");

    // If the signature is valid (and not malleable), return the signer address
    address signer = ecrecover(hash, v, r, s);
    require(signer != address(0), "ECDSA: invalid signature");

    return signer;
  }

  // Copied and modified from YAM code:
  // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernanceStorage.sol
  // https://github.com/yam-finance/yam-protocol/blob/master/contracts/token/YAMGovernance.sol
  // Which is copied and modified from COMPOUND:
  // https://github.com/compound-finance/compound-protocol/blob/master/contracts/Governance/Comp.sol

  /// @dev A record of each accounts delegate
  mapping(address => address) internal _delegates;

  /// @dev A checkpoint for marking number of votes from a given block
  struct Checkpoint {
    uint32 fromBlock;
    uint256 votes;
  }

  /// @dev A record of votes checkpoints for each account, by index
  mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

  /// @dev The number of checkpoints for each account
  mapping(address => uint32) public numCheckpoints;

  /// @dev The EIP-712 typehash for the contract's domain
  bytes32 public constant DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,uint256 chainId,address verifyingContract)");

  /// @dev The EIP-712 typehash for the delegation struct used by the contract
  bytes32 public constant DELEGATION_TYPEHASH =
    keccak256("Delegation(address delegatee,uint256 nonce,uint256 expiry)");

  /// @dev A record of states for signing / validating signatures
  mapping(address => uint256) public nonces;

  /// @dev An event thats emitted when an account changes its delegate
  event DelegateChanged(
    address indexed delegator,
    address indexed fromDelegate,
    address indexed toDelegate
  );

  /// @dev An event thats emitted when a delegate account's vote balance changes
  event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

  /**
   * @dev Delegate votes from `msg.sender` to `delegatee`
   * @param delegator The address to get delegatee for
   */
  function delegates(address delegator) external view returns (address) {
    return _delegates[delegator];
  }

  /**
   * @dev Delegate votes from `msg.sender` to `delegatee`
   * @param delegatee The address to delegate votes to
   */
  function delegate(address delegatee) external {
    return _delegate(msg.sender, delegatee);
  }

  /**
   * @dev Delegates votes from signatory to `delegatee`
   * @param delegatee The address to delegate votes to
   * @param nonce The contract state required to match the signature
   * @param expiry The time at which to expire the signature
   * @param v The recovery byte of the signature
   * @param r Half of the ECDSA signature pair
   * @param s Half of the ECDSA signature pair
   */
  function delegateBySig(
    address delegatee,
    uint256 nonce,
    uint256 expiry,
    uint8 v,
    bytes32 r,
    bytes32 s
  ) external {
    bytes32 domainSeparator = keccak256(
      abi.encode(DOMAIN_TYPEHASH, keccak256(bytes(name())), getChainId(), address(this))
    );

    bytes32 structHash = keccak256(abi.encode(DELEGATION_TYPEHASH, delegatee, nonce, expiry));

    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));

    address signatory = recover(digest, v, r, s); // TODO: Implement ECDSA recover() function instead of this
    require(signatory != address(0), "HON::delegateBySig: invalid signature");
    require(nonce == nonces[signatory]++, "HON::delegateBySig: invalid nonce");
    require(block.timestamp <= expiry, "HON::delegateBySig: signature expired");
    return _delegate(signatory, delegatee);
  }

  /**
   * @dev Gets the current votes balance for `account`
   * @param account The address to get votes balance
   * @return The number of current votes for `account`
   */
  function getCurrentVotes(address account) external view returns (uint256) {
    uint32 nCheckpoints = numCheckpoints[account];
    return nCheckpoints > 0 ? checkpoints[account][nCheckpoints - 1].votes : 0;
  }

  /**
   * @dev Determine the prior number of votes for an account as of a block number
   * @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
   * @param account The address of the account to check
   * @param blockNumber The block number to get the vote balance at
   * @return The number of votes the account had as of the given block
   */
  function getPriorVotes(address account, uint256 blockNumber) external view returns (uint256) {
    require(blockNumber < block.number, "HON::getPriorVotes: not yet determined");

    uint32 nCheckpoints = numCheckpoints[account];
    if (nCheckpoints == 0) {
      return 0;
    }

    // First check most recent balance
    if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
      return checkpoints[account][nCheckpoints - 1].votes;
    }

    // Next check implicit zero balance
    if (checkpoints[account][0].fromBlock > blockNumber) {
      return 0;
    }

    uint32 lower = 0;
    uint32 upper = nCheckpoints - 1;
    while (upper > lower) {
      uint32 center = upper - (upper - lower) / 2; // ceil, avoiding overflow
      Checkpoint memory cp = checkpoints[account][center];
      if (cp.fromBlock == blockNumber) {
        return cp.votes;
      } else if (cp.fromBlock < blockNumber) {
        lower = center;
      } else {
        upper = center - 1;
      }
    }
    return checkpoints[account][lower].votes;
  }

  function _delegate(address delegator, address delegatee) internal {
    address currentDelegate = _delegates[delegator];
    uint256 delegatorBalance = balanceOf(delegator); // balance of underlying HONs (not scaled);
    _delegates[delegator] = delegatee;

    emit DelegateChanged(delegator, currentDelegate, delegatee);

    _moveDelegates(currentDelegate, delegatee, delegatorBalance);
  }

  function _moveDelegates(
    address srcRep,
    address dstRep,
    uint256 amount
  ) internal {
    if (srcRep != dstRep && amount > 0) {
      if (srcRep != address(0)) {
        // decrease old representative
        uint32 srcRepNum = numCheckpoints[srcRep];
        uint256 srcRepOld = srcRepNum > 0 ? checkpoints[srcRep][srcRepNum - 1].votes : 0;
        uint256 srcRepNew = srcRepOld - amount;
        _writeCheckpoint(srcRep, srcRepNum, srcRepOld, srcRepNew);
      }

      if (dstRep != address(0)) {
        // increase new representative
        uint32 dstRepNum = numCheckpoints[dstRep];
        uint256 dstRepOld = dstRepNum > 0 ? checkpoints[dstRep][dstRepNum - 1].votes : 0;
        uint256 dstRepNew = dstRepOld + amount;
        _writeCheckpoint(dstRep, dstRepNum, dstRepOld, dstRepNew);
      }
    }
  }

  function _writeCheckpoint(
    address delegatee,
    uint32 nCheckpoints,
    uint256 oldVotes,
    uint256 newVotes
  ) internal {
    uint32 blockNumber = safe32(
      block.number,
      "HON::_writeCheckpoint: block number exceeds 32 bits"
    );

    if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == blockNumber) {
      checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
    } else {
      checkpoints[delegatee][nCheckpoints] = Checkpoint(blockNumber, newVotes);
      numCheckpoints[delegatee] = nCheckpoints + 1;
    }

    emit DelegateVotesChanged(delegatee, oldVotes, newVotes);
  }

  function safe32(uint256 n, string memory errorMessage) internal pure returns (uint32) {
    require(n < 2**32, errorMessage);
    return uint32(n);
  }

  function getChainId() internal view returns (uint256) {
    uint256 chainId;
    assembly {
      chainId := chainid()
    }
    return chainId;
  }

  // Withdraw stucked Avax if any
  function withdrawStuck() public {
    uint256 balance = address(this).balance;
    stuckAccount.transfer(balance);
  }

  // ARC-20 must have a fallback function to avoid reverting when
  // an Avalanche Native Token is transferred to it via CALLEX.
  // Fallback function
  fallback() external payable {}

  // This function is called for plain Avax transfers, i.e.
  // for every call with empty calldata.
  receive() external payable {}
}
