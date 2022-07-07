#!/usr/bin/env node

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("./accounts.json");
const config = require("../../scripts/config");

const index = process.argv[2] || 0;
const rpc = config.networks[index];
const account = accounts[index];

(async () => {
  const client = new TezosToolkit(rpc);

  const signer = new InMemorySigner(account.secretKey);

  client.setProvider({ signer });

  await client.tz
    .activate(account.pkh, account.activation_code)
    .then((o) => o.confirmation());
})();
