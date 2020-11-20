pragma solidity ^0.5.17;

contract IZone {
    function dth() public view returns (address);

    function geohash() public view returns (bytes6);

    function currentAuctionId() public view returns (uint256);

    function auctionBids(uint256, address) public view returns (uint256);

    function withdrawableDth(address) public view returns (uint256);

    function teller() public view returns (address);

    function zoneFactory() public view returns (address);

    function MIN_STAKE() public view returns (uint256);

    function country() public view returns (bytes2);

    function geo() public view returns (address);

    function withdrawableEth(address) public view returns (uint256);

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
    ) external;

    function connectToTellerContract(address _teller) external;

    function ownerAddr() external view returns (address);

    function computeCSC(bytes6 _geohash, address _addr)
        external
        pure
        returns (bytes12);

    function calcHarbergerTax(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _dthAmount
    ) public view returns (uint256 taxAmount, uint256 keepAmount);

    function calcEntryFee(uint256 _value)
        external
        view
        returns (uint256 burnAmount, uint256 bidAmount);

    function auctionExists(uint256 _auctionId) external view returns (bool);

    function getZoneOwner()
        external
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
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        );

    function processState() external;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public;

    function release() external;

    function withdrawFromAuction(uint256 _auctionId) external;

    function withdrawFromAuctions(uint256[] calldata _auctionIds) external;

    function withdrawDth() external;

    function proxyUpdateUserDailySold(address _to, uint256 _amount) external;
}
