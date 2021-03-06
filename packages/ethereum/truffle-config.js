const Ganache = require("ganache-core");
const HDWalletProvider = require("@truffle/hdwallet-provider");
const Web3 = require("web3");

const privateKey = (process.env.PRIVATE_KEY || "").replace(/"/g, '');

const infuraProvider = (network) => new Web3.providers.HttpProvider(
  `https://${network}.infura.io/v3/bcafa70c5a3f4289b9084cda97a3a2c8`, {
  headers: process.env.INFURA_PROJECT_SECRET ? [
    {
      name: "Authorization",
      value:
        "Basic " +
        Buffer.from(":" + process.env.INFURA_PROJECT_SECRET).toString(
          "base64"
        ),
    }
  ] : []
});

module.exports = {
  contracts_directory: "./contracts",
  contracts_build_directory: "./build/contracts",
  /**
   * Networks define how you connect to your ethereum client and let you set the
   * defaults web3 uses to send transactions. If you don't specify one truffle
   * will spin up a development blockchain for you on port 9545 when you
   * run `develop` or `test`. You can ask a truffle command to use a specific
   * network from the command line, e.g
   *
   * $ truffle test --network <network-name>
   */

  networks: {
    // development: {
    //   host: "127.0.0.1",
    //   port: 8545,
    //   network_id: "*",
    // },
    chainstack_prod: {
      provider: !process.env.CHAINSTACK_HTTP_LINK || !privateKey
        ? Ganache.provider({
          gasPrice: "0",
        })
        : new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: process.env.CHAINSTACK_HTTP_LINK,
        }),
      gasPrice: 0,
      type: "quorum", // needed for Truffle to support Quorum
      network_id: "10001",
    },
    chainstack_staging: {
      provider: !process.env.CHAINSTACK_HTTP_LINK || !privateKey
        ? Ganache.provider({
          gasPrice: "0",
        })
        : new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: process.env.CHAINSTACK_HTTP_LINK,
        }),
      gasPrice: 0,
      type: "quorum", // needed for Truffle to support Quorum
      network_id: "*",
    },
    ethereum_mainnet: {
      provider: !privateKey
        ? Ganache.provider({
          gasPrice: "0",
        })
        : new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: infuraProvider("mainnet"),
        }),
      network_id: "*",
    },
    ropsten: {
      provider: !privateKey
        ? Ganache.provider({
          gasPrice: "0",
        })
        : new HDWalletProvider({
          privateKeys: [privateKey],
          providerOrUrl: infuraProvider("ropsten"),
        }),
      network_id: "*",
    }
  },
  plugins: ["truffle-contract-size"],
  mocha: {
    // timeout: 100000
  },
  compilers: {
    solc: {
      version: "0.8.12",
      settings: {
        optimizer: {
          enabled: true,
        },
      },
    },
  },
};
