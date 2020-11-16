pragma solidity ^0.5.17;

contract IGeoRegistry {
    function zoneIsEnabled(bytes2) external view returns (bool);

    function enabledZone(uint256) external view returns (bytes2);

    function level_2(bytes2, bytes3) external view returns (bytes4);

    function validGeohashChars(bytes calldata _bytes) external returns (bool);

    function validGeohashChars12(bytes12 _bytes) external returns (bool);

    function zoneInsideBiggerZone(bytes2 _countryCode, bytes4 _zone)
        external
        view
        returns (bool);

    function updateLevel2(
        bytes2 _countryCode,
        bytes3 _letter,
        bytes4 _subLetters
    ) external;

    function updateLevel2batch(
        bytes2 _countryCode,
        bytes3[] calldata _letters,
        bytes4[] calldata _subLetters
    ) external;

    function endInit(bytes2 _countryCode) external;
}
