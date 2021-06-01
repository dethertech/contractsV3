// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "./IAnyswapV3ERC20.sol";

abstract contract IProtocolController {
    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------
    struct GlobalParams {
        uint256 bidPeriod; // Time during everyon can bid, when an auction is opened
        uint256 cooldownPeriod; // Time when no auction can be opened after an auction end
        uint256 entryFee; // Amount needed to be paid when starting an auction
        uint256 zoneTax; // Amount of taxes raised
        uint256 minRaise;
    }

    function dth() external view virtual returns (IAnyswapV3ERC20);

    // public getters
    function getGlobalParams()
        public
        view
        virtual
        returns (GlobalParams memory);

    function getCountryFloorPrice(bytes2 zoneCountry)
        public
        view
        virtual
        returns (uint256);

    // dao-initiated updates
    function updateGlobalParams(GlobalParams calldata newParams) public virtual;

    function updateCountryFloorPrice(
        bytes2 zoneCountry,
        uint256 floorStakePrice
    ) public virtual;

    function withdrawDth(
        address recipient,
        uint256 amount,
        string calldata id
    ) public virtual;

    // validation functions for dao proposals
    function validateCountryFloorPrice(
        bytes2 _countryCode,
        uint256 _floorStakePrice
    ) public view virtual;

    function validateGlobalParams(GlobalParams memory newParams)
        public
        view
        virtual;

    function validateWithdrawDth(address _recipient, uint256 _amount)
        public
        view
        virtual;
}
