#!/usr/bin/env node

const { TezosToolkit } = require("@taquito/taquito");
const { InMemorySigner } = require("@taquito/signer");
const accounts = require("../keystore/faucet/accounts.json");
const config = require("./config");

const network = process.argv[2] || "mondaynet";
const rpc = config.networks[network];
const account = accounts[network];


(async () => {
    const client = new TezosToolkit(rpc);

    const signer = new InMemorySigner(
        account.secretKey
    );

    client.setProvider({ signer });

    await client.wallet.transfer({
        to: process.env.PUBLIC_ADDRESS.replace(/"/g, ''),
        amount: "34620678761",
        mutez: true
    }).send();
})();
