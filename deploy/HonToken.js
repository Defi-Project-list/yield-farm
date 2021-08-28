const { BigNumber } = require("ethers");
const { Avalanche, BinTools, Buffer, BN } = require("avalanche");

module.exports = async function ({ ethers, getNamedAccounts, deployments }) {
  const { deploy } = deployments;
  const bintools = BinTools.getInstance();

  const { deployer } = await getNamedAccounts();

  const nativeAssets = await ethers.getContract("NativeAssets");
  console.log(nativeAssets.address);

  const denomination = 18;
  const total_supply = 200000000;
  const pre_mint = 10000000;
  const xChainAssetID = "2WMQ15ef66YmQ5od4MAUsT9YsGuwsC2WGpqGedTpatWj8woSk6";

  const byte_array = bintools.cb58Decode(xChainAssetID);
  const hon_asset_id = BigNumber.from(byte_array);
  console.log("Hon Token Asset id: ", hon_asset_id.toString());

  await deploy("HonToken", {
    from: deployer,
    args: [
      ethers.constants.WeiPerEther.mul(total_supply),
      deployer,
      deployer,
      hon_asset_id,
    ],
    libraries: {
      NativeAssets: nativeAssets.address,
    },
    log: true,
    deterministicDeployment: false,
  });

  /*
  // TODO: Do not MINT
  const hon_token = await ethers.getContract("HonToken");
  const total_supply_returned = await hon_token.totalSupply();

  console.log("Pre minting 10,000,000 HON for in game usage and airdrop");
  await hon_token.mint(deployer, ethers.constants.WeiPerEther.mul(pre_mint), {
    from: deployer,
    gasLimit: BigNumber.from(8000000),
  });

  console.log("HON token total supply: ", total_supply_returned.toString());
  */
};

module.exports.tags = ["HonToken"];
module.exports.dependencies = ["NativeAssets"];
