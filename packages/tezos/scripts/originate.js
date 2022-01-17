const config = require("./config");

const { alice } = require(`../keystore/faucet/accounts.json`);
const { importKey } = require("@taquito/signer");
const { TezosToolkit } = require("@taquito/taquito");

const tezosNode = config.networks[process.argv[2] || "hangzhounet"];

async function deploy(path, storage) {
  // path should end with _compiled
  const contractCode = require(`${__dirname}/../build/${path}_compiled/step_000_cont_0_contract.json`);
  const contractStorage = require(`${__dirname}/../build/${path}_compiled/step_000_cont_0_storage.json`);

  const client = new TezosToolkit(tezosNode);

  await importKey(client, alice.secretKey);

  const operation = await client.contract.originate(storage ? {
    code: contractCode,
    storage,
  } : {
    code: contractCode,
    init: contractStorage,
  });

  console.log(`Originating ${path}: ${operation.contractAddress}`);
  console.log(`Operation Hash: ${operation.hash} \n`);

  await operation.contract();

  console.log(`Success ------------ \n`);

  return operation.contractAddress;
}

(async () => {
  const vesting_address = await deploy("wallet/VestingEscrowMinterBurnerWallet");
  const whitelist_address = await deploy("compliance/Whitelist", {
    whitelist: [vesting_address],
    blacklist: [],
    roles: {
      0: {
        role_admin: 0,
        members: [alice.pkh]
      },
      1: {
        role_admin: 0,
        members: []
      },
      2: {
        role_admin: 0,
        members: []
      }
    }
  });
  await deploy("extension/WhitelistValidator", { whitelist_address });
  // await deploy("token/ST12");
})();
