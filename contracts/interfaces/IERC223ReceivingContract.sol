// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

/// @title Contract that supports the receival of ERC223 tokens.
abstract contract IERC223ReceivingContract {
    /// @dev Standard ERC223 function that will handle incoming token transfers.
    /// @param _from  Token sender address.
    /// @param _value Amount of tokens.
    /// @param _data  Transaction metadata.
    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public virtual;
}
