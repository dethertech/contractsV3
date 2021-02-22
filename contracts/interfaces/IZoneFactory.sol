pragma solidity ^0.7.6;

abstract contract IZoneFactory {
    function dth() external virtual view returns (address);

    function zoneToGeohash(address) external virtual view returns (bytes6);

    function geohashToZone(bytes6) external virtual view returns (address);

    function activeBidderToZone(address) external virtual view returns (address);

    function ownerToZone(address) external virtual view returns (address);

    function zoneImplementation() external virtual view returns (address);

    function tellerImplementation() external virtual view returns (address);

    function geo() external virtual view returns (address);

    function users() external virtual view returns (address);

    // function getActiveBidderZone(address _bidder) view external   returns(address);
    function transferOwnership(address newOwner) external virtual;

    function changeOwner(
        address _newOwner,
        address _oldOwner,
        address _zone
    ) external virtual;

    function zoneExists(bytes6 _geohash) external virtual view returns (bool);

    function proxyUpdateUserDailySold(
        bytes2 _countryCode,
        address _from,
        address _to,
        uint256 _amount
    ) external virtual;

    function emitAuctionCreated(
        bytes6 zoneFrom,
        address sender,
        uint256 auctionId,
        uint256 bidAmount
    ) external virtual;

    function emitAuctionEnded(
        bytes6 zoneFrom,
        address newOwner,
        uint256 auctionId,
        uint256 winningBid
    ) external virtual;

    function emitBid(
        bytes6 zoneFrom,
        address sender,
        uint256 auctionId,
        uint256 bidAmount
    ) external virtual;

    function emitClaimFreeZone(
        bytes6 zoneFrom,
        address newOwner,
        uint256 bidAmount
    ) external virtual;

    function emitReleaseZone(bytes6 zoneFrom, address sender) external virtual;

    function fillCurrentZoneBidder(address bidder) external virtual;

    function removeActiveBidder(address activeBidder) external virtual;

    function removeCurrentZoneBidders() external virtual;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external virtual;
}
