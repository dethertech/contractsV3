pragma solidity ^0.7.6;

contract ISettings {
     function getParams (bytes2 zoneCountry) public view returns(
       uint256 FLOOR_STAKE_PRICE,
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
    );

    function getZonePrice (bytes2 zoneCountry) public view returns (uint256);

        function setParams (
        bytes2 zoneCountry,
        uint256 FLOOR_STAKE_PRICE,
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
        )
        public  ;
}