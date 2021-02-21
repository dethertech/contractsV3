pragma solidity ^0.7.6;

/// @title Contract that supports the receival of ERC223 tokens.
contract IERC223ReceivingContract {
    /// @dev Standard ERC223 function that will handle incoming token transfers.
    /// @param _from  Token sender address.
    /// @param _value Amount of tokens.
    /// @param _data  Transaction metadata.
    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public;
}
