pragma solidity ^0.8.1;

abstract contract IZone {
    function dth() public virtual view returns (address);

    function geohash() public virtual view returns (bytes6);

    function currentAuctionId() public virtual view returns (uint256);

    function auctionBids(uint256, address) public virtual view returns (uint256);

    function withdrawableDth(address) public virtual view returns (uint256);

    function teller() public virtual view returns (address);

    function zoneFactory() public virtual view returns (address);

    function MIN_STAKE() public virtual view returns (uint256);

    function country() public virtual view returns (bytes2);

    function geo() public virtual view returns (address);

    function withdrawableEth(address) public virtual view returns (uint256);

    function init(
        bytes2 _countryCode,
        bytes6 _geohash,
        address _zoneOwner,
        uint256 _dthAmount,
        address _dth,
        address _zoneFactory,
        address _taxCollector,
        address _teller,
        address _settings
    ) external virtual;

    function connectToTellerContract(address _teller) external virtual;

    function ownerAddr() external virtual view returns (address);

    function computeCSC(bytes6 _geohash, address _addr)
        external 
        virtual
        pure
        returns (bytes12);

    function calcHarbergerTax(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _dthAmount
    ) public virtual view returns (uint256 taxAmount, uint256 keepAmount);

    function calcEntryFee(uint256 _value)
        external 
        virtual
        view
        returns (uint256 burnAmount, uint256 bidAmount);

    function auctionExists(uint256 _auctionId) external virtual view returns (bool);

    function getZoneOwner()
        external 
        virtual
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        );

    function getAuction(uint256 _auctionId)
        external 
        virtual
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        );

    function getLastAuction()
        external 
        virtual
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        );

    function processState() external virtual;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public virtual;

    function release() external virtual;

    function withdrawFromAuction(uint256 _auctionId) external virtual;

    function withdrawFromAuctions(uint256[] calldata _auctionIds) external virtual;

    function withdrawDth() external virtual;

    function proxyUpdateUserDailySold(address _to, uint256 _amount) external virtual;
}
