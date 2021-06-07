const config = require("./config");

const { alice } = require(`../keystore/faucet/accounts.json`);
const { importKey } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const tezosNode = config.networks[process.argv[2]];

async function deploy(path, init) {
  // path should end with _compiled
  const contractCode = require(`${__dirname}/../build/${path}_compiled/step_000_cont_0_contract.json`);
  const contractStorage = require(`${__dirname}/../build/${path}_compiled/step_000_cont_0_storage.json`);

  const client = new TezosToolkit(tezosNode);

  await importKey(client, alice.secretKey);

  const operation = await client.contract.originate({
    code: contractCode,
    init: init || contractStorage,
  });

  console.log(`Originating ${path}: ${operation.contractAddress}`);
  console.log(`Operation Hash: ${operation.hash} \n`);

  await operation.contract();

  console.log(`Success ------------ \n`);
}

(async () => {
  await deploy("extension/GeneralTransferManager");
  await deploy("wallet/VestingEscrowMinterBurnerWallet");
})();
