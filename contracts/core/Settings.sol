pragma solidity ^0.5.17;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";

import "../interfaces/IGeoRegistry.sol";

contract Settings is Ownable {
    // ------------------------------------------------
    //
    // Library init
    //
    // ------------------------------------------------

    using SafeMath for uint256;

    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------
    struct Params_t {
        uint256 FLOOR_STAKE_PRICE;      // minimum required amount to stake on a zone
        uint256 BID_PERIOD;             // Time during everyon can bid, when an auction is opened
        uint256 COOLDOWN_PERIOD;        // Time when no auction can be opened after an auction end
        uint256 ENTRY_FEE;              // Amount needed to be paid when starting an auction
        uint256 ZONE_TAX;               // Amount of taxes raised
        uint256 MIN_RAISE;
        bool _changed ;
    }

    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------

    IGeoRegistry public geo;
    mapping(bytes2 =>  Params_t ) public protocolParams;
    
    Params_t defaultValue = Params_t({
        FLOOR_STAKE_PRICE : 100 ether,
        BID_PERIOD : 48 hours,
        COOLDOWN_PERIOD : 24 hours,
        ENTRY_FEE : 4,
        ZONE_TAX : 4,
        MIN_RAISE : 6,
        _changed : false
    });

    // Params_t defaultValues = Params_t({
    //     100 ether,
    //     48 hours,
    //     24 hours,
    //     4,
    //     4,
    //     6,
    //     false,
    // })

    // ------------------------------------------------
    //
    // Events
    //
    // ------------------------------------------------

    event ChangeParams(string params);

    // ------------------------------------------------
    //
    // Constructor
    //
    // ------------------------------------------------

    constructor(address _geo) public {
        geo = IGeoRegistry(_geo);
    }

    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------

    function getParams (bytes2 zoneCountry) public view returns(
       uint256 FLOOR_STAKE_PRICE,
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
    ) {
        if (protocolParams[zoneCountry].FLOOR_STAKE_PRICE > 0 && !protocolParams[zoneCountry]._changed )
        {
            return (
                100 ether,      // == 100 DTH
                48 hours,       
                24 hours,
                4,              // 4% of the amount already staked
                4,              // 0.04% daily, around 15% yearly
                6               // everybid should be more than 6% that the previous highestbid
            );
        } 
            return (
                protocolParams[zoneCountry].FLOOR_STAKE_PRICE,
                protocolParams[zoneCountry].BID_PERIOD,
                protocolParams[zoneCountry].COOLDOWN_PERIOD,
                protocolParams[zoneCountry].ENTRY_FEE,
                protocolParams[zoneCountry].ZONE_TAX,
                protocolParams[zoneCountry].MIN_RAISE
            );
        
    }

    function setParams (
        bytes2 zoneCountry,
        uint256 FLOOR_STAKE_PRICE,
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
        )
        public onlyOwner 
        {
            // check params 
            require(FLOOR_STAKE_PRICE >= 1 ether, 'Floor stake price must be >= 1 DTH');
            require(BID_PERIOD >= 1 hours, 'Bid period must be >= 1 hours');
            require(BID_PERIOD <= 30 days, 'Bid period must be >= 1 hours');
            require(COOLDOWN_PERIOD >= 1 hours, 'Bid period must be >= 30 min ');
            require(COOLDOWN_PERIOD <= 30 days, 'Bid period must be >= 30 min ');
            require(BID_PERIOD > COOLDOWN_PERIOD, 'Bid period must be > cooldown period ');
            require(ENTRY_FEE <= 25, 'Entry fee must be less than 25% of current price');
            require(ZONE_TAX >= 1, 'Zone Tax must be at least 0.01% daily');
            require(ZONE_TAX <= 1000, 'Zone Tax must be at least 10% daily');
            require(MIN_RAISE < 50, 'Min raise must less than 50%');

            protocolParams[zoneCountry].FLOOR_STAKE_PRICE = FLOOR_STAKE_PRICE;
            protocolParams[zoneCountry].BID_PERIOD = BID_PERIOD;
            protocolParams[zoneCountry].COOLDOWN_PERIOD = COOLDOWN_PERIOD;
            protocolParams[zoneCountry].ENTRY_FEE = ENTRY_FEE;
            protocolParams[zoneCountry].ZONE_TAX = ZONE_TAX;
            protocolParams[zoneCountry].MIN_RAISE = MIN_RAISE;
            protocolParams[zoneCountry]._changed = true;
        }
}
