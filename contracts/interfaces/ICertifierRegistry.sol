// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;
pragma experimental ABIEncoderV2;

abstract contract ICertifierRegistry {
    struct Certification {
        address certifier;
        int8 ref;
        uint256 timestamp;
    }

    function createCertifier(string calldata _url) external virtual returns (address);

    function modifyUrl(address _certifierId, string calldata _newUrl) external virtual;

    function addCertificationType(
        address _certifierId,
        int8 ref,
        string calldata description
    ) external virtual;

    function addDelegate(address _certifierId, address _delegate) external virtual;

    function removeDelegate(address _certifierId, address _delegate) external virtual;

    function certify(
        address _certifierId,
        address _who,
        int8 _type
    ) external virtual;

    function revoke(address _certifierId, address _who) external virtual;

    function isDelegate(address _certifierId, address _who)
        external
        virtual
        view
        returns (bool);

    function getCerts(address _who)
        external
        virtual
        view
        returns (Certification[] memory);
}
