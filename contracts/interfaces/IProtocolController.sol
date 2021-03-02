pragma solidity ^0.8.1;

abstract contract IProtocolController {
    function getGlobalParams () public virtual view returns(
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
    );

    function getCountryFloorPrice (bytes2 zoneCountry) public virtual view returns (uint256);

    function updateGlobalParams (
        uint256 BID_PERIOD,
        uint256 COOLDOWN_PERIOD,
        uint256 ENTRY_FEE,
        uint256 ZONE_TAX,
        uint256 MIN_RAISE
        )
        public  virtual;
    
    function withdrawDth(address recipient, uint256 amount, string calldata id) public virtual;
    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external virtual;
}
