// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract IMedianizer {
    function peek()  external virtual view returns (bytes32, bool);
}
