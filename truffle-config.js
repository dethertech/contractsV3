require("dotenv").config();
const HDWalletProvider = require("@truffle/hdwallet-provider");
const infuraKey = "fj4jll3k.....";
//
// const fs = require('fs');
// const mnemonic = fs.readFileSync(".secret").toString().trim();
const { MNEMONIC, INFURA_KEY, BSC_RPC_URL } = process.env;
console.log(BSC_RPC_URL, MNEMONIC);
module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 8545,
      network_id: "*", // Match any network id
      gas: 6700000,
    },
    bscTestnet: {
      provider: () => new HDWalletProvider(MNEMONIC, BSC_RPC_URL_TESTNET),
      network_id: 97,
      // gas: 6700000,
      // gasPrice: 10000000000,
      // skipDryRun: true,
    },
    bsc: {
      provider: () => new HDWalletProvider(MNEMONIC, BSC_RPC_URL),
      network_id: 56,
      gasPrice: 5000000000,
      // gas: 6700000,
      // gasPrice: 10000000000,
      // skipDryRun: true,
    },
    kovan: {
      provider: () =>
        new HDWalletProvider(
          MNEMONIC,
          `https://kovan.infura.io/v3/${INFURA_KEY}`
        ),

      // provider: () => new HDWalletProvider(MNEMONIC, 'http://localhost:8545'),
      network_id: 42,
      gas: 6700000,
      gasPrice: 20000000000,
      skipDryRun: true,
      // from: '0x6AAb2B0913B70270E840B14c2b23B716C0a43522',
    },
    rinkeby: {
      provider: () =>
        new HDWalletProvider(MNEMONIC, "https://rinkeby.infura.io/"),
      // provider: () => new HDWalletProvider(MNEMONIC, 'http://localhost:8545'),
      network_id: 4,
      // gas: 4700000,
      gasPrice: 20000000000,
      // from: '0x6AAb2B0913B70270E840B14c2b23B716C0a43522',
    },
    ropsten: {
      provider: () =>
        new HDWalletProvider(MNEMONIC, "https://ropsten.infura.io/"),
      network_id: 3,
      // gas: 4700000,
      gasPrice: 2000000000,
      skipDryRun: true,
    },
    mainnet: {
      // provider: () => new HDWalletProvider(MNEMONIC_MAIN, 'http://localhost:8545'),
      provider: () =>
        new HDWalletProvider(
          MNEMONIC,
          `https://mainnet.infura.io/v3/${INFURA_KEY}`
        ),
      // provider: () => new PKWalletProvider(PRIVKEY_MAIN, 'http://localhost:8545'),
      network_id: 1,
      gasPrice: 23100000000,
      gas: 8110000,
      skipDryRun: true,
      // gasPrice: 25000000000,
    },
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    // timeout: 100000
  },

  // Configure your compilers
  compilers: {
    solc: {
      version: "0.8.3",
      optimizer: {
        enabled: true,
        runs: 200,
      },
      debug: {
        revertStrings: "strip",
      },
    },
  },
};
