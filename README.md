# Heroes of Nft Yield Farming
## Hon Token
Fixed supply Avalanche Cross-chain compatible ERC-20 (ARC-20) token.
All of the Hon Tokens(200,000,000.00) are minted on Avalanche's x-chain as ANT(Avalanche Native Token).
The Hon Tokens then are transferred to the MasterGamer contract on c-chain. 
To accomplish this, a transaction with data calling `deposit()` function of the target contract,
is sent to the special precompiled contract that resides in 0x0100000000000000000000000000000000000002 (NativeAssets).
Then this contract holds HON (ANT) in special wallet and calls the deposit function with same amount.
After calling `deposit()` function the same amount HON (ARC20) is created in c-chain on Hon Token contract.
HON (ARC20) is just a representation of the HON (ANT) on c-chain. X-chain currently doesn't support smart contracts.
X-chain supports 9 decimals, so to make Hon Token compatible with other ERC-20, it's multiplied with 10^9 in `deposit()`
and divided by 10^9 in `withdraw()` function.

References:
* [Coreth Arc20](https://docs.avax.network/build/references/coreth-arc20s)
* [Arc20 Contracts](https://github.com/ava-labs/wrapped-assets/tree/arc20-contracts)

## Master Gamer
Master of the yield farming, owner of the Hon Token. Generally yield farm MasterChef contracts mint the token
they're distributing. However Hon Token is already minted so that MasterGamer only transfers the Hon Token it has.
Avalanche's c-chain has nondeterministic block times, so to make a healthy yield farm we choose to depend on 
time periods. Normally in ethereum contracts reward is distributed on each block instead in our farm 
reward distributed after a period. This period is more than 1 minute and we chose it to 1 hour. So if someone
gathered his reward, the next reward he can get after an hour.

References:
* [Avalanche Measuring Time](https://support.avax.network/en/articles/5106526-measuring-time-in-smart-contracts)


## Networks

### AVALANCHE MAINNET
1. Contract addresses
  * **Hon:** 0xEd2b42D3C9c6E97e11755BB37df29B6375ede3EB
  * **Hon Xchain AssetId:** 2qTqfExA4Du47qhnAHVyEuCpzUY9n32jnjUC9h6vvqFhNoijHk
  * **MasterGamer:** 
  * **HeroesToken:** 
  * **Marketplace:** 
2. Wallet addresses
  * **Deployer Cchain:** 0x4464bbe40cc1f1184bda0d43c010298fda3d8d7e
  * **Deployer Xchain:** X-avax14hn68j6d4aprx5gvusrskaeuww870eey9js87m
  * **Developer Cchain:** 0xBf7DD80dc9762D04C4cB0DfEe1ed2F5955AdbD38
  * **Multisig:** 
3. Transactions
  * Hon Xchain Creation: 2qTqfExA4Du47qhnAHVyEuCpzUY9n32jnjUC9h6vvqFhNoijHk, cost: 0.01 Avax
  * Hon Xchain Export: mpMbQn1LtEMDvEr7aFBmQr7V9dPr9b7cYzXUFcxgAEMXpqLav, cost: 0.001 Avax
  * Avax Export: umZ2zewSmv8ePANrMgY8otGyNdegns1fFG4ysEUGWFceboPKM, cost: 0.001 Avax
  * Hon Cchain Import: Q9z7BNf1xz71cWUopVx3aLQzrbjtTwPXW7odzhnsZfZw8kats, cost: 0.001 Avax
  * 
  * Hon Contract Deployment: 0x97e6847b3e90d5f40246ce847e88265527bec1872ede7d9e47451765914edc87, cost: 0.998 Avax
  * Hon Deposit: 0xc5ad6d3c56b8a5245e0bebca8d8f0d588cab306799d6a901e7480aaa3648aee7, cost: 0.0027 Avax
  * 

### FUJI
1. Contract addresses
  * **Hon:** 0x4246083C7D07e4B7Ac95E6289c93255611141021
  * **Hon Xchain AssetId:** zdXmHXkF2pDpJv5zWPeNesgGja7jX17U5ea48mdsWiCNyUqRe
  * **MasterGamer:** 
  * **HeroesToken:** 
  * **Marketplace:** 
2. Wallet addresses
  * **Deployer Cchain:** 0x4464bbe40cc1f1184bda0d43c010298fda3d8d7e
  * **Deployer Xchain:** X-avax14hn68j6d4aprx5gvusrskaeuww870eey9js87m
  * **Developer Cchain:** 0xBf7DD80dc9762D04C4cB0DfEe1ed2F5955AdbD38
  * **Multisig:** 
3. Transactions
  * Hon Xchain Creation: zdXmHXkF2pDpJv5zWPeNesgGja7jX17U5ea48mdsWiCNyUqRe, cost: 0.01 Avax
  * Hon Xchain Export: nZau5kmxV1hKxHYuYXTELWboGk5h557WQAXbC4HEer56RARPG, cost: 0.001 Avax
  * Avax Export: 2AWNiDVnuk3aCfYVwWunFd3xTtRifHVSZ96ee8t5L1Eeoz7A91, cost: 0.001 Avax
  * Hon Cchain Import: JuMAhTzBgohu4UGSVF8sKjDSXiQpDjrH4ZxvHsWHMQPRKNpTF, cost: 0.001 Avax
  * 
  * Hon Contract Deployment: 0xe3f22442d2b9517e23ae5ba54112480681f7c4c411a00cb222c88b1c0758abe5, cost: 0.998 Avax
  * Hon Deposit: 0x82b92e1d6af1640946fd2f29ed9c62e17157f2ccff49aeaa9c17cb0a999feaff, cost: 0.0027 Avax
  * Hon Deposit: 0xd740837d528085f62e2e067ba3017186675de0688465b404a205a6a415c481ec, cost: 0.0018 Avax
  * 

