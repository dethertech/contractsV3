// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IDetherToken.sol";
import "../interfaces/IProtocolController.sol";
// This contracts will be change to an aragon DAO

// TODO:
// add events
contract ProtocolController is IERC223ReceivingContract, Ownable, IProtocolController {

    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------
    IDetherToken public override dth;
    uint256 public dthBalance;
    mapping (bytes2 => uint256 ) floorStakesPrices;
    Params_t globalParams = Params_t({
        // FLOOR_STAKE_PRICE : 100 ether,
        BID_PERIOD : 48 hours,
        COOLDOWN_PERIOD : 24 hours,
        ENTRY_FEE : 4,
        ZONE_TAX : 4,
        MIN_RAISE : 6
    });


    // ------------------------------------------------
    //
    // Events
    //
    // ------------------------------------------------

    event ChangeParams(Params_t params);
    event ReceivedTaxes(
        address indexed tokenFrom,
        uint256 taxes,
        address indexed from
    );
    event WithdrawDth(address recipient, uint256 amount, string id);
    /*
     * Constructor
     */
    constructor(address _dth) {
        dth = IDetherToken(_dth);
    }
    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------

    function getGlobalParams () public override view returns(Params_t memory)
    {
        return globalParams;
    }

    function getCountryFloorPrice(bytes2 zoneCountry) override public view returns(
        uint256 countryFloorPrice
    ) {
        if (floorStakesPrices[zoneCountry] > 0 ) {
            return floorStakesPrices[zoneCountry];
        } else {
            return 100 ether;
        }
    }

    function setCountryFloorPrice (
        bytes2 zoneCountry,
        uint256 FLOOR_STAKE_PRICE
    ) public onlyOwner
    {
        require(FLOOR_STAKE_PRICE >= 1 ether, 'Floor stake price must be >= 1 DTH');
        floorStakesPrices[zoneCountry] = FLOOR_STAKE_PRICE;
    }

    function updateGlobalParams (
        Params_t calldata newParams
    )
    public onlyOwner
    {
        // check params
        require(newParams.BID_PERIOD >= 1 hours, 'Bid period must be >= 1 hours');
        require(newParams.BID_PERIOD <= 30 days, 'Bid period must be >= 1 hours');
        require(newParams.COOLDOWN_PERIOD >= 1 hours, 'Bid period must be >= 30 min ');
        require(newParams.COOLDOWN_PERIOD <= 30 days, 'Bid period must be >= 30 min ');
        require(newParams.BID_PERIOD > newParams.COOLDOWN_PERIOD, 'Bid period must be > cooldown period ');
        require(newParams.ENTRY_FEE <= 25, 'Entry fee must be less than 25% of current price');
        require(newParams.ZONE_TAX >= 1, 'Zone Tax must be at least 0.01% daily');
        require(newParams.ZONE_TAX <= 1000, 'Zone Tax must be at least 10% daily');
        require(newParams.MIN_RAISE < 50, 'Min raise must less than 50%');
        globalParams = newParams;
        emit ChangeParams(newParams);
    }
    
    function withdrawDth(address recipient, uint256 amount, string calldata id) public onlyOwner  {
        require(amount <= dth.balanceOf(address(this)));
        dth.transfer(recipient, amount);
        emit WithdrawDth(recipient, amount, id);
    }

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public override {

    }
}
