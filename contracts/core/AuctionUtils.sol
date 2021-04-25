// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "./FeeTaxHelpers.sol";
import "../interfaces/IDetherToken.sol";
import "../interfaces/IZoneFactory.sol";
import "../interfaces/IProtocolController.sol";
import "./ProtocolController.sol";

library AuctionUtils {
    using FeeTaxHelpers for uint256;

    enum AuctionState {Started, Ended}
    struct Auction {
        uint256 state;
        uint256 startTime;
        uint256 endTime;
        address highestBidder;
    }

    struct AuctionDetails {
        mapping(uint256 => Auction) auctionIdToAuction;
        mapping(uint256 => mapping(address => uint256)) auctionBids;
        uint256 currentAuctionId; // starts at 0, first auction will get id 1, etc.
    }

    /// @notice get a specific auction
    function getAuction(
        AuctionDetails storage _auctionDetailsPtr,
        uint256 _auctionId,
        address _zoneOwner,
        uint256 _staked
    ) external view returns (
        Auction memory auction,
        uint256 highestBid
    ) {
        require(
            _auctionId > 0 && _auctionId <= _auctionDetailsPtr.currentAuctionId,
            "auction does not exist"
        );

        auction = _auctionDetailsPtr.auctionIdToAuction[_auctionId];

        highestBid = _auctionDetailsPtr.auctionBids[_auctionId][auction.highestBidder];

        // If auction is ongoing, for current zone owner his existing zone stake is added to his bid
        if (
            auction.state == uint256(AuctionState.Started) &&
            auction.highestBidder == _zoneOwner
        ) {
            highestBid = highestBid + _staked;
        }
    }

    function createAuction(
        AuctionDetails storage _auctionDetailsPtr,
        address _sender,
        uint256 _dthAmount,
        bytes6 _geohash,
        address _ownerAddress,
        uint256 _staked,
        IProtocolController _protocolController,
        IProtocolController.Params_t memory _params,
        IZoneFactory zoneFactory
    ) external {
        require(
            zoneFactory.activeBidderToZone(_sender) == address(0),
            "sender is currently involved in an auction (Zone)"
        );
        require(
            zoneFactory.ownerToZone(_sender) == address(0),
            "sender own already a zone"
        );

        (uint256 burnAmount, uint256 bidAmount) = _dthAmount.calcEntryFee(_params.entryFee);
        require(
            bidAmount >
            _staked + _staked * _params.minRaise / 100,
            "bid is lower than current zone stake"
        );

        _auctionDetailsPtr.currentAuctionId++;
        _auctionDetailsPtr.auctionIdToAuction[_auctionDetailsPtr.currentAuctionId] = Auction({
            state: uint256(AuctionState.Started),
            startTime: block.timestamp,
            endTime: block.timestamp + _params.bidPeriod,
            highestBidder: _sender // caller (challenger)
        });
        _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] = bidAmount;

        require(_protocolController.dth().transfer(address(_protocolController), burnAmount));

        zoneFactory.fillCurrentZoneBidder(_sender);
        zoneFactory.fillCurrentZoneBidder(_ownerAddress);
        zoneFactory.emitAuctionCreated(
            _geohash,
            _sender,
            _auctionDetailsPtr.currentAuctionId,
            _dthAmount
        );
    }

    function endAuction(AuctionDetails storage _auctionDetailsPtr) external returns (uint256 auctionPtr, uint256 highestBid) {
        Auction storage lastAuction = _auctionDetailsPtr.auctionIdToAuction[_auctionDetailsPtr.currentAuctionId];
        highestBid = _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][lastAuction.highestBidder];
        lastAuction.state = uint256(AuctionState.Ended);
        assembly { auctionPtr := lastAuction.slot }
    }

    function joinAuction(
        AuctionDetails storage _auctionDetailsPtr,
        address _sender,
        uint256 _dthAmount,
        bytes6 _geohash,
        address _ownerAddress,
        uint256 _staked,
        IProtocolController _protocolController,
        IProtocolController.Params_t memory _params,
        IZoneFactory _zoneFactory
    ) external {
        require(
            _zoneFactory.activeBidderToZone(_sender) == address(this) ||
                _zoneFactory.activeBidderToZone(_sender) == address(0),
            "sender is currently involved in another auction"
        );
        require(
            _zoneFactory.ownerToZone(_sender) == address(0) ||
                _zoneFactory.ownerToZone(_sender) == address(this),
            "sender own already another zone"
        );

        // AuctionDetails storage auctionsPtr;
        // assembly { auctionsPtr.slot := _auctionDetailsPtr }
        Auction storage lastAuction = _auctionDetailsPtr.auctionIdToAuction[_auctionDetailsPtr.currentAuctionId];

        uint256 currentHighestBid = _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][lastAuction.highestBidder];

        if (_sender == _ownerAddress) {
            uint256 dthAddedBidsAmount = _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] + _dthAmount;
            // the current zone owner's stake also counts in his bid
            require(
                _staked + dthAddedBidsAmount >=
                currentHighestBid + currentHighestBid * _params.minRaise / 100,
                "bid + already staked is less than current highest + minRaise"
            );

            _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] = dthAddedBidsAmount;
        } else {
            // _sender is not the current zone owner
            if (_auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] == 0) {
                // this is the first bid of this challenger, deduct entry fee
                (uint256 burnAmount, uint256 bidAmount) = _dthAmount.calcEntryFee(_params.entryFee);

                require(
                    bidAmount >=
                    currentHighestBid + currentHighestBid * _params.minRaise / 100,
                    "bid is less than current highest + minRaise"
                );

                _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] = bidAmount;
                require(_protocolController.dth().transfer(address(_protocolController), burnAmount));
            } else {
                // not the first bid, no entry fee
                uint256 newUserTotalBid = _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] + _dthAmount;
                require(
                    newUserTotalBid >=
                    currentHighestBid + currentHighestBid * _params.minRaise / 100,
                    "bid is less than current highest + minRaise"
                );

                _auctionDetailsPtr.auctionBids[_auctionDetailsPtr.currentAuctionId][_sender] = newUserTotalBid;
            }
        }

        // it worked, _sender placed a bid
        lastAuction.highestBidder = _sender;

        _zoneFactory.fillCurrentZoneBidder(_sender);
        _zoneFactory.emitBid(_geohash, _sender, _auctionDetailsPtr.currentAuctionId, _dthAmount);
    }

    /// @notice withdraw losing bids from a specific auction
    /// @param _auctionId The auction id
    function withdrawFromAuction(
        AuctionDetails storage _auctionDetailsPtr,
        uint256 _auctionId,
        IDetherToken _dth,
        mapping(address => uint256) storage _withdrawableDth,
        IZoneFactory _zoneFactory
    ) external {
        // even when country is disabled, otherwise users cannot withdraw their bids
        require(
            _auctionId > 0 && _auctionId <= _auctionDetailsPtr.currentAuctionId,
            "auctionId does not exist"
        );

        require(
            _auctionDetailsPtr.auctionIdToAuction[_auctionId].state == uint256(AuctionUtils.AuctionState.Ended),
            "cannot withdraw while auction is active"
        );
        require(
            _auctionDetailsPtr.auctionIdToAuction[_auctionId].highestBidder != msg.sender,
            "auction winner can not withdraw"
        );
        require(_auctionDetailsPtr.auctionBids[_auctionId][msg.sender] > 0, "nothing to withdraw");

        uint256 withdrawAmount = _auctionDetailsPtr.auctionBids[_auctionId][msg.sender];
        _auctionDetailsPtr.auctionBids[_auctionId][msg.sender] = 0;
        if (_withdrawableDth[msg.sender] > 0) {
            withdrawAmount = withdrawAmount + _withdrawableDth[msg.sender];
            _withdrawableDth[msg.sender] = 0;
        }
        _zoneFactory.removeActiveBidder(msg.sender);
        require(_dth.transfer(msg.sender, withdrawAmount));
    }

    /// @notice withdraw from a given list of auction ids
    function withdrawFromAuctions(
        AuctionDetails storage _auctionDetailsPtr,
        uint256[] calldata _auctionIds,
        IDetherToken _dth,
        mapping(address => uint256) storage _withdrawableDth,
        IZoneFactory _zoneFactory
    ) external {
        // even when country is disabled, can withdraw
        require(_auctionDetailsPtr.currentAuctionId > 0, "there are no auctions");

        require(_auctionIds.length > 0, "auctionIds list is empty");
        require(
            _auctionIds.length <= _auctionDetailsPtr.currentAuctionId,
            "auctionIds list is longer than allowed"
        );

        uint256 withdrawAmountTotal = 0;

        for (uint256 idx = 0; idx < _auctionIds.length; idx++) {
            uint256 auctionId = _auctionIds[idx];
            require(
                auctionId > 0 && auctionId <= _auctionDetailsPtr.currentAuctionId,
                "auctionId does not exist"
            );
            require(
                _auctionDetailsPtr.auctionIdToAuction[auctionId].state == uint256(AuctionUtils.AuctionState.Ended),
                "cannot withdraw from running auction"
            );
            require(
                _auctionDetailsPtr.auctionIdToAuction[auctionId].highestBidder != msg.sender,
                "auction winner can not withdraw"
            );
            uint256 withdrawAmount = _auctionDetailsPtr.auctionBids[auctionId][msg.sender];
            if (withdrawAmount > 0) {
                // if user supplies the same auctionId multiple times in auctionIds,
                // only the first one will get a withdrawal amount
                _auctionDetailsPtr.auctionBids[auctionId][msg.sender] = 0;
                withdrawAmountTotal = withdrawAmountTotal + withdrawAmount;
            }
        }
        if (_withdrawableDth[msg.sender] > 0) {
            withdrawAmountTotal = withdrawAmountTotal + _withdrawableDth[msg.sender];
            _withdrawableDth[msg.sender] = 0;
        }
        _zoneFactory.removeActiveBidder(msg.sender);

        require(withdrawAmountTotal > 0, "nothing to withdraw");

        require(_dth.transfer(msg.sender, withdrawAmountTotal));
    }
}