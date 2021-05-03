// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

library FeeTaxHelpers {
    function calcEntryFee(uint256 _value, uint256 _entryFee) public pure returns (
        uint256 burnAmount, 
        uint256 bidAmount
    ) {
        burnAmount = _value * _entryFee / 100; // 4%
        bidAmount = _value - burnAmount; // 96%
    }

    function calcHarbergerTax(
        uint256 _dthAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _zoneTax
    ) public pure returns (uint256 taxAmount) {
        // TODO use smaller uint variables, hereby preventing under/overflows, so no need for SafeMath
        // source: https://programtheblockchain.com/posts/2018/09/19/implementing-harberger-tax-deeds/
        return (_dthAmount
            * (_endTime - _startTime)
            * (_zoneTax)
            / (10000)
            / (1 days)
        );
    }
}