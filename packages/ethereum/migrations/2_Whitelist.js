const { deployProxy } = require("@openzeppelin/truffle-upgrades");

const Whitelist = artifacts.require("Whitelist");
const WhitelistValidator = artifacts.require("WhitelistValidator");

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const instance = await deployProxy(Whitelist, { deployer });
  console.log(
    "\n   > Whitelist deployment: Success -->",
    instance.address
  );

  const instance = await deployProxy(WhitelistValidator, [instance.address], { deployer });
  console.log(
    "\n   > WhitelistValidator deployment: Success -->",
    instance.address
  );
};
