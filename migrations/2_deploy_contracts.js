/* global artifacts */
const DetherToken = artifacts.require("DetherToken.sol");
const CertifierRegistry = artifacts.require("CertifierRegistry");
const Users = artifacts.require("Users.sol");
const GeoRegistry = artifacts.require("GeoRegistry.sol");
const ZoneFactory = artifacts.require("ZoneFactory.sol");
const Zone = artifacts.require("Zone.sol");
const Teller = artifacts.require("Teller.sol");
const Shops = artifacts.require("Shops.sol");
const TaxCollector = artifacts.require("TaxCollector.sol");
const Settings = artifacts.require("Settings.sol");

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
      await deployer.deploy(DetherToken, { gas: 6500000 });
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

  await deployer.deploy(TaxCollector, dth.address, ADDRESS_ZERO, {
    gas: 6500000,
  });
  const taxCollector = await TaxCollector.deployed();

  await deployer.deploy(CertifierRegistry, { gas: 6500000 });
  const certifierRegistry = await CertifierRegistry.deployed();

  await deployer.deploy(GeoRegistry, { gas: 6500000 });
  const geo = await GeoRegistry.deployed();

  await deployer.deploy(Settings, { gas: 6500000 });
  const settings = await Settings.deployed();

  await deployer.deploy(Zone, { gas: 10000000 });
  const zoneImplementation = await Zone.deployed();

  await deployer.deploy(Teller, { gas: 6500000 });
  const tellerImplementation = await Teller.deployed();

  await deployer.deploy(Users, geo.address, certifierRegistry.address, {
    gas: 6500000,
  });
  const users = await Users.deployed();

  await deployer.deploy(
    ZoneFactory,
    dth.address,
    geo.address,
    users.address,
    zoneImplementation.address,
    tellerImplementation.address,
    taxCollector.address,
    settings.address,
    { gas: 6500000 }
  );
  const zoneFactory = await ZoneFactory.deployed();

  switch (network) {
    case "kovan":

    case "mainnet":
      await users.setZoneFactory(ZoneFactory.address, { gas: 6500000 });
      console.log("Set zone factory");
  }

  await deployer.deploy(
    Shops,
    dth.address,
    geo.address,
    users.address,
    zoneFactory.address,
    { gas: 6500000 }
  );
};
