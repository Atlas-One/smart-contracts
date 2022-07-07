#!/usr/bin/env node
const fs = require("fs");
const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("./accounts.json");

const rpc = process.argv[2];

(async () => {
  const client = new TezosToolkit(rpc);

  await Promise.all(
    accounts.map(async (wallet) => {
      const signer = InMemorySigner.fromFundraiser(
        wallet.email,
        wallet.password,
        wallet.mnemonic.join(" ")
      );

      client.setProvider({ signer });

      wallet.secretKey = await signer.secretKey();
    })
  );

  fs.writeFileSync(
    __dirname + "/./accounts.json",
    JSON.stringify(accounts, null, 2),
    "utf-8"
  );
})();
