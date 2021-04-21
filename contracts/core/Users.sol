// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;

import "../interfaces/ICertifier.sol";
import "../interfaces/IGeoRegistry.sol";
import "../interfaces/ICertifierRegistry.sol";

contract Users {

    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------

    IGeoRegistry public geo;
    ICertifierRegistry public certifierRegistry;

    address public zoneFactoryAddress;
    bool public isInit = false;

    // ------------------------------------------------
    //
    // Constructor
    //
    // ------------------------------------------------

    constructor(address _geo, address _certifierRegistry) {
        geo = IGeoRegistry(_geo);
        certifierRegistry = ICertifierRegistry(_certifierRegistry);
    }

    // ------------------------------------------------
    //
    // Functions Setters
    //
    // ------------------------------------------------

    function setZoneFactory(address _zoneFactory) external {
        require(isInit == false, "cannot be called more than once");
        zoneFactoryAddress = _zoneFactory;
        isInit = true;
    }

    // ------------------------------------------------
    //
    // Functions Getters
    //
    // ------------------------------------------------

    function getCertifications(address _who)
        external
        view
        returns (ICertifierRegistry.Certification[] memory)
    {
        return certifierRegistry.getCerts(_who);
    }
}
