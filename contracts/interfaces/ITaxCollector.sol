// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract ITaxCollector {
    function unchangeableRecipient() external virtual;

    function changeRecipient() external virtual;

    function collect() external virtual;

    // function onTokenTransfer(
    //     address _from,
    //     uint256 _value,
    //     bytes calldata _data
    // ) external virtual;
}
