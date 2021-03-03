pragma solidity ^0.8.1;

abstract contract IExchangeRateOracle {
    function WAD() external virtual view returns (uint256);

    function mkrPriceFeed() external virtual view returns (address);

    function getWeiPriceOneUsd() external virtual view returns (uint256);
}
