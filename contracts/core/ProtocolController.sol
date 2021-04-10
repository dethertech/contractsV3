// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IDetherToken.sol";
import "../interfaces/IProtocolController.sol";

import "../libraries/SharedStructs.sol";
import "../interfaces/IGeoRegistry.sol";

contract ProtocolController is IProtocolController, IERC223ReceivingContract {

    // for updating global params
    uint256 constant public MIN_BID_PERIOD = 1 hours;
    uint256 constant public MAX_BID_PERIOD = 30 days;
    uint256 constant public MIN_COOLDOWN_PERIOD = 1 hours;
    uint256 constant public MAX_COOLDOWN_PERIOD = 30 days;
    uint256 constant public MAX_ENTRY_FEE = 25; // 25%
    uint256 constant public MIN_ZONE_TAX = 1; // 0.01%
    uint256 constant public MAX_ZONE_TAX = 1000;
    uint256 constant public MAX_MIN_RAISE = 50;

    // for updating country floor stake price
    uint256 constant public MIN_FLOOR_STAKE_PRICE = 1 ether; // 1 DTH

    IDetherToken public dth;
    IGeoRegistry public geoRegistry;

    address public voting;

    uint256 public dthBalance;

    mapping (bytes2 => uint256) floorStakesPrices;

    SharedStructs.Params_t public globalParams = SharedStructs.Params_t({
        bidPeriod: 48 hours,
        cooldownPeriod: 24 hours,
        entryFee: 4,
        zoneTax: 4,
        minRaise: 6
    });

    event ReceivedTaxes(address indexed tokenFrom, uint256 taxes, address indexed from);

    // dao initiated updates
    event UpdatedCountryFloorStakePrice(bytes2 countryCode, uint256 floorStakePrice);
    event UpdatedGlobalParams(uint256 bidPeriod, uint256 cooldownPeriod, uint256 entryFee, uint256 zoneTax, uint256 minRaise);
    event WithdrawDth(address recipient, uint256 amount, string id);

    constructor(address _dth, address _voting, address _geoRegistry) {
        require(_dth != address(0), "_dth is address(0)");
        require(_voting != address(0), "_voting is address(0)");
        require(_geoRegistry != address(0), "_geoRegistry is address(0)");
        dth = IDetherToken(_dth);
        voting = _voting;
        geoRegistry = IGeoRegistry(_geoRegistry);
    }

    function _onlyVoting() private view {
        require(msg.sender == voting, "can only be called by voting contract");
    }

    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------

    function getGlobalParams() public override view returns(SharedStructs.Params_t memory params) {
        return globalParams;
    }

    function getCountryFloorPrice(bytes2 _countryCode) public override view returns(uint256 countryFloorPrice) {
        if (floorStakesPrices[_countryCode] > 0) {
            return floorStakesPrices[_countryCode];
        } else {
            return 100 ether;
        }
    }

    // ------------------------------------------------
    //
    // Functions to validate + update country floor stake price
    //
    // ------------------------------------------------

    function validateCountryFloorPrice(bytes2 _countryCode, uint256 _floorStakePrice) public view override {
        _onlyVoting();
        require(geoRegistry.zoneIsEnabled(_countryCode), "country not enabled");
        require(_floorStakePrice >= MIN_FLOOR_STAKE_PRICE, 'Floor stake price must be >= 1 DTH');
    }

    function updateCountryFloorPrice(bytes2 _countryCode, uint256 _floorStakePrice) public override {
        _onlyVoting();
        floorStakesPrices[_countryCode] = _floorStakePrice;
        emit UpdatedCountryFloorStakePrice(_countryCode, _floorStakePrice);
    }

    // ------------------------------------------------
    //
    // Functions to validate + update global params
    //
    // ------------------------------------------------

    function validateGlobalParams(SharedStructs.Params_t memory newParams) public view override {
        _onlyVoting();
        require(newParams.bidPeriod >= MIN_BID_PERIOD, 'Bid period must be >= 1 hours');
        require(newParams.bidPeriod <= MAX_BID_PERIOD, 'Bid period must be >= 1 hours');
        require(newParams.cooldownPeriod >= MIN_COOLDOWN_PERIOD, 'Bid period must be >= 30 min ');
        require(newParams.cooldownPeriod <= MAX_COOLDOWN_PERIOD, 'Bid period must be >= 30 min ');
        require(newParams.bidPeriod > newParams.cooldownPeriod, 'Bid period must be > cooldown period ');
        require(newParams.entryFee <= MAX_ENTRY_FEE, 'Entry fee must be less than 25% of current price');
        require(newParams.zoneTax >= MIN_ZONE_TAX, 'Zone Tax must be at least 0.01% daily');
        require(newParams.zoneTax <= MAX_ZONE_TAX, 'Zone Tax must be at least 10% daily');
        require(newParams.minRaise < MAX_MIN_RAISE, 'Min raise must less than 50%');
    }

    function updateGlobalParams(SharedStructs.Params_t calldata newParams) public override {
        _onlyVoting();
        globalParams = newParams;
        emit UpdatedGlobalParams(globalParams.bidPeriod, globalParams.cooldownPeriod, globalParams.entryFee, globalParams.zoneTax, globalParams.minRaise);
    }

    // ------------------------------------------------
    //
    // Functions to validate + pay out dth collected from taxes
    //
    // ------------------------------------------------

    function validateWithdrawDth(address _recipient, uint256 _amount) public view override {
        _onlyVoting();
        require(_recipient != address(0), "recipient cannot be address zero");
        require(_amount <= dth.balanceOf(address(this)), "amount is bigger than available dth");
    }

    function withdrawDth(address recipient, uint256 amount, string calldata id) public override  {
        _onlyVoting();
        require(amount <= dth.balanceOf(address(this)));
        dth.transfer(recipient, amount);
        emit WithdrawDth(recipient, amount, id);
    }

    // ------------------------------------------------
    //
    // Used to receive taxes paid by Dether contracts
    //
    // ------------------------------------------------

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public override {
        // called whenever collected taxes are transferred to this contract
    }
}
