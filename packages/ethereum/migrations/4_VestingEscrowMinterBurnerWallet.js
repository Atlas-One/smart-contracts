const { deployProxy } = require("@openzeppelin/truffle-upgrades");
const VestingEscrowMinterBurnerWallet = artifacts.require(
  "VestingEscrowMinterBurnerWallet"
);

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  const instance = await deployProxy(VestingEscrowMinterBurnerWallet, {
    deployer,
  });
  console.log(
    "\n   > VestingEscrowMinterBurnerWallet deployment: Success -->",
    instance.address,
    "\n   > SecurityTokens will need to grant this wallet MINTER_ROLE and BURNER_ROLE"
  );
};
