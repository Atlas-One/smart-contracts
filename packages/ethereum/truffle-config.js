const Ganache = require("ganache-core");
const HDWalletProvider = require("@truffle/hdwallet-provider");

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
      provider: !process.env.CHAINSTACK_HTTP_LINK
        ? Ganache.provider({
            gasPrice: "0",
          })
        : new HDWalletProvider({
            privateKeys: [process.env.PRIVATE_KEY],
            providerOrUrl: process.env.CHAINSTACK_HTTP_LINK,
          }),
      gasPrice: 0,
      type: "quorum", // needed for Truffle to support Quorum
      network_id: "10001",
    },
    chainstack_staging: {
      provider: !process.env.CHAINSTACK_HTTP_LINK
        ? Ganache.provider({
            gasPrice: "0",
          })
        : new HDWalletProvider({
            privateKeys: [process.env.PRIVATE_KEY],
            providerOrUrl: process.env.CHAINSTACK_HTTP_LINK,
          }),
      gasPrice: 0,
      type: "quorum", // needed for Truffle to support Quorum
      network_id: "*",
    },
    infura: {
      provider: !process.env.INFURA_HTTP_LINK
        ? Ganache.provider({
            gasPrice: "0",
          })
        : new HDWalletProvider({
            privateKeys: [process.env.PRIVATE_KEY],
            providerOrUrl: process.env.INFURA_HTTP_LINK,
          }),
      network_id: "*",
    },
    kaleido_stage: {
      provider: !process.env.KALEIDO_HTTP_LINK
        ? Ganache.provider({
            gasPrice: "0",
          })
        : new HDWalletProvider({
            privateKeys: [process.env.PRIVATE_KEY],
            providerOrUrl: process.env.KALEIDO_HTTP_LINK,
          }),
      gasPrice: 0,
      network_id: "1089731529",
    },
    kaleido_prod: {
      provider: !process.env.KALEIDO_HTTP_LINK
        ? Ganache.provider({
            gasPrice: "0",
          })
        : new HDWalletProvider({
            privateKeys: [process.env.PRIVATE_KEY],
            providerOrUrl: process.env.KALEIDO_HTTP_LINK,
          }),
      gasPrice: 0,
      network_id: "1767184108",
    },
  },
  plugins: ["truffle-contract-size"],
  mocha: {
    // timeout: 100000
  },
  compilers: {
    solc: {
      version: "0.6.7",
      settings: {
        optimizer: {
          enabled: true,
        },
      },
    },
  },
};
