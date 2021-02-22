pragma solidity ^0.7.6;

abstract contract IDetherToken {
    function mintingFinished() external virtual view returns (bool);

    function name() external virtual view returns (string memory);

    function approve(address _spender, uint256 _value) external virtual returns (bool);

    function totalSupply() external virtual view returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external virtual returns (bool);

    function decimals() external virtual view returns (uint8);

    function mint(address _to, uint256 _amount) external virtual returns (bool);

    function decreaseApproval(address _spender, uint256 _subtractedValue)
        external
        virtual
        returns (bool);

    function balanceOf(address _owner) external virtual view returns (uint256 balance);

    function finishMinting() external virtual returns (bool);

    function owner() external virtual view returns (address);

    function symbol() external virtual view returns (string memory);

    function transfer(address _to, uint256 _value) external virtual returns (bool);

    function transfer(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external virtual returns (bool);

    function increaseApproval(address _spender, uint256 _addedValue)
        external
        virtual
        returns (bool);

    function allowance(address _owner, address _spender)
        external
        virtual
        view
        returns (uint256);

    function transferOwnership(address newOwner) external virtual;
}
