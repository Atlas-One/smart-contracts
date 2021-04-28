const VestingEscrowWallet = artifacts.require(
  "./wallet/VestingEscrowWallet.sol"
);

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  await deployer.deploy(VestingEscrowWallet);
  const wallet = await VestingEscrowWallet.deployed();
  console.log(
    "\n   > VestingEscrowWallet deployment: Success -->",
    wallet.address,
    "\n   > SecurityTokens will need to grant this wallet MINTER_ROLE and BURNER_ROLE"
  );
};
