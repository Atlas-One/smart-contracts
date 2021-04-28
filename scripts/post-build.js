/** @format */

const fs = require("fs-extra");

fs.copySync("./packages/ethereum/dist/ethereum", "./dist/ethereum");
fs.copySync("./packages/tezos/dist/tezos", "./dist/tezos");
