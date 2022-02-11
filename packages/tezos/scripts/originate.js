const config = require("./config");
const JsonDB = require('simple-json-db');
const db = new JsonDB(__dirname + '/../networks.json');

const accounts = require(`../keystore/faucet/accounts.json`);
const { importKey } = require("@taquito/signer");
const { TezosToolkit, MichelsonMap } = require("@taquito/taquito");
const fs = require("fs");

const network = process.argv[2] || "mondaynet";
const rpc = config.networks[network];
const account = accounts[network];

async function deploy(path, storage) {
  const key = `${path} ${rpc}`;
  if (db.has(key)) {
    return db.get(key).contractAddress;
  }

  // path should end with _compiled
  const contractCode = require(`${__dirname}/../build/${path}_compiled/step_000_cont_0_contract.json`);
  const contractStorage = fs.existsSync(`${__dirname}/../build/${path}_compiled/step_000_cont_0_storage.json`) ? JSON.parse(fs.readFileSync(`${__dirname}/../build/${path}_compiled/step_000_cont_0_storage.json`).toString()) : undefined;

  const client = new TezosToolkit(rpc);

  await importKey(client, account.secretKey);

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

  db.set(key, { contractAddress: operation.contractAddress, hash: operation.hash });

  return operation.contractAddress;
}

(async () => {
  const vesting_wallet_address = await deploy("wallet/VestingEscrowMinterBurnerWallet");

  // ADMIN_ROLE = 0
  // WHITELIST_ADMIN_ROLE = 1
  // BLACKLIST_ADMIN_ROLE = 2
  const roles = new MichelsonMap();
  roles.set(0, {
    role_admin: 0,
    members: [account.pkh]
  });
  roles.set(1, {
    role_admin: 0,
    members: [account.pkh]
  });
  roles.set(2, {
    role_admin: 0,
    members: [account.pkh]
  });

  const whitelist_address = await deploy("compliance/Whitelist", {
    whitelist: [vesting_wallet_address],
    blacklist: [],
    roles
  });

  await deploy("extension/WhitelistValidator", whitelist_address);
  // await deploy("token/ST12");
})();
