pragma solidity ^0.7.6;

contract IExchangeRateOracle {
    function WAD() external view returns (uint256);

    function mkrPriceFeed() external view returns (address);

    function getWeiPriceOneUsd() external view returns (uint256);
}
