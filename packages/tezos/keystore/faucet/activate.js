#!/usr/bin/env node

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("./accounts.json");
const config = require("../../scripts/config");

const rpc = config.networks[process.argv[2] || "hangzhounet"];

(async () => {
  const client = new TezosToolkit(rpc);

  await Promise.all(
    Object.entries(accounts).map(async ([name, wallet]) => {
      const signer = InMemorySigner.fromFundraiser(
        wallet.email,
        wallet.password,
        wallet.mnemonic.join(" ")
      );

      client.setProvider({ signer });

      await client.tz
        .activate(wallet.pkh, wallet.secret)
        .then((o) => o.confirmation())
        .catch(console.error);
    })
  );
})();
