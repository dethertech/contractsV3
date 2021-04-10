/* eslint-env mocha */
/* global artifacts, contract */
/* eslint-disable max-len, no-multi-spaces, no-unused-expressions */

const DetherToken = artifacts.require("DetherToken");
const Users = artifacts.require("Users");
const CertifierRegistry = artifacts.require("CertifierRegistry");
const GeoRegistry = artifacts.require("GeoRegistry");
const ZoneFactory = artifacts.require("ZoneFactory");
const Zone = artifacts.require("Zone");
const Teller = artifacts.require("Teller");
// const TaxCollector = artifacts.require("TaxCollector");
const ProtocolController = artifacts.require("ProtocolController");

const Web3 = require("web3");

const expect = require("./utils/chai");
const TimeTravel = require("./utils/timeTravel");
const { addCountry } = require("./utils/geo");
const { ethToWei, asciiToHex, str, weiToEth } = require("./utils/convert");
const {
  expectRevert,
  expectRevert2,
  expectRevert3,
} = require("./utils/evmErrors");
const { getRandomBytes32 } = require("./utils/ipfs");
const {
  BYTES7_ZERO,
  VALID_CG_ZONE_GEOHASH,
  VALID_CG_ZONE_GEOHASH2,
  VALID_CG_ZONE_GEOHASH3,
  INVALID_CG_ZONE_GEOHASH,
  MIN_ZONE_DTH_STAKE,
  ONE_HOUR,
  ONE_DAY,
  BID_PERIOD,
  COOLDOWN_PERIOD,
  ADDRESS_ZERO,
  ADDRESS_BURN,
  BYTES32_ZERO,
  BYTES1_ZERO,
  BYTES12_ZERO,
  BYTES16_ZERO,
  ZONE_AUCTION_STATE_STARTED,
  ZONE_AUCTION_STATE_ENDED,
  TELLER_CG_POSITION,
  TELLER_CG_CURRENCY_ID,
  TELLER_CG_MESSENGER,
  TELLER_CG_SELLRATE,
  TELLER_CG_BUYRATE,
  TELLER_CG_SETTINGS,
  TELLER_CG_REFFEE,
} = require("./utils/values");

const web3 = new Web3("http://localhost:8545");
const timeTravel = new TimeTravel(web3);

const getLastBlockTimestamp = async () =>
  (await web3.eth.getBlock("latest")).timestamp;

const createDthZoneCreateData = (
  zoneFactoryAddr,
  bid,
  countryCode,
  geohash
) => {
  const fnSig = web3.eth.abi.encodeFunctionSignature(
    "transfer(address,uint256,bytes)"
  );
  const params = web3.eth.abi.encodeParameters(
    ["address", "uint256", "bytes"],
    [
      zoneFactoryAddr,
      ethToWei(bid),
      `0x${countryCode.slice(2)}${geohash.slice(2)}`,
    ]
  );
  return [fnSig, params.slice(2)].join("");
};
const createDthZoneCreateDataWithTier = (
  zoneFactoryAddr,
  bid,
  countryCode,
  geohash,
  tier
) => {
  const fnSig = web3.eth.abi.encodeFunctionSignature(
    "transfer(address,uint256,bytes)"
  );
  const params = web3.eth.abi.encodeParameters(
    ["address", "uint256", "bytes"],
    [
      zoneFactoryAddr,
      ethToWei(bid),
      `0x${countryCode.slice(2)}${geohash.slice(2)}${tier}`,
    ]
  );
  return [fnSig, params.slice(2)].join("");
};
const createDthZoneClaimFreeData = (zoneFactoryAddr, dthAmount) => {
  const fnSig = web3.eth.abi.encodeFunctionSignature(
    "transfer(address,uint256,bytes)"
  );
  const params = web3.eth.abi.encodeParameters(
    ["address", "uint256", "bytes"],
    [zoneFactoryAddr, ethToWei(dthAmount), "0x41"]
  );
  return [fnSig, params.slice(2)].join("");
};
const createDthZoneBidData = (zoneAddr, bid) => {
  const fnSig = web3.eth.abi.encodeFunctionSignature(
    "transfer(address,uint256,bytes)"
  );
  const params = web3.eth.abi.encodeParameters(
    ["address", "uint256", "bytes"],
    [zoneAddr, ethToWei(bid), "0x42"]
  );
  return [fnSig, params.slice(2)].join("");
};
const createDthZoneTopUpData = (zoneAddr, dthAmount) => {
  const fnSig = web3.eth.abi.encodeFunctionSignature(
    "transfer(address,uint256,bytes)"
  );
  const params = web3.eth.abi.encodeParameters(
    ["address", "uint256", "bytes"],
    [zoneAddr, ethToWei(dthAmount), "0x43"]
  );
  return [fnSig, params.slice(2)].join("");
};

