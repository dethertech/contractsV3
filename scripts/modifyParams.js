require("dotenv").config();

const path = require("path");
const pretty = require("pretty-time");
const Web3 = require("web3");

const Voting = artifacts.require("Voting.sol");


module.exports = async function (callback) {
  // perform actions
  const web3 = new Web3(process.env.BSC_RPC_URL);

  const voting = await Voting.deployed();

  console.log("counter ", await voting.proposalIdCounter());
};
