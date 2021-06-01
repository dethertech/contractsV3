const { ethToWei, toVotingPerc } = require("../test/utils/convert");
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
const AnyswapV4ERC20 = artifacts.require("AnyswapV4ERC20.sol");

const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
// const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

// file will be deployed. therefore comment them out until you actually want to deploy.
module.exports = async (deployer, network, accounts) => {
  // await deployer.deploy(DetherToken, { gas: 6500000 });
  let dth;
  let tempToken;
  switch (network) {
    case "development":
      // use a fake instance to test locally using truffle develop
      // fall through
      await deployer.deploy(DetherToken);
      tempToken = await DetherToken.deployed();
      await tempToken.mint(accounts[0], web3.utils.toWei("100000", "ether"));
      // anyswap
      await deployer.deploy(
        AnyswapV4ERC20,
        "ANYDTH",
        "DTH",
        18,
        tempToken.address,
        accounts[0]
      );
      dth = await AnyswapV4ERC20.deployed();
      await tempToken.approve(dth.address, web3.utils.toWei("100000", "ether"));
      // should init vault ??
      await dth.deposit(web3.utils.toWei("10000", "ether"), accounts[0]);
      // call
      break;

    case "rinkeby":
    // use a fake instance to test locally using truffle develop
    // fall through
    case "development":
    // use a fake instance to test locally using ganache
    // fall through
    // case "ropsten":
    //   await deployer.deploy(DetherToken);
    //   dth = await DetherToken.deployed();
    //   break;
    case "bscTestnet":
      dth = await AnyswapV4ERC20.at(
        "0xbD27E1B4d05B04b6501eF609aBc9b37963814163"
      );
      break;
    case "bsc":
      dth = await AnyswapV4ERC20.at(
        "0xdc42728b0ea910349ed3c6e1c9dc06b5fb591f98"
      );
      break;
    case "kovan-fork":

    // case "kovan":
    //   dth = await DetherToken.at("0x9027e9fc4641e2991a36eaeb0347bc5b35322741"); // DTH kovan address
    //   break;

    // case "mainnet":
    //   dth = await DetherToken.at("0x5adc961D6AC3f7062D2eA45FEFB8D8167d44b190"); // DTH mainnet address
    //   break;

    default:
      throw new Error(
        `did not specify how to deploy DTH on this network (${network})`
      );
  }

  await deployer.deploy(CertifierRegistry);
  const certifierRegistry = await CertifierRegistry.deployed();

  let geo;
  if (network === "bsc") {
    geo = await GeoRegistry.at("0x4cFf328AA985218856184bC92d469aA08387C0DC");
  } else {
    await deployer.deploy(GeoRegistry);
    geo = await GeoRegistry.deployed();
  }

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
  let dthWrapper;
  if (network === "bscTestnet") {
    dthWrapper = await DthWrapper.at(
      "0xe3c6Dad22785EA3166e692bCEb02DFeDDcde825C"
    );
  } else {
    await deployer.deploy(DthWrapper, dth.address);
    dthWrapper = await DthWrapper.deployed();
  }

  // await deployer.deploy(DthWrapper, dth.address);
  // const dthWrapper = await DthWrapper.deployed();

  await deployer.deploy(
    Voting,
    dthWrapper.address,
    toVotingPerc(25),
    toVotingPerc(60),
    ethToWei(10),
    45 * 60 // for mainnet 5 jours
    // 5 * 24 * 60 * 60 // for mainnet 5 jours
  );
  const voting = await Voting.deployed();

  await deployer.deploy(
    ProtocolController,
    dth.address,
    voting.address,
    geo.address
  );
  const protocolController = await ProtocolController.deployed();

  await voting.setProtocolController(protocolController.address);

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