const COUNTRY_CG = "CG";

const zoneOwnerToObj = (zoneOwnerArr) => ({
  addr: zoneOwnerArr[0],
  startTime: zoneOwnerArr[1],
  staked: zoneOwnerArr[2],
  balance: zoneOwnerArr[3],
  lastTaxTime: zoneOwnerArr[4],
  auctionId: zoneOwnerArr[5],
});
const zoneOwnerToObjPretty = (zoneOwnerArr) => ({
  addr: zoneOwnerArr[0],
  startTime: zoneOwnerArr[1].toString(),
  staked: zoneOwnerArr[2].toString(),
  balance: zoneOwnerArr[3].toString(),
  lastTaxTime: zoneOwnerArr[4].toString(),
  auctionId: zoneOwnerArr[5].toString(),
});

const tellerToObj = (tellerArr) => ({
  address: tellerArr[0],
  currencyId: tellerArr[1],
  messenger: tellerArr[2],
  position: tellerArr[3],
  settings: tellerArr[4],
  buyRate: tellerArr[5],
  sellRate: tellerArr[6],
  // funds: tellerArr[7],
  referrer: tellerArr[7],
});

const auctionToObj = (auctionArr) => ({
  id: auctionArr[0],
  state: auctionArr[1],
  startTime: auctionArr[2],
  endTime: auctionArr[3],
  highestBidder: auctionArr[4],
  highestBid: auctionArr[5],
});
const auctionToObjPretty = (auctionArr) => ({
  id: auctionArr[0].toString(),
  state: auctionArr[1].toString(),
  startTime: auctionArr[2].toString(),
  endTime: auctionArr[3].toString(),
  highestBidder: auctionArr[4],
  highestBid: auctionArr[5].toString(),
});

