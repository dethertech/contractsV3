pragma solidity ^0.5.17;

contract ITaxCollector {
    function unchangeableRecipient() external;

    function changeRecipient() external;

    function collect() external;

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes calldata _data
    ) external;
}
