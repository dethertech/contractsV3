// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract ICertifier {
    function certs(address) external virtual view returns (bool active);

    function delegate(address) external virtual view returns (bool active);

    function addDelegate(address _delegate) external virtual;

    function removeDelegate(address _delegate) external virtual;

    function certify(address _who) external virtual;

    function revoke(address _who) external virtual;

    function isDelegate(address _who) external virtual view returns (bool);

    function certified(address _who) external virtual view returns (bool);

    function get(address _who, string calldata _field)
        external
        virtual
        view
        returns (bytes32);
}
