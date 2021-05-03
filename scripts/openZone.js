require("dotenv").config();
const GeoRegistry = artifacts.require("GeoRegistry.sol");
const path = require("path");
const pretty = require("pretty-time");
const Web3 = require("web3");
const { addCountry } = require("../test/utils/geo");

const BATCH_SIZE = 300;
const countryCode = "";
const owner = "0x13d721b30485cf6E34776A16ac8478a15E5127a0";

module.exports = async function (callback) {
  // perform actions
  const web3 = new Web3(process.env.BSC_RPC_URL);

  const GeoRegistryContract = await GeoRegistry.deployed();
  const tx = await addCountry(
    owner,
    web3,
    GeoRegistryContract,
    countryCode,
    300
  );
  console.log("tx", tx);
};
