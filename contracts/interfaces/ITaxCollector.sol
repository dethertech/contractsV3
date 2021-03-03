pragma solidity ^0.8.1;

abstract contract ITaxCollector {
    function unchangeableRecipient() external virtual;

    function changeRecipient() external virtual;

    function collect() external virtual;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external virtual;
}
