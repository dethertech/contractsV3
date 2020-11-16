pragma solidity ^0.5.17;

contract IUsers {
    function zoneFactoryAddress() external view returns (address);

    function kycCertifier() external view returns (address);

    function priceOracle() external view returns (address);

    function smsCertifier() external view returns (address);

    function getHour(uint256 timestamp) external pure returns (uint8);

    function volumeSell(address) external view returns (uint256);

    function nbTrade(address) external view returns (uint256);

    function getWeekday(uint256 timestamp) external pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute
    ) external pure returns (uint256 timestamp);

    function getDay(uint256 timestamp) external pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour
    ) external pure returns (uint256 timestamp);

    function getSecond(uint256 timestamp) external pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day
    ) external pure returns (uint256 timestamp);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute,
        uint8 second
    ) external pure returns (uint256 timestamp);

    function getYear(uint256 timestamp) external pure returns (uint16);

    function getMonth(uint256 timestamp) external pure returns (uint8);

    function isLeapYear(uint16 year) external pure returns (bool);

    function leapYearsBefore(uint256 year) external pure returns (uint256);

    function getDaysInMonth(uint8 month, uint16 year)
        external
        pure
        returns (uint8);

    function geo() external view returns (address);

    function volumeBuy(address) external view returns (uint256);

    function getMinute(uint256 timestamp) external pure returns (uint8);

    function getDateInfo(uint256 timestamp)
        external
        pure
        returns (
            uint16,
            uint16,
            uint16
        );
}
