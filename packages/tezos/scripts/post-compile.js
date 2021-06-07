const fs = require("fs");

const contracts = {
  "token/ST12_compiled": "tezos/token/FA1.2",
  //   "token/ST2_compiled": "tezos/token/FA2",
  "extension/GeneralTransferManager_compiled":
    "tezos/extension/GeneralTransferManager",
  "wallet/VestingEscrowWallet_compiled":
    "tezos/wallet/VestingEscrowMinterBurnerWallet",
};

for (const [key, outputPath] of Object.entries(contracts)) {
  const compiled = require(`${__dirname}/../build/${key}/step_000_cont_0_contract.json`);
  fs.writeFileSync(
    `${__dirname}/../dist/${outputPath}.json`,
    JSON.stringify(compiled, null, 2)
  );
}
