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
  const xChainAssetID = "2pJmudCy2cp4beB58r8USmGWCDxc8ikWejAh95yfgeC9tfNakS";

  const byte_array = bintools.cb58Decode(xChainAssetID);
  const hon_asset_id = BigNumber.from(byte_array);
  console.log("Hon Token Asset id: ", hon_asset_id.toString());

  await deploy("HonToken", {
    from: deployer,
    args: [
      ethers.constants.WeiPerEther.mul(total_supply),
      hon_asset_id,
    ],
    libraries: {
      NativeAssets: nativeAssets.address,
    },
    log: true,
    deterministicDeployment: false,
  });
};

module.exports.tags = ["HonToken"];
module.exports.dependencies = ["NativeAssets"];
