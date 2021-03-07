pragma solidity ^0.8.1;

abstract contract IProtocolController {

    function getGlobalParams () public virtual view returns(uint256, uint256, uint256, uint256, uint256);

    function getCountryFloorPrice (bytes2 zoneCountry) public virtual view returns (uint256);
}
