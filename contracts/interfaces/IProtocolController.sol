// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "./IDetherToken.sol";

import "../libraries/SharedStructs.sol";

abstract contract IProtocolController {
    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------
    struct Params_t {
        uint256 BID_PERIOD;             // Time during everyon can bid, when an auction is opened
        uint256 COOLDOWN_PERIOD;        // Time when no auction can be opened after an auction end
        uint256 ENTRY_FEE;              // Amount needed to be paid when starting an auction
        uint256 ZONE_TAX;               // Amount of taxes raised
        uint256 MIN_RAISE;
    }

    function dth() external virtual view returns (IDetherToken);

    // public getters
    function getGlobalParams() public virtual view returns(SharedStructs.Params_t memory);
    function getCountryFloorPrice(bytes2 zoneCountry) public virtual view returns (uint256);

    // dao-initiated updates
    function updateGlobalParams(SharedStructs.Params_t calldata newParams) public virtual;
    function updateCountryFloorPrice(bytes2 zoneCountry, uint256 FLOOR_STAKE_PRICE) public virtual;
    function withdrawDth(address recipient, uint256 amount, string calldata id) public virtual;

    // validation functions for dao proposals
    function validateCountryFloorPrice(bytes2 _countryCode, uint256 _floorStakePrice) public view virtual;
    function validateGlobalParams(SharedStructs.Params_t memory newParams) public view virtual;
    function validateWithdrawDth(address _recipient, uint256 _amount) public view virtual;
}
