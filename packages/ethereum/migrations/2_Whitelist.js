const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const Whitelist = artifacts.require("Whitelist");
const WhitelistValidator = artifacts.require("WhitelistValidator");

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const whitelistInstance = await deployProxy(Whitelist, { deployer });
  console.log(
    "\n   > Whitelist deployment: Success -->",
    whitelistInstance.address
  );

  const whitelistValidatorInstance = await deployProxy(WhitelistValidator, [whitelistInstance.address], { deployer });
  console.log(
    "\n   > WhitelistValidator deployment: Success -->",
    whitelistValidatorInstance.address
  );
};
