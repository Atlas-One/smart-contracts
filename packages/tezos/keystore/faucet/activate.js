#!/usr/bin/env node

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("./accounts.json");
const config = require("../../scripts/config");

const rpc = config.networks[process.argv[2] || "mondaynet"];

(async () => {
  const client = new TezosToolkit(rpc);

  await Promise.all(
    Object.entries(accounts).map(async ([name, wallet]) => {
      if (!wallet.activated) {
        const signer = new InMemorySigner(
          wallet.secretKey
        );

        client.setProvider({ signer });

        await client.tz
          .activate(wallet.pkh, wallet.activation_code)
          .then((o) => o.confirmation())
          .catch(console.error);
      }
    })
  );
})();
