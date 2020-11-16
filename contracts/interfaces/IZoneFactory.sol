pragma solidity ^0.5.17;

contract IZoneFactory {
    function dth() external view returns (address);

    function zoneToGeohash(address) external view returns (bytes6);

    function geohashToZone(bytes6) external view returns (address);

    function activeBidderToZone(address) external view returns (address);

    function ownerToZone(address) external view returns (address);

    function zoneImplementation() external view returns (address);

    function tellerImplementation() external view returns (address);

    function geo() external view returns (address);

    function users() external view returns (address);

    // function getActiveBidderZone(address _bidder) view external   returns(address);
    function transferOwnership(address newOwner) external;

    function changeOwner(
        address _newOwner,
        address _oldOwner,
        address _zone
    ) external;

    function zoneExists(bytes6 _geohash) external view returns (bool);

    function proxyUpdateUserDailySold(
        bytes2 _countryCode,
        address _from,
        address _to,
        uint256 _amount
    ) external;

    function emitAuctionCreated(
        bytes6 zoneFrom,
        address sender,
        uint256 auctionId,
        uint256 bidAmount
    ) external;

    function emitAuctionEnded(
        bytes6 zoneFrom,
        address newOwner,
        uint256 auctionId,
        uint256 winningBid
    ) external;

    function emitBid(
        bytes6 zoneFrom,
        address sender,
        uint256 auctionId,
        uint256 bidAmount
    ) external;

    function emitClaimFreeZone(
        bytes6 zoneFrom,
        address newOwner,
        uint256 bidAmount
    ) external;

    function emitReleaseZone(bytes6 zoneFrom, address sender) external;

    function fillCurrentZoneBidder(address bidder) external;

    function removeActiveBidder(address activeBidder) external;

    function removeCurrentZoneBidders() external;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external;
}
