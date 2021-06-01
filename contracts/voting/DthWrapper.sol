pragma solidity ^0.8.1;

import "../interfaces/IAnyswapV3ERC20.sol";
import "../interfaces/ITransferReceiver.sol";
import "../interfaces/IERC223ReceivingContract.sol";
import "./CheckpointingLib.sol";

// contract DthWrapper is IERC223ReceivingContract {

contract DthWrapper is ITransferReceiver {
    using Checkpointing for Checkpointing.History;

    IAnyswapV3ERC20 public dthToken;

    mapping(address => Checkpointing.History) internal balancesHistory;
    Checkpointing.History internal totalSupplyHistory;

    event Deposit(address indexed entity, uint256 amount);
    event Withdrawal(address indexed entity, uint256 amount);

    constructor(address _dthToken) {
        require(_dthToken != address(0), "_dthToken is address(0))");
        dthToken = IAnyswapV3ERC20(_dthToken);
    }

    //
    // [ deposit ]
    //
    function _deposit(address _from, uint256 _amount) internal {
        uint192 newBalance = uint192(balanceOf(_from) + _amount);
        uint192 newTotalSupply = uint192(totalSupply() + _amount);
        uint64 currentBlock = uint64(block.number);

        balancesHistory[_from].addCheckpoint(currentBlock, newBalance);
        totalSupplyHistory.addCheckpoint(currentBlock, newTotalSupply);

        emit Deposit(_from, _amount);
    }

    function deposit(uint256 _amount) external {
        require(_amount > 0, "amount is zero");

        dthToken.transferFrom(msg.sender, address(this), _amount);

        _deposit(msg.sender, _amount);
    }

    function onTokenTransfer(
        address _from,
        uint256 _value,
        bytes memory
    ) public override returns (bool) {
        require(_value > 0, "onTokenTransfer value is zero");
        require(
            msg.sender == address(dthToken),
            "can only be called by dth contract"
        );
        _deposit(_from, _value);
        return (true);
    }

    //
    // [ withdraw ]
    //
    function withdraw(uint256 _amount) external {
        require(_amount > 0, "amount is zero");

        uint192 newBalance = uint192(balanceOf(msg.sender) - _amount);
        uint192 newTotalSupply = uint192(totalSupply() - _amount);
        uint64 currentBlock = uint64(block.number);

        balancesHistory[msg.sender].addCheckpoint(currentBlock, newBalance);
        totalSupplyHistory.addCheckpoint(currentBlock, newTotalSupply);

        dthToken.transfer(msg.sender, _amount);

        emit Withdrawal(msg.sender, _amount);
    }

    //
    // [ balanceOf ]
    //
    function balanceOf(address _owner) public view returns (uint256) {
        return _balanceOfAt(_owner, block.number);
    }

    function balanceOfAt(address _owner, uint256 _blockNumber)
        public
        view
        returns (uint256)
    {
        return _balanceOfAt(_owner, _blockNumber);
    }

    function _balanceOfAt(address _owner, uint256 _blockNumber)
        internal
        view
        returns (uint256)
    {
        return balancesHistory[_owner].getValueAt(uint64(_blockNumber));
    }

    //
    // [ totalSupply ]
    //
    function totalSupply() public view returns (uint256) {
        return _totalSupplyAt(block.number);
    }

    function totalSupplyAt(uint256 _blockNumber) public view returns (uint256) {
        return _totalSupplyAt(_blockNumber);
    }

    function _totalSupplyAt(uint256 _blockNumber)
        internal
        view
        returns (uint256)
    {
        return totalSupplyHistory.getValueAt(uint64(_blockNumber));
    }
}
