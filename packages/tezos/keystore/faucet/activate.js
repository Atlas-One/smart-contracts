#!/usr/bin/env node

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("./accounts.json");
const config = require("../../scripts/config");

const network = process.argv[2] || "mondaynet";
const rpc = config.networks[network];
const account = accounts[network];


(async () => {
  const client = new TezosToolkit(rpc);

  const signer = new InMemorySigner(
    account.secretKey
  );

  client.setProvider({ signer });

  await client.tz
    .activate(account.pkh, account.activation_code)
    .then((o) => o.confirmation())
})();