contract("ProtocolController + Voting", (accounts) => {
  let owner;
  let user1;
  let user2;
  let user3;
  let user4;
  let user5;

  let __rootState__; // eslint-disable-line no-underscore-dangle

  let dthInstance;
  let usersInstance;
  let geoInstance;
  let zoneFactoryInstance;
  let zoneImplementationInstance;
  let tellerImplementationInstance;
  let certifierRegistryInstance;
  let protocolControllerInstance;
  let votingInstance;

  before(async () => {
    __rootState__ = await timeTravel.saveState();
    [owner, user1, user2, user3, user4, user5] = accounts;
  });

  beforeEach(async () => {
    await timeTravel.revertState(__rootState__); // to go back to real time
    dthInstance = await DetherToken.new({ from: owner });
    certifierRegistryInstance = await CertifierRegistry.new({ from: owner });
    geoInstance = await GeoRegistry.new({ from: owner });

    protocolControllerInstance = await ProtocolController.new(
      dthInstance.address,
      { from: owner }
    );
    zoneImplementationInstance = await Zone.new({
      from: owner,
    });
    tellerImplementationInstance = await Teller.new({ from: owner });
    usersInstance = await Users.new(
      geoInstance.address,
      certifierRegistryInstance.address,
      { from: owner }
    );
    zoneFactoryInstance = await ZoneFactory.new(
      dthInstance.address,
      geoInstance.address,
      usersInstance.address,
      zoneImplementationInstance.address,
      tellerImplementationInstance.address,
      protocolControllerInstance.address,
      { from: owner }
    );

    //
    //
    // NEW STUFF
    //
    //
    dthWrapperInstance = await DthWrapper.new(dthInstance.address, { from: owner });
    votingInstance = await Voting.new(
      dthWrapperInstance.address,
      50e16,       // 50%
      75e16,       // 75%
      ethToWei(1), // 1 DTH
      60*60*24*7,  // 7 days
      { from: owner }
    );
    protocolControllerInstance = await ProtocolController.new(dthInstance.address, votingInstance.address, geoInstance.address, { from: owner });
    await votingInstance.setProtocolController(protocolControllerInstance.address, { from: owner });
  });

  const createZone = async (from, dthAmount, countryCode, geohash) => {
    await dthInstance.mint(from, ethToWei(dthAmount), { from: owner });

    const txCreate = await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: createDthZoneCreateData(
        zoneFactoryInstance.address,
        dthAmount,
        asciiToHex(countryCode),
        asciiToHex(geohash)
      ),
      value: 0,
      gas: 4700000,
    });

    const zoneAddress = await zoneFactoryInstance.geohashToZone(
      asciiToHex(geohash)
    );
    const zoneInstance = await Zone.at(zoneAddress);
    const tellerAddress = await zoneInstance.teller();
    const tellerInstance = await Teller.at(tellerAddress);
    return { zoneInstance, tellerInstance };
  };

  const placeBid = async (from, dthAmount, zoneAddress) => {
    await dthInstance.mint(from, ethToWei(dthAmount), { from: owner });
    const tx = await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: createDthZoneBidData(zoneAddress, dthAmount),
      value: 0,
      gas: 4700000,
    });
    return tx;
  };

  const claimFreeZone = async (from, dthAmount, zoneAddress) => {
    await dthInstance.mint(from, ethToWei(dthAmount), { from: owner });
    const tx = await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: createDthZoneClaimFreeData(zoneAddress, dthAmount),
      value: 0,
      gas: 4700000,
    });
    return tx;
  };

  const topUp = async (from, dthAmount, zoneAddress) => {
    await dthInstance.mint(from, ethToWei(dthAmount), { from: owner });
    const tx = await web3.eth.sendTransaction({
      from,
      to: dthInstance.address,
      data: createDthZoneTopUpData(zoneAddress, dthAmount),
      value: 0,
      gas: 4700000,
    });
    return tx;
  };

  const enableAndLoadCountry = async (countryCode) => {
    await addCountry(owner, web3, geoInstance, countryCode, 300);
  };

  describe("when succeeds after bid period ended", () => {
    let zoneInstance;
    let tellerInstance;

    // create a zone with a zone owner

    let user1dthBalanceBefore;
    let user2dthBalanceBefore;
    let user3dthBalanceBefore;
    let user2bidAmount;
    let auctionBefore;
    let withdrawTxTimestamp;
    beforeEach(async () => {
      await enableAndLoadCountry(COUNTRY_CG);
    });
    it("owner should be able to modify Params", async () => {
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD,
          COOLDOWN_PERIOD,
          ENTRY_FEE: 2,
          ZONE_TAX: 8,
          MIN_RAISE: 3,
        },
        { from: owner }
      );
      await protocolControllerInstance.setCountryFloorPrice(
        asciiToHex(COUNTRY_CG),
        ethToWei(MIN_ZONE_DTH_STAKE - 50)
      );

      const zonePrice = await protocolControllerInstance.getCountryFloorPrice(
        asciiToHex(COUNTRY_CG)
      );
      expect(zonePrice).to.be.bignumber.equal(
        ethToWei(MIN_ZONE_DTH_STAKE - 50)
      );
      const settingZone = await protocolControllerInstance.getGlobalParams();
      expect(settingZone.BID_PERIOD).to.be.bignumber.equal(
        BID_PERIOD.toString()
      );
      expect(settingZone.COOLDOWN_PERIOD).to.be.bignumber.equal(
        COOLDOWN_PERIOD.toString()
      );
      expect(settingZone.ENTRY_FEE).to.be.bignumber.equal("2");
      expect(settingZone.ZONE_TAX).to.be.bignumber.equal("8");
      expect(settingZone.MIN_RAISE).to.be.bignumber.equal("3");
    });

    it("owner should be able to modify Params and create zone", async () => {
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD,
          COOLDOWN_PERIOD,
          ENTRY_FEE: 2,
          ZONE_TAX: 8,
          MIN_RAISE: 3,
        },
        { from: owner }
      );
      // try to create a zone with 70 DTH
      // try to create a zone with 20 DTH
      await expectRevert2(
        createZone(
          user5,
          MIN_ZONE_DTH_STAKE - 30,
          COUNTRY_CG,
          VALID_CG_ZONE_GEOHASH2
        ),
        "DTH staked are not enough for this zone"
      );
      await protocolControllerInstance.setCountryFloorPrice(
        asciiToHex(COUNTRY_CG),
        ethToWei(MIN_ZONE_DTH_STAKE - 50)
      );
      // try to create a zone with 70 DTH
      try {
        ({ zoneInstance, tellerInstance } = await createZone(
          user5,
          MIN_ZONE_DTH_STAKE - 30,
          COUNTRY_CG,
          VALID_CG_ZONE_GEOHASH2
        ));
      } catch (err) {
        console.log("====> err ===>", err);
      }
      // change zone price and verify that it throw with invalid params
    });

    it("owner should be able to modify BID_PERIOD, register zone and place bid", async () => {
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD: BID_PERIOD + ONE_HOUR * 24,
          COOLDOWN_PERIOD,
          ENTRY_FEE: 2,
          ZONE_TAX: 8,
          MIN_RAISE: 3,
        },
        { from: owner }
      );
      const settingZone = await protocolControllerInstance.getGlobalParams();
      const zonePrice = await protocolControllerInstance.getCountryFloorPrice(
        asciiToHex(COUNTRY_CG)
      );
      expect(settingZone.BID_PERIOD).to.be.bignumber.equal(
        (BID_PERIOD + ONE_HOUR * 24).toString()
      );
      // open bid and try to bid after 48 hours, should succeed

      ({ zoneInstance, tellerInstance } = await createZone(
        user1,
        MIN_ZONE_DTH_STAKE,
        COUNTRY_CG,
        VALID_CG_ZONE_GEOHASH2
      ));

      await timeTravel.inSecs(COOLDOWN_PERIOD + ONE_HOUR);

      await placeBid(owner, MIN_ZONE_DTH_STAKE + 20, zoneInstance.address);
      await timeTravel.inSecs(BID_PERIOD + ONE_HOUR);
      await placeBid(user2, MIN_ZONE_DTH_STAKE + 50, zoneInstance.address);
      auctionLive = auctionToObjPretty(await zoneInstance.getLastAuction());
      expect(auctionLive.highestBidder).to.be.equal(user2);

      // modify bid period to 36h
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD: BID_PERIOD - ONE_HOUR * 12,
          COOLDOWN_PERIOD,
          ENTRY_FEE: 4,
          ZONE_TAX: 4,
          MIN_RAISE: 6,
        },
        { from: owner }
      );

      // Change are not yet active on an active auction
      await placeBid(user3, MIN_ZONE_DTH_STAKE + 90, zoneInstance.address);
      auctionLive = auctionToObjPretty(await zoneInstance.getLastAuction());
      expect(auctionLive.highestBidder).to.be.equal(user3);

      // after time bid should fail, because COOLDOWN_PERIOD is not end yet
      await timeTravel.inSecs(ONE_HOUR * 23 + COOLDOWN_PERIOD - ONE_HOUR);

      await expectRevert2(
        placeBid(user5, MIN_ZONE_DTH_STAKE + 170, zoneInstance.address),
        "cooldown period did not end yet"
      );
      // open bid and try to bid after 36h, should fail because change are now active
      await zoneInstance.withdrawFromAuction("1", { from: user2 });
      await timeTravel.inSecs(COOLDOWN_PERIOD + ONE_HOUR);
      await placeBid(user2, MIN_ZONE_DTH_STAKE + 260, zoneInstance.address);
      await timeTravel.inSecs(BID_PERIOD - ONE_HOUR * 12 + ONE_HOUR);
      await expectRevert2(
        placeBid(user5, MIN_ZONE_DTH_STAKE + 350, zoneInstance.address),
        "cooldown period did not end yet"
      );
    });

    it("owner should be able to modify COOLDOWN_PERIOD", async () => {
      const settingZonePre = await protocolControllerInstance.getGlobalParams();
      console.log(
        "settingZonePre",
        settingZonePre[0].toString(),
        settingZonePre[1].toString()
      );
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD,
          COOLDOWN_PERIOD: COOLDOWN_PERIOD + ONE_HOUR * 6,
          ENTRY_FEE: 4,
          ZONE_TAX: 4,
          MIN_RAISE: 6,
        },
        { from: owner }
      );
      const settingZone = await protocolControllerInstance.getGlobalParams();
      console.log("settingZone post", settingZone);

      expect(settingZone.COOLDOWN_PERIOD).to.be.bignumber.equal(
        (COOLDOWN_PERIOD + ONE_HOUR * 6).toString()
      );
      // open bid and try to bid after 48 hours, should succeed

      ({ zoneInstance, tellerInstance } = await createZone(
        user1,
        MIN_ZONE_DTH_STAKE,
        COUNTRY_CG,
        VALID_CG_ZONE_GEOHASH2
      ));
      await timeTravel.inSecs(COOLDOWN_PERIOD + ONE_HOUR);
      //try to bid after 25 hours, should fail

      await expectRevert2(
        placeBid(user1, MIN_ZONE_DTH_STAKE + 150, zoneInstance.address),
        "cooldown period did not end yet"
      );

      // modify for next iteration
      await protocolControllerInstance.updateGlobalParams(
        {
          BID_PERIOD,
          COOLDOWN_PERIOD: ONE_HOUR * 6,
          ENTRY_FEE: 4,
          ZONE_TAX: 4,
          MIN_RAISE: 6,
        },
        { from: owner }
      );

      await timeTravel.inSecs(ONE_HOUR * 6);
      // should succeed
      await placeBid(user2, MIN_ZONE_DTH_STAKE + 20, zoneInstance.address);
      await placeBid(user3, MIN_ZONE_DTH_STAKE + 60, zoneInstance.address);
      auctionLive = auctionToObjPretty(await zoneInstance.getLastAuction());
      expect(auctionLive.highestBidder).to.be.equal(user3);
      await timeTravel.inSecs(BID_PERIOD + ONE_HOUR);
      await zoneInstance.withdrawFromAuction("1", { from: user2 });
      await timeTravel.inSecs(ONE_HOUR * 3);
      await expectRevert2(
        placeBid(user5, MIN_ZONE_DTH_STAKE + 150, zoneInstance.address),
        "cooldown period did not end yet"
      );
      await timeTravel.inSecs(ONE_HOUR * 4);
      await placeBid(user5, MIN_ZONE_DTH_STAKE + 150, zoneInstance.address);
      auctionLive = auctionToObjPretty(await zoneInstance.getLastAuction());
      expect(auctionLive.highestBidder).to.be.equal(user5);
    });

    it("can withdraw DTH", async () => {
      // change entry fees and verify it after auction
      const preBalance = await dthInstance.balanceOf(
        protocolControllerInstance.address
      );
      ({ zoneInstance, tellerInstance } = await createZone(
        user1,
        MIN_ZONE_DTH_STAKE,
        COUNTRY_CG,
        VALID_CG_ZONE_GEOHASH
      ));
      await tellerInstance.addTeller(
        asciiToHex(TELLER_CG_POSITION),
        TELLER_CG_CURRENCY_ID,
        asciiToHex(TELLER_CG_MESSENGER),
        TELLER_CG_SELLRATE,
        TELLER_CG_BUYRATE,
        TELLER_CG_SETTINGS,
        ADDRESS_BURN,
        TELLER_CG_REFFEE,
        asciiToHex("ETH-BTC"),
        { from: user1 }
      );

      // lancer le fast forward avance dans le temp
      await timeTravel.inSecs(ONE_DAY * 365);
      await zoneInstance.processState();
      // lacher la zone
      await zoneInstance.release({ from: user1 });
      // console.log('balance post', postBalance.toString());
      const postBalance = await dthInstance.balanceOf(
        protocolControllerInstance.address
      );
      expect(postBalance).to.be.bignumber.gt(preBalance);

      // do withdraw
      const balanceRecipientPre = await dthInstance.balanceOf(user5);

      await protocolControllerInstance.withdrawDth(user5, postBalance, "TEST", {
        from: owner,
      });
      const balanceRecipientPost = await dthInstance.balanceOf(user5);

      expect(postBalance).to.be.bignumber.equal(balanceRecipientPost);
      // console.log('balanceZeroPost', balanceZeroPost.toString())
    });

    it.skip("owner should be able to modify ENTRY FEE", async () => {
      // change entry fees and verify it after auction
    });
    it.skip("owner should be able to modify MIN RAISE", async () => {
      // change min raise and verify it after auction
    });
    it.skip("owner should be able to modify ZONE_TAX", async () => {
      // change min raise and verify it after auction
      // verify amount on the duration
    });
  });
});

14293400462962962962;
14600000462962962962;
