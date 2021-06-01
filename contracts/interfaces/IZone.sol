// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract IZone {
    function dth() public view virtual returns (address);

    function geohash() public view virtual returns (bytes6);

    function currentAuctionId() public view virtual returns (uint256);

    function auctionBids(uint256, address)
        public
        view
        virtual
        returns (uint256);

    function withdrawableDth(address) public view virtual returns (uint256);

    function teller() public view virtual returns (address);

    function zoneFactory() public view virtual returns (address);

    function MIN_STAKE() public view virtual returns (uint256);

    function country() public view virtual returns (bytes2);

    function geo() public view virtual returns (address);

    function withdrawableEth(address) public view virtual returns (uint256);

    function init(
        bytes2 _countryCode,
        bytes6 _geohash,
        address _zoneOwner,
        uint256 _dthAmount,
        address _dth,
        address _zoneFactory,
        address _teller,
        address _protocolController
    ) external virtual;

    function connectToTellerContract(address _teller) external virtual;

    function ownerAddr() external view virtual returns (address);

    function computeCSC(bytes6 _geohash, address _addr)
        external
        pure
        virtual
        returns (bytes12);

    function calcHarbergerTax(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _dthAmount
    ) public view virtual returns (uint256 taxAmount, uint256 keepAmount);

    function calcEntryFee(uint256 _value)
        external
        view
        virtual
        returns (uint256 burnAmount, uint256 bidAmount);

    function auctionExists(uint256 _auctionId)
        external
        view
        virtual
        returns (bool);

    function zoneOwner()
        external
        view
        virtual
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
        virtual
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
        virtual
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        );

    function processState() external virtual;

    // function onTokenTransfer(
    //     address _from,
    //     uint256 _value,
    //     bytes memory _data
    // ) public virtual;

    function release() external virtual;

    function withdrawFromAuction(uint256 _auctionId) external virtual;

    function withdrawFromAuctions(uint256[] calldata _auctionIds)
        external
        virtual;

    function withdrawDth() external virtual;

    function proxyUpdateUserDailySold(address _to, uint256 _amount)
        external
        virtual;
}
