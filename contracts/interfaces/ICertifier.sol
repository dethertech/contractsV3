pragma solidity ^0.5.17;

contract ICertifier {
    function certs(address) external view returns (bool active);

    function delegate(address) external view returns (bool active);

    function addDelegate(address _delegate) external;

    function removeDelegate(address _delegate) external;

    function certify(address _who) external;

    function revoke(address _who) external;

    function isDelegate(address _who) external view returns (bool);

    function certified(address _who) external view returns (bool);

    function get(address _who, string calldata _field)
        external
        view
        returns (bytes32);
}
