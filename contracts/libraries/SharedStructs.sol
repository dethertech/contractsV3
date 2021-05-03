pragma solidity ^0.8.1;
pragma experimental ABIEncoderV2;

library SharedStructs {
  struct Params_t {
        uint256 bidPeriod;             // Time during everyon can bid, when an auction is opened
        uint256 cooldownPeriod;        // Time when no auction can be opened after an auction end
        uint256 entryFee;              // Amount needed to be paid when starting an auction
        uint256 zoneTax;               // Amount of taxes raised
        uint256 minRaise;
  }
}