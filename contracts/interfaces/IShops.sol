// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract IShops {
    function dth() external virtual view returns (address);

    function withdrawableDth(address) external virtual view returns (uint256);

    function positionToShopAddress(bytes12) external virtual view returns (address);

    // function shopsDispute() external view returns (address);

    function zoneToShopAddresses(bytes7, uint256)
        external 
        virtual
        view
        returns (address);

    function geo() external virtual view returns (address);

    function users() external virtual view returns (address);

    function countryLicensePrice(bytes2) external virtual view returns (uint256);

    // function setShopsDisputeContract(address _shopsDispute) external virtual;

    function getShopByAddr(address _addr)
        external 
        virtual
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
        virtual
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
        virtual
        view
        returns (address[] memory);

    function shopByAddrExists(address _shopAddress)
        external 
        virtual
        view
        returns (bool);

    // function getShopDisputeID(address _shopAddress)
    //     external virtual
    //     view
    //     returns (uint256);

    // function hasDispute(address _shopAddress) external virtual view returns (bool);

    function getShopStaked(address _shopAddress)
        external 
        virtual
        view
        returns (uint256);

    function setCountryLicensePrice(bytes2 _countryCode, uint256 _priceDTH)
        external virtual;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external virtual;

    function removeShop() external virtual;

    function withdrawDth() external virtual;

    // function setDispute(address _shopAddress, uint256 _disputeID) external virtual;

    // function unsetDispute(address _shopAddress) external virtual;

    // function removeDisputedShop(address _shopAddress, address _challenger)
    //     external virtual;
}
