const BYTES1_ZERO = "0x00";
const BYTES6_ZERO = "0x000000000000";
const BYTES7_ZERO = "0x00000000000000";
const BYTES12_ZERO = "0x000000000000000000000000";
const BYTES16_ZERO = "0x00000000000000000000000000000000";
const BYTES32_ZERO =
  "0x0000000000000000000000000000000000000000000000000000000000000000";
const ADDRESS_ZERO = "0x0000000000000000000000000000000000000000";
const ADDRESS_BURN = "0xffffffffffffffffffffffffffffffffffffffff";

const COUNTRY_CG = "CG";
// const VALID_CG_ZONE_GEOHASH = 'krcztse'; // krcz is in CG
// const INVALID_CG_ZONE_GEOHASH = 'krcttse'; // krct is not in CG
const VALID_CG_ZONE_GEOHASH = "krczts"; // krcz is in CG
const VALID_CG_ZONE_GEOHASH2 = "krcztt"; // krcz is in CG
const VALID_CG_ZONE_GEOHASH3 = "krcztk"; // krcz is in CG
const INVALID_CG_ZONE_GEOHASH = "krctts"; // krct is not in CG
const NONEXISTING_CG_ZONE_GEOHASH = "krcats"; // krca, a is not a valid geohash char
const VALID_CG_SHOP_GEOHASH = "krcztseeeeee"; // krcz is in CG
const VALID_CG_SHOP_GEOHASH_2 = "krcztseeceee"; // krcy is alo in CG
const VALID_CG_SHOP_GEOHASH_3 = "krcztseedeee"; // krcy is alo in CG
const VALID_CG_SHOP_GEOHASH_4 = "krcztseedeet";
const INVALID_CG_SHOP_GEOHASH = "krcatseeeeee"; // krca, a is not a valid geohash char
const NONEXISTING_CG_SHOP_GEOHASH = "krcttseeeeee"; // krct is not in CG

const CG_SHOP_LICENSE_PRICE = 42;
const MIN_ZONE_DTH_STAKE = 100;

const ONE_HOUR = 60 * 60;
const ONE_DAY = ONE_HOUR * 24;
const BID_PERIOD = 60 * 60 * 48; // 48 hours
const COOLDOWN_PERIOD = 60 * 60 * 24; // 24 hours

const KLEROS_ARBITRATION_PRICE = 1; // eth
const KLEROS_DISPUTE_TIMEOUT = 60; // seconds
const KLEROS_ARBITRATOR_EXTRADATA = "0x8575";
const KLEROS_SHOP_WINS = 1;
const KLEROS_CHALLENGER_WINS = 2;
const KLEROS_NO_RULING = 0;

const ZONE_AUCTION_STATE_STARTED = "0";
const ZONE_AUCTION_STATE_ENDED = "1";

const TELLER_CG_POSITION = "krcztsebcddd";
const TELLER_CG_CURRENCY_ID = "1";
const TELLER_CG_MESSENGER = "my_telegram_nick";
const TELLER_CG_SELLRATE = "177"; // 1.77%
const TELLER_CG_BUYRATE = "1364"; // 13.64%
const TELLER_CG_SETTINGS = "0x03"; // 0000 0011 <-- both buyer and seller bit set
const TELLER_CG_REFFEE = 21;

const ONE_WEEK_IN_SEC = 604800;

module.exports = {
  BYTES1_ZERO,
  BYTES6_ZERO,
  BYTES7_ZERO,
  BYTES12_ZERO,
  BYTES16_ZERO,
  BYTES32_ZERO,
  ADDRESS_ZERO,
  ADDRESS_BURN,

  COUNTRY_CG,
  VALID_CG_ZONE_GEOHASH,
  VALID_CG_ZONE_GEOHASH2,
  VALID_CG_ZONE_GEOHASH3,
  INVALID_CG_ZONE_GEOHASH,
  NONEXISTING_CG_ZONE_GEOHASH,
  VALID_CG_SHOP_GEOHASH,
  VALID_CG_SHOP_GEOHASH_2,
  VALID_CG_SHOP_GEOHASH_3,
  VALID_CG_SHOP_GEOHASH_4,
  INVALID_CG_SHOP_GEOHASH,
  NONEXISTING_CG_SHOP_GEOHASH,

  MIN_ZONE_DTH_STAKE,
  CG_SHOP_LICENSE_PRICE,

  ONE_HOUR,
  ONE_DAY,
  BID_PERIOD,
  COOLDOWN_PERIOD,

  KLEROS_ARBITRATION_PRICE,
  KLEROS_DISPUTE_TIMEOUT,
  KLEROS_ARBITRATOR_EXTRADATA,
  KLEROS_SHOP_WINS,
  KLEROS_CHALLENGER_WINS,
  KLEROS_NO_RULING,

  ZONE_AUCTION_STATE_STARTED,
  ZONE_AUCTION_STATE_ENDED,

  TELLER_CG_POSITION,
  TELLER_CG_CURRENCY_ID,
  TELLER_CG_MESSENGER,
  TELLER_CG_SELLRATE,
  TELLER_CG_BUYRATE,
  TELLER_CG_SETTINGS,
  TELLER_CG_REFFEE,

  ONE_WEEK_IN_SEC
};
