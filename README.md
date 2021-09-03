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
* https://docs.avax.network/build/references/coreth-arc20s
* https://github.com/ava-labs/wrapped-assets/tree/arc20-contracts

## Master Gamer
Master of the yield farming, owner of the Hon Token. Generally yield farm MasterChef contracts mint the token
they're distributing. However Hon Token is already minted so that MasterGamer only transfers the Hon Token it has.
Avalanche's c-chain has nondeterministic block times, so to make a healthy yield farm we choose to depend on 
time periods. Normally in ethereum contracts reward is distributed on each block instead in our farm 
reward distributed after a period. This period is more than 1 minute and we chose it to 1 hour. So if someone
gathered his reward, the next reward he can get after an hour.

References:
* https://support.avax.network/en/articles/5106526-measuring-time-in-smart-contracts



## Networks

* FUJI
Pangolin addresses
Router: 0x2D99ABD9008Dc933ff5c0CD271B88309593aB921
Factory: 0xE4A575550C2b460d2307b82dCd7aFe84AD1484dd
WAVAX: 0xd00ae08403B9bbb9124bB305C09058E32C39A48c
PGL: 0xF0dCBF8abd26C28112a948C340eb294293bf29A2

Hon: 0x637CD98eBeaECF6051a5B82c709A969B483f8ba5
Hon AssetId: 2WMQ15ef66YmQ5od4MAUsT9YsGuwsC2WGpqGedTpatWj8woSk6
MasterGamer: 0x4a1866ee249EAAAFf10028E5DC1cD05C12dc72cf
HeroesToken: 
Marketplace: 

* MAINNET
TODO:

## Deployment cost


## ANT and ARC-20
Example transaction flow. From initial token creation on Xchain, then importing these tokens into 
Cchain contract.

**minter local node X address:** X-fuji1f5f8hxgpyneyrs9g28fhffuqrsydzj9e5nm62q
**minter local node C address:** C-fuji1f5f8hxgpyneyrs9g28fhffuqrsydzj9e5nm62q
**minter c chain address:** 0x9739f855697c65Ab6CeAC700F4c6Fa617c3Ad799
**dev c chain address:** 0xe6981A95885fDC9D2fcaa9A177648eCf7B124edA

**HON (ANT) x chain address / asset id:** 2WMQ15ef66YmQ5od4MAUsT9YsGuwsC2WGpqGedTpatWj8woSk6
**HON (ARC-20) c chain address:** 0x637CD98eBeaECF6051a5B82c709A969B483f8ba5

### Transaction flow
**Create fixed cap asset:** 2WMQ15ef66YmQ5od4MAUsT9YsGuwsC2WGpqGedTpatWj8woSk6
**Export AVAX:** uiiT4nJtGncKpGw9z4uGCw6Yjqxn47M5NTaRdBoqNTQJmr2D6
**Export HON (ANT):** 2buVnAjJWZ3fUFgHuTYkTJjvNcTS8dkWfAFdWf8PXyuwhRDseW
**Import HON (ANT):** 2DTJepyyAZE6AsRwMpjd6HXo1cufPpHSzp8hTjnKDkGPG95w74
**Deploy smart contract:** 0x809d0c1e96d3a9b7b75f910136530b7cd59b6d85cfe928d974392b185a3c183a
**Deposit HON (ANT) to smart contract:** 0x6faab5217c774dde2845f9ed6c5ecbc2a55d61f01a0c8c71bd743264f2f024cb


**transfer HON (ARC-20):** 0x495085270e8e511d20bc4f26ba5f208545de1dcb7521eaf3b767973bd3099c89
**withdraw HON (ANT) from smart contract:** 0x4fa8a1b25e41c2fbf92c4a88fc5af9818ad9d27385e01e1865504894d50ad37a
**Export HON (ARC-20) from C-chain:** 2ZaAUTqLeL1RMR3LTnFsBopC48NJ848W9jKGPnJoSgvuWnWtEz
**Export AVAX from C-chain:** A8P4D7feyzQd8p6emoY1RtkUA4cohQaY8KCh7mQteViV5cyff
**Import HON (ARC-20) to X-chain:** pv4tDTHvpjnZhJJ2NgBNGknnFPvZKWzjEirEaYYBw4aYmvq1P

**Transfer HON (ANT):** 25v9fYgM1ejpFmTTWL9frqFKAEMKCJ1oYUTeRRZC1ZoF53mrzh
**Transfer HON (ANT):** yp3gJszmmozAPH21rwz1nKMoA7JZ7s2mV24ww3yGBtjrJ7epr

**Export HON (ANT) from X-chain:** 2srAvTwfqeynAbDz7zH9j3k5nTzQo1paXiVNdxE4XmLJhuv7t5
**Export AVAX from X-chain:** 2S5kDbNLDd6Lc3p1qpsPwB43gpKjZQuvrUj4dHhS9YNVacZ4dR
**Import HON (ANT) to C-chain:** bbi5h2ft7sq2pYTzcNTxwRujYHBc3bkyUTo2VspXbfpFtozdj
**Deposit HON (ANT) to smart contract:** 0x01011b0032ab6d803dbd6ae7420ce432b37c3dc311f2efa6d6cc262aaca5303a




