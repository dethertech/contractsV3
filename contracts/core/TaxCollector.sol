// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

// import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IAnyswapV3ERC20.sol";
import "../interfaces/ITransferReceiver.sol";

contract TaxCollector is ITransferReceiver, Ownable {
    // Address where collected taxes are sent to
    address public taxRecipient;
    bool public unchangeable;
    IAnyswapV3ERC20 public dth;
    // Daily tax rate (there are no floats in solidity)
    event ReceivedTaxes(
        address indexed tokenFrom,
        uint256 taxes,
        address indexed from
    );

    constructor(address _dth, address _taxRecipient) {
        dth = IAnyswapV3ERC20(_dth);
        taxRecipient = _taxRecipient;
    }

    function unchangeableRecipient() external onlyOwner {
        unchangeable = true;
    }

    function changeRecipient(address _newRecipient) external onlyOwner {
        require(!unchangeable, "Impossible to change the recipient");
        taxRecipient = _newRecipient;
    }

    function collect() public {
        uint256 balance = dth.balanceOf(address(this));
        dth.transfer(taxRecipient, balance);
    }

    function onTokenTransfer(
        address _from,
        uint256 _value,
        bytes memory
    ) public override returns (bool) {
        require(
            msg.sender == address(dth),
            "can only be called by dth contract"
        );
        emit ReceivedTaxes(msg.sender, _value, _from);
        return true;
    }
}
