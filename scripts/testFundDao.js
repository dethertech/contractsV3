require("dotenv").config();
const DetherToken = artifacts.require("DetherToken.sol");
const Voting = artifacts.require("Voting.sol");

const Web3 = require("web3");

const amount = "10";
module.exports = async function (callback) {
  // perform actions
  console.log("YOLO");
  const web3 = new Web3(process.env.BSC_RPC_URL);

  const Dth = await DetherToken.at(
    "0xbD27E1B4d05B04b6501eF609aBc9b37963814163"
  );

  const Vote = await Voting.deployed();

  const tx = await Dth.transfer(
    Vote.address,
    web3.utils.toWei(amount, "ether"),
    "0x"
  );

  console.log("tx", tx);
};
