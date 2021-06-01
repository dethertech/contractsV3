require("dotenv").config();
const fs = require("fs");
const Papa = require("papaparse");
const GeoRegistry = artifacts.require("GeoRegistry.sol");
const path = require("path");
const pretty = require("pretty-time");
// const Web3 = require("web3");
const { addCountry } = require("../test/utils/geo");
const delay = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const BATCH_SIZE = 300;
const countryCode = "DE";
const owner = "0x13d721b30485cf6E34776A16ac8478a15E5127a0";
const csv = fs.readFileSync("../data/countryList/country.csv", "utf8");
const { data } = Papa.parse(csv, {
  header: true,
});
console.log("data => ", data);
module.exports = async function (callback) {
  // perform actions
  // const web3 = new Web3(process.env.BSC_RPC_URL);
  const geoRegistryContract = await GeoRegistry.deployed();

  for await (country of data) {
    console.log("open country for", country.COUNTRY);
    try {
      await addCountry(
        owner,
        web3,
        geoRegistryContract,
        country.COUNTRY,
        BATCH_SIZE
      );
      console.log("pre delay");
      await delay(3000);
      console.log("post delay");
    } catch (err) {
      console.log("error add country", country, err);
    }
  }

  // const { countryGasCost, mostExpensiveTrxGasCost, txCount, countryMap } =
  //   await addCountry(owner, web3, geoRegistryContract, countryCode, BATCH_SIZE);

  // console.log("tx", txCount);
};
