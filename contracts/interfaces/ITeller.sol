pragma solidity ^0.7.6;

abstract contract ITeller {
    function funds() external virtual view returns (uint256);

    function geo() external virtual view returns (address);

    function withdrawableEth(address) external virtual view returns (uint256);

    function canPlaceCertifiedComment(address, address)
        external 
        virtual
        view
        returns (uint256);

    function zone() external virtual view returns (address);

    function init(address _geo, address _zone) external virtual;

    function getComments() external virtual view returns (bytes32[] memory);

    function calcReferrerFee(uint256 _value)
        external virtual
        view
        returns (uint256 referrerAmount);

    function getTeller()
        external 
        virtual
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

    function getReferrer() external virtual view returns (address, uint256);

    function hasTeller() external virtual view returns (bool);

    function removeTellerByZone() external virtual;

    function removeTeller() external virtual;

    function addTeller(
        bytes calldata _position,
        uint8 _currencyId,
        bytes16 _messenger,
        int16 _sellRate,
        int16 _buyRate,
        bytes1 _settings,
        address _referrer,
        bytes32 _description
    ) external virtual;

    function addComment(bytes32 _commentHash) external virtual;
}
