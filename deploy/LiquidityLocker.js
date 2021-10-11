const { BigNumber } = require("ethers");

module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments;

  const { deployer, developer } = await getNamedAccounts();

  //const hon = await ethers.getContract("HonToken");
  const mastergamer = await ethers.getContract("MasterGamer");

  const unlockDate = new Date(2021, 10, 10, 14, 30, 0);
  const unlock = 1633893300; //unlockDate.getTime() / 1000;
  console.log(
    "Unlock timestamp: ",
    unlock,
    " - date: ",
    unlockDate.getUTCDate()
  );

  /**
   * uint256 unlock
   * IERC20 token
   * IYieldFarm farm
   *  */
  const liquidityLocker = await deploy("LiquidityLocker", {
    from: deployer,
    args: [
      unlock,
      "0x4246083C7D07e4B7Ac95E6289c93255611141021",
      mastergamer.address,
    ],
    log: true,
    deterministicDeployment: false,
  });

  console.log("LiquidityLocker address: ", liquidityLocker.address);
};

module.exports.tags = ["LiquidityLocker"];
module.exports.dependencies = [/*"HonToken",*/ "MasterGamer"];
