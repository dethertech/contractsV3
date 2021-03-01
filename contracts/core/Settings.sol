pragma solidity ^0.8.1;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

// This contracts will be change to an aragon DAO

contract Settings is Ownable {

    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------
    struct Params_t {
        // uint256 FLOOR_STAKE_PRICE;      // minimum required amount to stake on a zone
        uint256 BID_PERIOD;             // Time during everyon can bid, when an auction is opened
        uint256 COOLDOWN_PERIOD;        // Time when no auction can be opened after an auction end
        uint256 ENTRY_FEE;              // Amount needed to be paid when starting an auction
        uint256 ZONE_TAX;               // Amount of taxes raised
        uint256 MIN_RAISE;
    }

    struct FloorStake_t {
        uint256 FLOOR_STAKE_PRICE;
        bool _changed;
    }
    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------

    mapping (bytes2 => FloorStake_t) floorStakesPrices;

    Params_t public globalParams = Params_t({
        // FLOOR_STAKE_PRICE : 100 ether,
        BID_PERIOD : 48 hours,
        COOLDOWN_PERIOD : 24 hours,
        ENTRY_FEE : 4,
        ZONE_TAX : 4,
        MIN_RAISE : 6
    });
    
    // Params_t public defaultValue = Params_t({
    //     FLOOR_STAKE_PRICE : 100 ether,
    //     BID_PERIOD : 48 hours,
    //     COOLDOWN_PERIOD : 24 hours,
    //     ENTRY_FEE : 4,
    //     ZONE_TAX : 4,
    //     MIN_RAISE : 6,
    //     _changed : false
    // });


    // ------------------------------------------------
    //
    // Events
    //
    // ------------------------------------------------

    event ChangeParams(string params);

    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------

function getGlobalParams() public view returns(
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
) {
    return (
        globalParams.BID_PERIOD,
        globalParams.COOLDOWN_PERIOD,
        globalParams.ENTRY_FEE,
        globalParams.ZONE_TAX,
        globalParams.MIN_RAISE
    );
}

function getCountryFloorPrice(bytes2 zoneCountry) public view returns(
    uint256 countryFloorPrice
) {
    if (floorStakesPrices[zoneCountry].FLOOR_STAKE_PRICE > 0 && floorStakesPrices[zoneCountry]._changed ) {
        return floorStakesPrices[zoneCountry].FLOOR_STAKE_PRICE;
    } else {
        return 100 ether;
    }
}



    // function getParams (bytes2 zoneCountry) public view returns(
    //    uint256 FLOOR_STAKE_PRICE,
    //     uint256 BID_PERIOD,
    //     uint256 COOLDOWN_PERIOD,
    //     uint256 ENTRY_FEE,
    //     uint256 ZONE_TAX,
    //     uint256 MIN_RAISE
    // ) {
    //     if (protocolParams[zoneCountry].FLOOR_STAKE_PRICE > 0 && protocolParams[zoneCountry]._changed )
    //     {
    //         return (
    //             protocolParams[zoneCountry].FLOOR_STAKE_PRICE,
    //             protocolParams[zoneCountry].BID_PERIOD,
    //             protocolParams[zoneCountry].COOLDOWN_PERIOD,
    //             protocolParams[zoneCountry].ENTRY_FEE,
    //             protocolParams[zoneCountry].ZONE_TAX,
    //             protocolParams[zoneCountry].MIN_RAISE
    //         );

    //     } else { // return default value
    //         return (
    //             100 ether,      // == 100 DTH
    //             48 hours,       
    //             24 hours,
    //             4,              // 4% of the amount already staked
    //             4,              // 0.04% daily, around 15% yearly
    //             6               // everybid should be more than 6% that the previous highestbid
    //         );
    //     }
    // }

    // function getZonePrice (bytes2 zoneCountry) public view returns (uint256 price) {
    //     if (protocolParams[zoneCountry].FLOOR_STAKE_PRICE > 0 && protocolParams[zoneCountry]._changed ) {
    //          return protocolParams[zoneCountry].FLOOR_STAKE_PRICE;

    //     } else {
    //                    return 100 ether;
    //     }
    // }
    // event SetParams(uint256FLOOR_STAKE_PRICE,)

    function setCountryFloorPrice (
        bytes2 zoneCountry,
        uint256 FLOOR_STAKE_PRICE
    ) public onlyOwner
    {
        require(FLOOR_STAKE_PRICE >= 1 ether, 'Floor stake price must be >= 1 DTH');
        floorStakesPrices[zoneCountry].FLOOR_STAKE_PRICE = FLOOR_STAKE_PRICE;
        floorStakesPrices[zoneCountry]._changed = true;
    }

    function updateGlobalParams (
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
        )
        public onlyOwner 
        {
            // check params 
            require(BID_PERIOD >= 1 hours, 'Bid period must be >= 1 hours');
            require(BID_PERIOD <= 30 days, 'Bid period must be >= 1 hours');
            require(COOLDOWN_PERIOD >= 1 hours, 'Bid period must be >= 30 min ');
            require(COOLDOWN_PERIOD <= 30 days, 'Bid period must be >= 30 min ');
            require(BID_PERIOD > COOLDOWN_PERIOD, 'Bid period must be > cooldown period ');
            require(ENTRY_FEE <= 25, 'Entry fee must be less than 25% of current price');
            require(ZONE_TAX >= 1, 'Zone Tax must be at least 0.01% daily');
            require(ZONE_TAX <= 1000, 'Zone Tax must be at least 10% daily');
            require(MIN_RAISE < 50, 'Min raise must less than 50%');

            globalParams.BID_PERIOD = BID_PERIOD;
            globalParams.COOLDOWN_PERIOD = COOLDOWN_PERIOD;
            globalParams.ENTRY_FEE = ENTRY_FEE;
            globalParams.ZONE_TAX = ZONE_TAX;
            globalParams.MIN_RAISE = MIN_RAISE;
            // emit
        }
}
