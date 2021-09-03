const { BigNumber } = require("ethers");

module.exports = async function ({ ethers, deployments, getNamedAccounts }) {
  const { deploy } = deployments;

  //const { deployer, developer, treasury, gamerewards, fees } = await getNamedAccounts();
  const { deployer } = await getNamedAccounts();

  const hon = await ethers.getContract("HonToken");

  // Hon each minute = 60
  // Hon each period (1 hour) = 3100
  // Hon each year (1 hour) = 3100 * 24 * 360 = 26,784,000 for stakers
  const honPerPeriod = BigNumber.from(10).pow(18).mul(3100);
  const startPeriodMinutes = 24 * 60;
  const rewardPeriodMinutes = 60;

  /**
   *  _hon,
   *  _devaddr,
   *  _treasuryaddr
   *  _feeaddr
   *  _honPerPeriod,
   *  _startPeriodMinutes,
   *  _rewardPeriodMinutes
   */
  const { address } = await deploy("MasterGamer", {
    from: deployer,
    args: [
      hon.address,
      deployer,
      deployer,
      deployer,
      honPerPeriod.toString(),
      "15",
      "5",
    ],
    log: true,
    deterministicDeployment: false,
  });

  /*
  const MasterGamer = await ethers.getContract("MasterGamer");

  if ((await hon.owner()) !== address) {
    // Transfer Hon Ownership to MasterGamer
    console.log("Transfer Hon Ownership to MasterGamer");
    await (await hon.transferOwnership(address)).wait();
  }

  if ((await MasterGamer.owner()) !== dev) {
    // Transfer ownership of MasterGamer to dev
    console.log("Transfer ownership of MasterGamer to dev");
    await (await MasterGamer.transferOwnership(dev)).wait();
  }
  */
};

module.exports.tags = ["MasterGamer"];
module.exports.dependencies = ["HonToken"];
