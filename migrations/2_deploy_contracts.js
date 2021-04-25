const { ethToWei, toVotingPerc } = require('../test/utils/convert');
/* global artifacts */
const DetherToken = artifacts.require("DetherToken.sol");
const CertifierRegistry = artifacts.require("CertifierRegistry");
const Users = artifacts.require("Users.sol");
const GeoRegistry = artifacts.require("GeoRegistry.sol");
const ZoneFactory = artifacts.require("ZoneFactory.sol");
const FeeTaxHelpers = artifacts.require("FeeTaxHelpers.sol");
const ZoneOwnerUtils = artifacts.require("ZoneOwnerUtils.sol");
const AuctionUtils = artifacts.require("AuctionUtils.sol");
const Zone = artifacts.require("Zone.sol");
const Teller = artifacts.require("Teller.sol");
const Shops = artifacts.require("Shops.sol");
const ProtocolController = artifacts.require("ProtocolController.sol");
const DthWrapper = artifacts.require("DthWrapper.sol");
const Voting = artifacts.require("Voting.sol");

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
// const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// file will be deployed. therefore comment them out until you actually want to deploy.
module.exports = async (deployer, network) => {
  console.log("Deploy contract to => ", network);

  // await deployer.deploy(DetherToken, { gas: 6500000 });
  let dth;
  switch (network) {
    case "develop":
    // use a fake instance to test locally using truffle develop
    // fall through
    case "rinkeby":
    // use a fake instance to test locally using truffle develop
    // fall through
    case "development":
    // use a fake instance to test locally using ganache
    // fall through
    case "ropsten":
      await deployer.deploy(DetherToken);
      dth = await DetherToken.deployed();
      break;

    case "kovan-fork":
    // fall through

    case "kovan":
      dth = await DetherToken.at("0x9027e9fc4641e2991a36eaeb0347bc5b35322741"); // DTH kovan address
      break;

    case "mainnet":
      dth = await DetherToken.at("0x5adc961D6AC3f7062D2eA45FEFB8D8167d44b190"); // DTH mainnet address
      break;

    default:
      throw new Error(
        `did not specify how to deploy ExchangeRateOracle on this network (${network})`
      );
  }

  await deployer.deploy(CertifierRegistry);
  const certifierRegistry = await CertifierRegistry.deployed();

  await deployer.deploy(GeoRegistry);
  const geo = await GeoRegistry.deployed();

  await deployer.deploy(FeeTaxHelpers);
  //const feeTaxHelper = await FeeTaxHelpers.deployed();
  deployer.link(FeeTaxHelpers, [ZoneOwnerUtils, AuctionUtils, Zone]);
  await deployer.deploy(AuctionUtils);
  //const auctionUtils = await AuctionUtils.deployed();
  deployer.link(AuctionUtils, Zone);
  await deployer.deploy(ZoneOwnerUtils);
  //const zoneownerUtils = await ZoneOwnerUtils.deployed();
  deployer.link(ZoneOwnerUtils, Zone);

  await deployer.deploy(Zone);
  const zoneImplementation = await Zone.deployed();

  await deployer.deploy(Teller);
  const tellerImplementation = await Teller.deployed();

  await deployer.deploy(Users, geo.address, certifierRegistry.address, {
    gas: 6500000,
  });
  const users = await Users.deployed();

  // voting stuff

  await deployer.deploy(DthWrapper, dth.address);
  const dthWrapper = await DthWrapper.deployed();

  await deployer.deploy(Voting, dthWrapper.address, toVotingPerc(25), toVotingPerc(60), ethToWei(10), 7*24*60*60);
  const voting = await Voting.deployed();

  await deployer.deploy(ProtocolController, dth.address, voting.address, geo.address);
  const protocolController = await ProtocolController.deployed();

  await voting.setProtocolController(protocolController.address)

  await deployer.deploy(
    ZoneFactory,
    dth.address,
    geo.address,
    users.address,
    zoneImplementation.address,
    tellerImplementation.address,
    protocolController.address,
    { gas: 6500000 }
  );
  const zoneFactory = await ZoneFactory.deployed();

  switch (network) {
    case "kovan":

    case "mainnet":
      await users.setZoneFactory(ZoneFactory.address);
      console.log("Set zone factory");
  }

  await deployer.deploy(
    Shops,
    dth.address,
    geo.address,
    users.address,
    zoneFactory.address
  );

};
