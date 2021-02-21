pragma solidity ^0.7.6;

abstract contract IUsers {
    function zoneFactoryAddress() external virtual view returns (address);

    function kycCertifier() external virtual view returns (address);

    function priceOracle() external virtual view returns (address);

    function smsCertifier() external virtual view returns (address);

    function getHour(uint256 timestamp) external virtual pure returns (uint8);

    function volumeSell(address) external virtual view returns (uint256);

    function nbTrade(address) external virtual view returns (uint256);

    function getWeekday(uint256 timestamp) external virtual pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute
    ) external virtual pure returns (uint256 timestamp);

    function getDay(uint256 timestamp) external virtual pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour
    ) external virtual pure returns (uint256 timestamp);

    function getSecond(uint256 timestamp) external virtual pure returns (uint8);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day
    ) external virtual pure returns (uint256 timestamp);

    function toTimestamp(
        uint16 year,
        uint8 month,
        uint8 day,
        uint8 hour,
        uint8 minute,
        uint8 second
    ) external virtual pure returns (uint256 timestamp);

    function getYear(uint256 timestamp) external virtual pure returns (uint16);

    function getMonth(uint256 timestamp) external virtual pure returns (uint8);

    function isLeapYear(uint16 year) external virtual pure returns (bool);

    function leapYearsBefore(uint256 year) external virtual pure returns (uint256);

    function getDaysInMonth(uint8 month, uint16 year)
        external
        virtual
        pure
        returns (uint8);

    function geo() external virtual view returns (address);

    function volumeBuy(address) external virtual view returns (uint256);

    function getMinute(uint256 timestamp) external virtual pure returns (uint8);

    function getDateInfo(uint256 timestamp)
        external
        virtual
        pure
        returns (
            uint16,
            uint16,
            uint16
        );
}
