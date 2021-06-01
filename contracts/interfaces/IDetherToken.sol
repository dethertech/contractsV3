// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

abstract contract IDetherToken {
    function mintingFinished() external view virtual returns (bool);

    function name() external view virtual returns (string memory);

    function approve(address _spender, uint256 _value)
        external
        virtual
        returns (bool);

    function totalSupply() external view virtual returns (uint256);

    function transferFrom(
        address _from,
        address _to,
        uint256 _value
    ) external virtual returns (bool);

    function decimals() external view virtual returns (uint8);

    function mint(address _to, uint256 _amount) external virtual returns (bool);

    function decreaseApproval(address _spender, uint256 _subtractedValue)
        external
        virtual
        returns (bool);

    function balanceOf(address _owner)
        external
        view
        virtual
        returns (uint256 balance);

    function finishMinting() external virtual returns (bool);

    function owner() external view virtual returns (address);

    function symbol() external view virtual returns (string memory);

    function transfer(address _to, uint256 _value)
        external
        virtual
        returns (bool);

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
        view
        virtual
        returns (uint256);

    function transferOwnership(address newOwner) external virtual;
}
