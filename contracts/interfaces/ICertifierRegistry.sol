pragma solidity ^0.7.6;
pragma experimental ABIEncoderV2;

contract ICertifierRegistry {
    struct Certification {
        address certifier;
        int8 ref;
        uint256 timestamp;
    }

    function createCertifier(string calldata _url) external returns (address);

    function modifyUrl(address _certifierId, string calldata _newUrl) external;

    function addCertificationType(
        address _certifierId,
        int8 ref,
        string calldata description
    ) external;

    function addDelegate(address _certifierId, address _delegate) external;

    function removeDelegate(address _certifierId, address _delegate) external;

    function certify(
        address _certifierId,
        address _who,
        int8 _type
    ) external;

    function revoke(address _certifierId, address _who) external;

    function isDelegate(address _certifierId, address _who)
        external
        view
        returns (bool);

    function getCerts(address _who)
        external
        view
        returns (Certification[] memory);
}
