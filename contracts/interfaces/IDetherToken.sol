pragma solidity ^0.5.17;

contract IDetherToken {
    function mintingFinished() external view returns (bool);

    function name() external view returns (string memory);

    function approve(address _spender, uint256 _value) external returns (bool);

    function totalSupply() external view returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external returns (bool);

    function decimals() external view returns (uint8);

    function mint(address _to, uint256 _amount) external returns (bool);

    function decreaseApproval(address _spender, uint256 _subtractedValue)
        external
        returns (bool);

    function balanceOf(address _owner) external view returns (uint256 balance);

    function finishMinting() external returns (bool);

    function owner() external view returns (address);

    function symbol() external view returns (string memory);

    function transfer(address _to, uint256 _value) external returns (bool);

    function transfer(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (bool);

    function increaseApproval(address _spender, uint256 _addedValue)
        external
        returns (bool);

    function allowance(address _owner, address _spender)
        external
        view
        returns (uint256);

    function transferOwnership(address newOwner) external;
}
