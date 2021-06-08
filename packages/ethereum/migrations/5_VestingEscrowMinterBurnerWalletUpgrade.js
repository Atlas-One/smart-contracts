const { upgradeProxy } = require("@openzeppelin/truffle-upgrades");
const VestingEscrowMinterBurnerWallet = artifacts.require(
  "VestingEscrowMinterBurnerWallet"
);

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const instance = await VestingEscrowMinterBurnerWallet.deployed();
  await upgradeProxy(instance.address, VestingEscrowMinterBurnerWallet, {
    deployer,
  });
};
