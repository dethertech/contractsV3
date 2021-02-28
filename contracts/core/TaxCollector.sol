pragma solidity ^0.8.1;

import "openzeppelin-solidity/contracts/access/Ownable.sol";

import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IDetherToken.sol";

contract TaxCollector is IERC223ReceivingContract, Ownable {
    // Address where collected taxes are sent to
    address public taxRecipient;
    bool public unchangeable;
    IDetherToken public dth;
    // Daily tax rate (there are no floats in solidity)
    event ReceivedTaxes(
        address indexed tokenFrom,
        uint256 taxes,
        address indexed from
    );

    constructor(address _dth, address _taxRecipient) {
        dth = IDetherToken(_dth);
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

    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data
    ) public override {
        emit ReceivedTaxes(msg.sender, _value, _from);
    }
}
