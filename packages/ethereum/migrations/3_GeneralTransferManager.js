const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const GeneralTransferManager = artifacts.require("GeneralTransferManager");

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const instance = await deployProxy(GeneralTransferManager, { deployer });
  console.log(
    "\n   > GeneralTransferManager deployment: Success -->",
    instance.address
  );
};
