const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const VestingEscrowWallet = artifacts.require("VestingEscrowWallet");

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const instance = await deployProxy(VestingEscrowWallet, { deployer });
  console.log(
    "\n   > VestingEscrowWallet deployment: Success -->",
    instance.address,
    "\n   > SecurityTokens will need to grant this wallet MINTER_ROLE and BURNER_ROLE"
  );
};
