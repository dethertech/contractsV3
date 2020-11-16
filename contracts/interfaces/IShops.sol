pragma solidity ^0.5.17;

contract IShops {
    function dth() external view returns (address);

    function withdrawableDth(address) external view returns (uint256);

    function positionToShopAddress(bytes12) external view returns (address);

    // function shopsDispute() external view returns (address);

    function zoneToShopAddresses(bytes7, uint256)
        external
        view
        returns (address);

    function geo() external view returns (address);

    function users() external view returns (address);

    function countryLicensePrice(bytes2) external view returns (uint256);

    // function setShopsDisputeContract(address _shopsDispute) external;

    function getShopByAddr(address _addr)
        external
        view
        returns (
            bytes12,
            bytes16,
            bytes16,
            bytes32,
            bytes16,
            uint256,
            bool,
            uint256
        );

    function getShopByPos(bytes12 _position)
        external
        view
        returns (
            bytes12,
            bytes16,
            bytes16,
            bytes32,
            bytes16,
            uint256,
            bool,
            uint256
        );

    function getShopAddressesInZone(bytes7 _zoneGeohash)
        external
        view
        returns (address[] memory);

    function shopByAddrExists(address _shopAddress)
        external
        view
        returns (bool);

    // function getShopDisputeID(address _shopAddress)
    //     external
    //     view
    //     returns (uint256);

    // function hasDispute(address _shopAddress) external view returns (bool);

    function getShopStaked(address _shopAddress)
        external
        view
        returns (uint256);

    function setCountryLicensePrice(bytes2 _countryCode, uint256 _priceDTH)
        external;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external;

    function removeShop() external;

    function withdrawDth() external;

    // function setDispute(address _shopAddress, uint256 _disputeID) external;

    // function unsetDispute(address _shopAddress) external;

    // function removeDisputedShop(address _shopAddress, address _challenger)
    //     external;
}
