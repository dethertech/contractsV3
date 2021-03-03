pragma solidity ^0.8.1;

abstract contract IMedianizer {
    function peek()  external virtual view returns (bytes32, bool);
}
