pragma solidity ^0.7.6;

abstract contract IMedianizer {
    function peek()  external virtual view returns (bytes32, bool);
}
