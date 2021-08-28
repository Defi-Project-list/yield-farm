const { ethers, BigNumber } = require("ethers");

module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments;

  const { deployer, developer } = await getNamedAccounts();

  const nativeAssets = await deploy("NativeAssets", {
    from: deployer,
  });

  console.log("NativeAssets address: ", nativeAssets.address);
};

module.exports.tags = ["NativeAssets"];
