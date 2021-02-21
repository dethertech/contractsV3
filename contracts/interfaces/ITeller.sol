pragma solidity ^0.7.6;

contract ITeller {
    function funds() external view returns (uint256);

    function geo() external view returns (address);

    function withdrawableEth(address) external view returns (uint256);

    function canPlaceCertifiedComment(address, address)
        external
        view
        returns (uint256);

    function zone() external view returns (address);

    function init(address _geo, address _zone) external;

    function getComments() external view returns (bytes32[] memory);

    function calcReferrerFee(uint256 _value)
        external
        view
        returns (uint256 referrerAmount);

    function getTeller()
        external
        view
        returns (
            address,
            uint8,
            bytes16,
            bytes12,
            bytes1,
            int16,
            int16,
            uint256,
            address
        );

    function getReferrer() external view returns (address, uint256);

    function hasTeller() external view returns (bool);

    function removeTellerByZone() external;

    function removeTeller() external;

    function addTeller(
        bytes calldata _position,
        uint8 _currencyId,
        bytes16 _messenger,
        int16 _sellRate,
        int16 _buyRate,
        bytes1 _settings,
        address _referrer,
        bytes32 _description
    ) external;

    function addComment(bytes32 _commentHash) external;
}
