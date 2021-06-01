// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

interface ITransferReceiver {
    function onTokenTransfer(
        address,
        uint256,
        bytes calldata
    ) external returns (bool);
}
