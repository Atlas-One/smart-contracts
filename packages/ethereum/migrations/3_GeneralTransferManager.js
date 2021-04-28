const GeneralTransferManager = artifacts.require(
  "./extension/GeneralTransferManager.sol"
);

module.exports = async function (deployer, network) {
  if (network == "test") return; // test maintains own contracts

  await deployer.deploy(GeneralTransferManager);
  const extension = await GeneralTransferManager.deployed();
  console.log(
    "\n   > GeneralTransferManager deployment: Success -->",
    extension.address
  );
};
