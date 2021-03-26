// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "./IDetherToken.sol";

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

    function getGlobalParams () public virtual view returns(Params_t memory);

    function getCountryFloorPrice (bytes2 zoneCountry) public virtual view returns (uint256);
}
