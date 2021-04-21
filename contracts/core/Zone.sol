// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IDetherToken.sol";
import "../interfaces/IZoneFactory.sol";
import "../interfaces/IZone.sol";
import "../interfaces/ITeller.sol";
import "../interfaces/IProtocolController.sol";
import "./AuctionUtils.sol";
import "./FeeTaxHelpers.sol";
import "./ZoneOwnerUtils.sol";

contract Zone is IERC223ReceivingContract {

    using ZoneOwnerUtils for uint256;
    using AuctionUtils for AuctionUtils.AuctionDetails;
    using FeeTaxHelpers for uint256;

    AuctionUtils.AuctionDetails auctions;
    
    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------

    uint256 public FLOOR_STAKE_PRICE; // DTH, which is also 18 decimals!

    IProtocolController.Params_t public zoneParams;
    IZoneFactory public zoneFactory;
    ITeller public teller;
    ZoneOwnerUtils.ZoneOwner public zoneOwner;
    IProtocolController public protocolController;

    bytes2 public country;
    bytes6 public geohash;

    mapping(address => uint256) public withdrawableDth;

    // ------------------------------------------------
    //
    // Modifiers
    //
    // ------------------------------------------------

    modifier updateState {
        processState();
        _;
    }

    modifier onlyWhenZoneHasOwner {
        require(zoneOwner.addr != address(0), "zone has no owner");
        _;
    }

    modifier onlyWhenCallerIsZoneOwner {
        require(msg.sender == zoneOwner.addr, "caller is not zoneowner");
        _;
    }

    modifier onlyWhenZoneHasNoOwner {
        require(zoneOwner.addr == address(0), "can not claim zone with owner");
        _;
    }

    // ------------------------------------------------
    //
    // Constructor
    //
    // ------------------------------------------------

    // executed by ZoneFactory.sol when this Zone does not yet exist (= not yet deployed)
    function init(
        bytes2 _countryCode,
        bytes6 _geohash,
        address _zoneOwner,
        uint256 _dthAmount,
        address /* _dth */,
        address _zoneFactory,
        address _teller,
        address _protocolController
    ) external {
        require(address(teller) == address(0), "contract already initialized");
        protocolController = IProtocolController(_protocolController);
        require(
            _dthAmount >= protocolController.getCountryFloorPrice(_countryCode),
            "DTH staked are not enough for this zone"
        );

        country = _countryCode;
        geohash = _geohash;

        zoneFactory = IZoneFactory(_zoneFactory);

        uint256 zoneOwnerPtr;
        assembly { zoneOwnerPtr := zoneOwner.slot }
        zoneOwnerPtr.init(_zoneOwner, block.timestamp, _dthAmount, 0);

        auctions.currentAuctionId = 0;
        teller = ITeller(_teller);

        _setParams();
    }

    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------


    function getZoneOwner() public view returns (
        address addr,
        uint256 startTime,
        uint256 staked,
        uint256 balance,
        uint256 lastTaxTime,
        uint256 auctionId
    ) {
        return (
            zoneOwner.addr, 
            zoneOwner.startTime, 
            zoneOwner.staked, 
            zoneOwner.balance, 
            zoneOwner.lastTaxTime, 
            zoneOwner.auctionId
        );
    }
    function ownerAddr() external view returns (address) {
        return zoneOwner.addr;
    }

    function getAuction(uint256 _auctionId) public view returns (AuctionUtils.Auction memory auction, uint256 highestBid) {
        return auctions.getAuction(_auctionId, zoneOwner.addr, zoneOwner.staked);
    }

    function auctionExists(uint256 _auctionId) external view returns (bool) {
        // if aucton does not exist we should get back zero, otherwise this field
        // will contain a block.timestamp, set whe creating an Auction, in constructor() and bid()
        return auctions.auctionIdToAuction[_auctionId].startTime > 0;
    }

    function currentAuctionId() public view returns (uint256) {
        return auctions.currentAuctionId;
    }

    function auctionBids(uint256 _auctionId, address _user) public view returns (uint256) {
        return auctions.auctionBids[_auctionId][_user];
    }

    /// @notice get the last auction
    function getLastAuction()
        external
        view
        returns (
            uint256 auctionId,
            uint256 state,
            uint256 startTime,
            uint256 endTime,
            address highestBidder,
            uint256 highestBid
        )
    {
        auctionId = auctions.currentAuctionId;
        AuctionUtils.Auction memory auction;
        (auction, highestBid) = auctions.getAuction(auctionId, zoneOwner.addr, zoneOwner.staked);
        state = auction.state;
        startTime = auction.startTime;
        endTime = auction.endTime;
        highestBidder = auction.highestBidder;
    }

    function _setParams(
    ) private {
        zoneParams = protocolController.getGlobalParams();
        FLOOR_STAKE_PRICE = protocolController.getCountryFloorPrice(country);
    }

    function _removeZoneOwner(bool fromRelease) private {
        // if we call this function from release() we shouldn't update withdrawableDth as we already send dth
        if (!fromRelease) {
            withdrawableDth[zoneOwner.addr] = withdrawableDth[zoneOwner.addr] + (zoneOwner.balance);
        }

        if (teller.hasTeller()) {
            teller.removeTellerByZone();
        }
        zoneFactory.changeOwner(address(0), zoneOwner.addr, address(0));
        delete zoneOwner;
    }

    /*
     * calculate harberger taxes and send dth to taxCollector and referrer (if exist)
     */
    function _handleTaxPayment() private {
        // processState ensured that: no running auction + there is a zone owner

        if (zoneOwner.lastTaxTime >= block.timestamp) {
            return; // short-circuit: multiple txes in 1 block OR many blocks but in same Auction
        }

        uint256 taxAmount = zoneOwner.staked.calcHarbergerTax(
            zoneOwner.lastTaxTime,
            block.timestamp,
            zoneParams.ZONE_TAX
        );

        if (taxAmount > zoneOwner.balance) {
            // zone owner does not have enough balance, remove him as zone owner
            uint256 oldZoneOwnerBalance = zoneOwner.balance;
            _removeZoneOwner(false);

            require(protocolController.dth().transfer(address(protocolController), oldZoneOwnerBalance));
        } else {
            // zone owner can pay due taxes
            uint256 zoneOwnerPtr;
            assembly { zoneOwnerPtr := zoneOwner.slot }
            zoneOwnerPtr.payTax(taxAmount);
            (address referrer, uint256 refFee) = teller.getReferrer();
            if (referrer != address(0x00) && refFee > 0) {
                uint256 referralFee = taxAmount * refFee / 1000;

                // to avoid Dos with revert if referrer is contract
                bytes memory payload = abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    referrer,
                    referralFee
                );
                address(protocolController.dth()).call(payload);

                // require(dth.transfer(referrer, referralFee));
                require(protocolController.dth().transfer(address(protocolController), taxAmount - referralFee));
            } else {
                require(protocolController.dth().transfer(address(protocolController), taxAmount));
            }
        }
    }

    /*
     * Called when auction is ended by processState()
     * update the state with new owner and new bid
     */
    function _endAuction() private {
        (uint256 lastAuctionPtr, uint256 highestBid) = auctions.endAuction();
        AuctionUtils.Auction storage lastAuction;
        assembly { lastAuction.slot := lastAuctionPtr }

        uint256 zoneOwnerPtr;
        assembly { zoneOwnerPtr := zoneOwner.slot }

        if (zoneOwner.addr == lastAuction.highestBidder) {
            zoneOwnerPtr.extendZoneOwnership(highestBid, auctions.currentAuctionId);
        } else {
            // we need to update the zone owner
            _removeZoneOwner(false);
            zoneFactory.changeOwner(
                lastAuction.highestBidder,
                zoneOwner.addr,
                address(this)
            );
            
            zoneOwnerPtr.init(lastAuction.highestBidder, lastAuction.endTime, highestBid, auctions.currentAuctionId);
        }

        zoneOwnerPtr.payTax(zoneOwner.staked.calcHarbergerTax(
            lastAuction.endTime,
            block.timestamp,
            zoneParams.ZONE_TAX
        ));

        zoneFactory.removeActiveBidder(lastAuction.highestBidder);
        zoneFactory.removeCurrentZoneBidders();
        zoneFactory.emitAuctionEnded(
            geohash,
            lastAuction.highestBidder,
            auctions.currentAuctionId,
            highestBid
        );

        _setParams();
    }

    /// @notice function to update the current auction state
    function processState() public {
        if (
            auctions.currentAuctionId > 0 &&
            auctions.auctionIdToAuction[auctions.currentAuctionId].state == uint256(AuctionUtils.AuctionState.Started)
        ) {
            // while uaction is running, no taxes need to be paid

            // handling of taxes around change of zone ownership are handled inside _endAuction
            if (block.timestamp >= auctions.auctionIdToAuction[auctions.currentAuctionId].endTime)
                _endAuction();
        } else {
            // no running auction, currentAuctionId could be zero
            if (zoneOwner.addr != address(0)) _handleTaxPayment();
        }
    }

    /// @notice private function to update the current auction state
    function _bid(
        address _sender,
        uint256 _dthAmount // GAS COST +/- 223.689
    ) private onlyWhenZoneHasOwner {
        if (
            auctions.currentAuctionId > 0 &&
            auctions.auctionIdToAuction[auctions.currentAuctionId].state == uint256(AuctionUtils.AuctionState.Started)
        ) {
            auctions.joinAuction(
                _sender, 
                _dthAmount, 
                geohash, 
                zoneOwner.addr, 
                zoneOwner.staked, 
                protocolController, 
                zoneParams,
                zoneFactory
            );
        } else {
            // there currently is no running auction
            if (zoneOwner.auctionId == 0) {
                // current zone owner did not become owner by winning an auction, but by creating this zone or caliming it when it was free
                require(
                    block.timestamp > zoneOwner.startTime + zoneParams.COOLDOWN_PERIOD,
                    "cooldown period did not end yet"
                );
            } else {
                // current zone owner became owner by winning an auction (which has ended)
                require(
                    block.timestamp >
                    auctions.auctionIdToAuction[auctions.currentAuctionId].endTime + zoneParams.COOLDOWN_PERIOD,
                    "cooldown period did not end yet"
                );
            }

            auctions.createAuction(
                _sender, 
                _dthAmount, 
                geohash, 
                zoneOwner.addr, 
                zoneOwner.staked, 
                protocolController, 
                zoneParams,
                zoneFactory
            );
        }
    }

    function _claimFreeZone(
        address _sender,
        uint256 _dthAmount // GAS COSt +/- 177.040
    ) private onlyWhenZoneHasNoOwner {
        _setParams();

        require(
            _dthAmount >= FLOOR_STAKE_PRICE,
            "need at least minimum zone stake amount (100 DTH)"
        );
        require(
            zoneFactory.ownerToZone(_sender) == address(0),
            "sender own already one zone"
        );
        require(
            zoneFactory.activeBidderToZone(_sender) == address(0),
            "sender is currently involved in an auction (Zone)"
        );

        // NOTE: empty zone claim will not have entry fee deducted, its not bidding it's taking immediately
        zoneFactory.changeOwner(_sender, zoneOwner.addr, address(this));
        uint256 zoneOwnerPtr;
        assembly { zoneOwnerPtr := zoneOwner.slot }
        zoneOwnerPtr.init(_sender, block.timestamp, _dthAmount, 0);
        zoneFactory.emitClaimFreeZone(geohash, _sender, _dthAmount);
    }

    function _topUp(
        uint256 _dthAmount // GAS COST +/- 104.201
    ) private onlyWhenZoneHasOwner {
        require(
            auctions.currentAuctionId == 0 ||
                auctions.auctionIdToAuction[auctions.currentAuctionId].state ==
                uint256(AuctionUtils.AuctionState.Ended),
            "cannot top up while auction running"
        );

        zoneOwner.balance += _dthAmount;

        // a zone owner can currently keep calling this to increase his dth balance inside the zone
        // without a change in his sell price (= zone.staked) or tax amount he needs to pay
    }

    // ------------------------------------------------
    //
    // Functions Setters Public
    //
    // ------------------------------------------------

    /// @notice ERC223 receiving function called by Dth contract when Eth is sent to this contract
    /// @param _from Who send DTH to this contract
    /// @param _value How much DTH was sent to this contract
    /// @param _data Additional bytes data sent
    function tokenFallback(
        address _from,
        uint256 _value,
        bytes memory _data // onlyWhenZoneEnabled
    ) public override {
        require(address(teller) != address(0), "contract not yet initialized");
        require(
            msg.sender == address(protocolController.dth()),
            "can only be called by dth contract"
        );
        // require caller neither zone owner, neither active bidder

        bytes1 func = _data[0];

        // require(func == bytes1(0x40) || func == bytes1(0x41) || func == bytes1(0x42) || func == bytes1(0x43), "did not match Zone function");

        processState();

        if (func == bytes1(0x41)) {
            // claimFreeZone
            _claimFreeZone(_from, _value);
        } else if (func == bytes1(0x42)) {
            // bid
            _bid(_from, _value);
        } else if (func == bytes1(0x43)) {
            // topUp
            _topUp(_value);
        }
    }

    /// @notice release zone ownership
    /// @dev can only be called by current zone owner, when there is no running auction
    function release()
        external
        // GAS COST +/- 72.351
        updateState
        onlyWhenCallerIsZoneOwner
    {
        // allow also when country is disabled, otherwise no way for zone owner to get their eth/dth back

        require(
            auctions.currentAuctionId == 0 ||
                auctions.auctionIdToAuction[auctions.currentAuctionId].state ==
                uint256(AuctionUtils.AuctionState.Ended),
            "cannot release while auction running"
        );

        uint256 ownerBalance = zoneOwner.balance;

        _removeZoneOwner(true);

        // if msg.sender is a contract, the DTH ERC223 contract will try to call tokenFallback
        // on msg.sender, this could lead to a reentrancy. But we prevent this by resetting
        // zoneOwner before we do dth.transfer(msg.sender)
        require(protocolController.dth().transfer(msg.sender, ownerBalance));
        zoneFactory.emitReleaseZone(geohash, msg.sender);
    }

    // offer three different withdraw functions, single auction, multiple auctions, all auctions

    /// @notice withdraw losing bids from a specific auction
    /// @param _auctionId The auction id
    function withdrawFromAuction(
        uint256 _auctionId // GAS COST +/- 125.070
    ) external updateState {
        auctions.withdrawFromAuction(_auctionId, protocolController.dth(), withdrawableDth, zoneFactory);
    }

    /// @notice withdraw from a given list of auction ids
    function withdrawFromAuctions(
        uint256[] calldata _auctionIds // GAS COST +/- 127.070
    ) external updateState {
        auctions.withdrawFromAuctions(_auctionIds, protocolController.dth(), withdrawableDth, zoneFactory);
    }

    // - bids in past auctions
    // - zone owner stake
    function withdrawDth() external updateState {
        uint256 dthWithdraw = withdrawableDth[msg.sender];
        require(dthWithdraw > 0, "nothing to withdraw");
        zoneFactory.removeActiveBidder(msg.sender);
        if (dthWithdraw > 0) {
            withdrawableDth[msg.sender] = 0;
            require(protocolController.dth().transfer(msg.sender, dthWithdraw));
        }
    }
}
