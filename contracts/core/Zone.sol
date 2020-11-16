pragma solidity ^0.5.17;

import "openzeppelin-solidity/contracts/math/SafeMath.sol";

import "../interfaces/IERC223ReceivingContract.sol";
import "../interfaces/IDetherToken.sol";
import "../interfaces/IZoneFactory.sol";
import "../interfaces/IZone.sol";
import "../interfaces/ITeller.sol";

contract Zone is IERC223ReceivingContract {
    // ------------------------------------------------
    //
    // Library init
    //
    // ------------------------------------------------

    using SafeMath for uint256;

    // ------------------------------------------------
    //
    // Enums
    //
    // ------------------------------------------------

    enum AuctionState {Started, Ended}

    // ------------------------------------------------
    //
    // Structs
    //
    // ------------------------------------------------

    struct ZoneOwner {
        address addr;
        uint256 startTime;
        uint256 staked;
        uint256 balance;
        uint256 lastTaxTime;
        uint256 auctionId;
    }

    struct Auction {
        uint256 startTime;
        uint256 endTime;
        AuctionState state;
        address highestBidder;
    }

    mapping(uint256 => Auction) private auctionIdToAuction;
    // ------------------------------------------------
    //
    // Variables Public
    //
    // ------------------------------------------------

    uint256 public constant MIN_STAKE = 100 ether; // DTH, which is also 18 decimals!

    uint256 public constant BID_PERIOD = 48 hours; // mainnet params
    uint256 public constant COOLDOWN_PERIOD = 24 hours; // mainnet params
    uint256 public constant ENTRY_FEE_PERCENTAGE = 4; // in %
    uint256 public constant TAX_PERCENTAGE = 4; // 0,04% daily / around 15% yearly

    uint256 public constant MIN_RAISE = 6; // everybid should be more than x% that the previous highestbid

    bool private inited;

    IDetherToken public dth;
    IZoneFactory public zoneFactory;
    ITeller public teller;
    ZoneOwner public zoneOwner;
    address public taxCollector;

    bytes2 public country;
    bytes6 public geohash;

    mapping(address => uint256) public withdrawableDth;

    uint256 public currentAuctionId; // starts at 0, first auction will get id 1, etc.

    //      auctionId       bidder     dthAmount
    mapping(uint256 => mapping(address => uint256)) public auctionBids;

    // ------------------------------------------------
    //
    // Modifiers
    //
    // ------------------------------------------------

    modifier updateState {
        _processState();
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
        address _dth,
        // address _geo,
        address _zoneFactory,
        address _taxCollector,
        address _teller
    ) external {
        require(inited == false, "contract already initialized");
        require(
            _dthAmount >= MIN_STAKE,
            "zone dth stake should be at least minimum (100DTH)"
        );

        country = _countryCode;
        geohash = _geohash;

        dth = IDetherToken(_dth);
        zoneFactory = IZoneFactory(_zoneFactory);
        taxCollector = _taxCollector;

        zoneOwner.addr = _zoneOwner;
        zoneOwner.startTime = now;
        zoneOwner.staked = _dthAmount;
        zoneOwner.balance = _dthAmount;
        zoneOwner.lastTaxTime = now;
        zoneOwner.auctionId = 0; // was not gained by winning an auction

        inited = true;
        currentAuctionId = 0;
        teller = ITeller(_teller);
    }

    // ------------------------------------------------
    //
    // Functions Getters Public
    //
    // ------------------------------------------------

    function ownerAddr() external view returns (address) {
        return zoneOwner.addr;
    }

    function calcHarbergerTax(
        uint256 _startTime,
        uint256 _endTime,
        uint256 _dthAmount
    ) public view returns (uint256 taxAmount, uint256 keepAmount) {
        // TODO use smaller uint variables, hereby preventing under/overflows, so no need for SafeMath
        // source: https://programtheblockchain.com/posts/2018/09/19/implementing-harberger-tax-deeds/
        taxAmount = _dthAmount
            .mul(_endTime.sub(_startTime))
            .mul(TAX_PERCENTAGE)
            .div(10000)
            .div(1 days);
        keepAmount = _dthAmount.sub(taxAmount);
    }

    function calcEntryFee(uint256 _value)
        public
        view
        returns (uint256 burnAmount, uint256 bidAmount)
    {
        burnAmount = _value.mul(ENTRY_FEE_PERCENTAGE).div(100); // 4%
        bidAmount = _value.sub(burnAmount); // 96%
    }

    function auctionExists(uint256 _auctionId) external view returns (bool) {
        // if aucton does not exist we should get back zero, otherwise this field
        // will contain a block.timestamp, set whe creating an Auction, in constructor() and bid()
        return auctionIdToAuction[_auctionId].startTime > 0;
    }

    /// @notice get current zone owner data
    function getZoneOwner()
        external
        view
        returns (
            address,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        return (
            zoneOwner.addr, // address of current owner
            zoneOwner.startTime, // time this address became owner
            zoneOwner.staked, // "price you sell at"
            zoneOwner.balance, // will decrease whenever harberger taxes are paid
            zoneOwner.lastTaxTime, // time until taxes have been paid
            zoneOwner.auctionId // if gained by winning auction, the auction id, otherwise zero
        );
    }

    /// @notice get a specific auction
    function getAuction(uint256 _auctionId)
        public
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        )
    {
        require(
            _auctionId > 0 && _auctionId <= currentAuctionId,
            "auction does not exist"
        );

        Auction memory auction = auctionIdToAuction[_auctionId];

        uint256 highestBid = auctionBids[_auctionId][auction.highestBidder];

        // If auction is ongoing, for current zone owner his existing zone stake is added to his bid
        if (
            auction.state == AuctionState.Started &&
            auction.highestBidder == zoneOwner.addr
        ) {
            highestBid = highestBid.add(zoneOwner.staked);
        }

        return (
            _auctionId,
            uint256(auction.state),
            auction.startTime,
            auction.endTime,
            auction.highestBidder,
            highestBid
        );
    }

    /// @notice get the last auction
    function getLastAuction()
        external
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            address,
            uint256
        )
    {
        return getAuction(currentAuctionId);
    }

    // ------------------------------------------------
    //
    // Functions Utils
    //
    // ------------------------------------------------

    function toBytes1(bytes memory _bytes, uint256 _start)
        private
        pure
        returns (bytes1)
    {
        require(_bytes.length >= (_start + 1), " not long enough");
        bytes1 tempBytes1;

        assembly {
            tempBytes1 := mload(add(add(_bytes, 0x20), _start))
        }

        return tempBytes1;
    }

    // ------------------------------------------------
    //
    // Functions Setters Private
    //
    // ------------------------------------------------

    function _removeZoneOwner(bool fromRelease) private {
        // if we call this function from release() we shouldn't update withdrawableDth as we already send dth
        if (!fromRelease) {
            withdrawableDth[zoneOwner.addr] = withdrawableDth[zoneOwner.addr]
                .add(zoneOwner.balance);
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

        if (zoneOwner.lastTaxTime >= now) {
            return; // short-circuit: multiple txes in 1 block OR many blocks but in same Auction
        }

        (uint256 taxAmount, uint256 keepAmount) = calcHarbergerTax(
            zoneOwner.lastTaxTime,
            now,
            zoneOwner.staked
        );

        if (taxAmount > zoneOwner.balance) {
            // zone owner does not have enough balance, remove him as zone owner
            uint256 oldZoneOwnerBalance = zoneOwner.balance;
            _removeZoneOwner(false);

            require(dth.transfer(taxCollector, oldZoneOwnerBalance));
        } else {
            // zone owner can pay due taxes
            zoneOwner.balance = zoneOwner.balance.sub(taxAmount);
            zoneOwner.lastTaxTime = now;
            (address referrer, uint256 refFee) = teller.getReferrer();
            if (referrer != address(0x00) && refFee > 0) {
                uint256 referralFee = taxAmount.mul(refFee).div(1000);

                // to avoid Dos with revert if referrer is contract
                bytes memory payload = abi.encodeWithSignature(
                    "transfer(address,uint256)",
                    referrer,
                    referralFee
                );
                address(dth).call(payload);

                // require(dth.transfer(referrer, referralFee));
                require(dth.transfer(taxCollector, taxAmount - referralFee));
            } else {
                require(dth.transfer(taxCollector, taxAmount));
            }
        }
    }

    /*
     * Called when auction is ended by _processState()
     * update the state with new owner and new bid
     */
    function _endAuction() private {
        Auction storage lastAuction = auctionIdToAuction[currentAuctionId];

        lastAuction.state = AuctionState.Ended;

        uint256 highestBid = auctionBids[currentAuctionId][lastAuction
            .highestBidder];
        uint256 auctionEndTime = auctionIdToAuction[currentAuctionId].endTime;
        address highestBidder = lastAuction.highestBidder;

        if (zoneOwner.addr == highestBidder) {
            // current zone owner won the auction, extend his zone ownershp
            zoneOwner.staked = zoneOwner.staked.add(highestBid);
            zoneOwner.balance = zoneOwner.balance.add(highestBid);

            // need to set it since it might've been zero
            zoneOwner.auctionId = currentAuctionId; // the (last) auctionId that gave the zoneOwner zone ownership
        } else {
            // we need to update the zone owner
            _removeZoneOwner(false);
            zoneFactory.changeOwner(
                highestBidder,
                zoneOwner.addr,
                address(this)
            );
            zoneOwner.addr = highestBidder;
            zoneOwner.startTime = auctionEndTime;
            zoneOwner.staked = highestBid; // entry fee is already deducted when user calls bid()
            zoneOwner.balance = highestBid;
            zoneOwner.auctionId = currentAuctionId; // the auctionId that gave the zoneOwner zone ownership
        }

        // (new) zone owner needs to pay taxes from the moment he acquires zone ownership until now
        (uint256 taxAmount, uint256 keepAmount) = calcHarbergerTax(
            auctionEndTime,
            now,
            zoneOwner.staked
        );
        zoneOwner.balance = zoneOwner.balance.sub(taxAmount);
        zoneOwner.lastTaxTime = now;
        zoneFactory.removeActiveBidder(highestBidder);
        zoneFactory.removeCurrentZoneBidders();
        zoneFactory.emitAuctionEnded(
            geohash,
            highestBidder,
            currentAuctionId,
            highestBid
        );
    }

    function processState() external /* onlyByTellerContract */
    {
        _processState();
    }

    /// @notice private function to update the current auction state
    function _processState() private {
        if (
            currentAuctionId > 0 &&
            auctionIdToAuction[currentAuctionId].state == AuctionState.Started
        ) {
            // while uaction is running, no taxes need to be paid

            // handling of taxes around change of zone ownership are handled inside _endAuction
            if (now >= auctionIdToAuction[currentAuctionId].endTime)
                _endAuction();
        } else {
            // no running auction, currentAuctionId could be zero
            if (zoneOwner.addr != address(0)) _handleTaxPayment();
        }
    }

    function _joinAuction(address _sender, uint256 _dthAmount) private {
        Auction storage lastAuction = auctionIdToAuction[currentAuctionId];

        //------------------------------------------------------------------------------//
        // there is a running auction, lets see if we can join the auction with our bid //
        //------------------------------------------------------------------------------//

        require(
            zoneFactory.activeBidderToZone(_sender) == address(this) ||
                zoneFactory.activeBidderToZone(_sender) == address(0),
            "sender is currently involved in another auction"
        );
        require(
            zoneFactory.ownerToZone(_sender) == address(0) ||
                zoneFactory.ownerToZone(_sender) == address(this),
            "sender own already another zone"
        );

        uint256 currentHighestBid = auctionBids[currentAuctionId][lastAuction
            .highestBidder];

        if (_sender == zoneOwner.addr) {
            uint256 dthAddedBidsAmount = auctionBids[currentAuctionId][_sender]
                .add(_dthAmount);
            // the current zone owner's stake also counts in his bid
            require(
                zoneOwner.staked.add(dthAddedBidsAmount) >=
                    currentHighestBid.add(
                        currentHighestBid.mul(MIN_RAISE).div(100)
                    ),
                "bid + already staked is less than current highest + MIN_RAISE"
            );

            auctionBids[currentAuctionId][_sender] = dthAddedBidsAmount;
        } else {
            // _sender is not the current zone owner
            if (auctionBids[currentAuctionId][_sender] == 0) {
                // this is the first bid of this challenger, deduct entry fee
                (uint256 burnAmount, uint256 bidAmount) = calcEntryFee(
                    _dthAmount
                );
                require(
                    bidAmount >=
                        currentHighestBid.add(
                            currentHighestBid.mul(MIN_RAISE).div(100)
                        ),
                    "bid is less than current highest + MIN_RAISE"
                );

                auctionBids[currentAuctionId][_sender] = bidAmount;
                require(dth.transfer(taxCollector, burnAmount));
            } else {
                // not the first bid, no entry fee
                uint256 newUserTotalBid = auctionBids[currentAuctionId][_sender]
                    .add(_dthAmount);
                require(
                    newUserTotalBid >=
                        currentHighestBid.add(
                            currentHighestBid.mul(MIN_RAISE).div(100)
                        ),
                    "bid is less than current highest + MIN_RAISE"
                );

                auctionBids[currentAuctionId][_sender] = newUserTotalBid;
            }
        }

        // it worked, _sender placed a bid
        lastAuction.highestBidder = _sender;
        zoneFactory.fillCurrentZoneBidder(_sender);
        zoneFactory.emitBid(geohash, _sender, currentAuctionId, _dthAmount);
    }

    function _createAuction(address _sender, uint256 _dthAmount) private {
        require(
            zoneFactory.activeBidderToZone(_sender) == address(0),
            "sender is currently involved in an auction (Zone)"
        );
        require(
            zoneFactory.ownerToZone(_sender) == address(0),
            "sender own already a zone"
        );

        (uint256 burnAmount, uint256 bidAmount) = calcEntryFee(_dthAmount);
        require(
            bidAmount >
                zoneOwner.staked.add(zoneOwner.staked.mul(MIN_RAISE).div(100)),
            "bid is lower than current zone stake"
        );

        // save the new Auction
        uint256 newAuctionId = ++currentAuctionId;

        auctionIdToAuction[newAuctionId] = Auction({
            state: AuctionState.Started,
            startTime: now,
            endTime: now.add(BID_PERIOD),
            highestBidder: _sender // caller (challenger)
        });

        auctionBids[newAuctionId][_sender] = bidAmount;

        require(dth.transfer(taxCollector, burnAmount));
        //
        zoneFactory.fillCurrentZoneBidder(_sender);
        zoneFactory.fillCurrentZoneBidder(zoneOwner.addr);
        zoneFactory.emitAuctionCreated(
            geohash,
            _sender,
            newAuctionId,
            _dthAmount
        );
    }

    /// @notice private function to update the current auction state
    function _bid(
        address _sender,
        uint256 _dthAmount // GAS COST +/- 223.689
    ) private onlyWhenZoneHasOwner {
        if (
            currentAuctionId > 0 &&
            auctionIdToAuction[currentAuctionId].state == AuctionState.Started
        ) {
            _joinAuction(_sender, _dthAmount);
        } else {
            // there currently is no running auction
            if (zoneOwner.auctionId == 0) {
                // current zone owner did not become owner by winning an auction, but by creating this zone or caliming it when it was free
                require(
                    now > zoneOwner.startTime.add(COOLDOWN_PERIOD),
                    "cooldown period did not end yet"
                );
            } else {
                // current zone owner became owner by winning an auction (which has ended)
                require(
                    now >
                        auctionIdToAuction[currentAuctionId].endTime.add(
                            COOLDOWN_PERIOD
                        ),
                    "cooldown period did not end yet"
                );
            }
            _createAuction(_sender, _dthAmount);
        }
    }

    function _claimFreeZone(
        address _sender,
        uint256 _dthAmount // GAS COSt +/- 177.040
    ) private onlyWhenZoneHasNoOwner {
        require(
            _dthAmount >= MIN_STAKE,
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
        zoneOwner.addr = _sender;
        zoneOwner.startTime = now;
        zoneOwner.staked = _dthAmount;
        zoneOwner.balance = _dthAmount;
        zoneOwner.lastTaxTime = now;
        zoneOwner.auctionId = 0; // since it was not gained wby winning an auction
        zoneFactory.emitClaimFreeZone(geohash, _sender, _dthAmount);
    }

    function _topUp(
        address _sender,
        uint256 _dthAmount // GAS COST +/- 104.201
    ) private onlyWhenZoneHasOwner {
        // require(_sender == zoneOwner.addr, "caller is not zoneowner");
        require(
            currentAuctionId == 0 ||
                auctionIdToAuction[currentAuctionId].state ==
                AuctionState.Ended,
            "cannot top up while auction running"
        );

        uint256 oldBalance = zoneOwner.balance;
        uint256 newBalance = oldBalance.add(_dthAmount);
        zoneOwner.balance = newBalance;

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
    ) public  {
        require(inited == true, "contract not yet initialized");
        require(
            msg.sender == address(dth),
            "can only be called by dth contract"
        );
        // require caller neither zone owner, neither active bidder

        bytes1 func = toBytes1(_data, 0);

        // require(func == bytes1(0x40) || func == bytes1(0x41) || func == bytes1(0x42) || func == bytes1(0x43), "did not match Zone function");

        _processState();

        if (func == bytes1(0x41)) {
            // claimFreeZone
            _claimFreeZone(_from, _value);
        } else if (func == bytes1(0x42)) {
            // bid
            _bid(_from, _value);
        } else if (func == bytes1(0x43)) {
            // topUp
            _topUp(_from, _value);
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
            currentAuctionId == 0 ||
                auctionIdToAuction[currentAuctionId].state ==
                AuctionState.Ended,
            "cannot release while auction running"
        );

        uint256 ownerBalance = zoneOwner.balance;

        _removeZoneOwner(true);

        // if msg.sender is a contract, the DTH ERC223 contract will try to call tokenFallback
        // on msg.sender, this could lead to a reentrancy. But we prevent this by resetting
        // zoneOwner before we do dth.transfer(msg.sender)
        require(dth.transfer(msg.sender, ownerBalance));
        zoneFactory.emitReleaseZone(geohash, msg.sender);
    }

    // offer three different withdraw functions, single auction, multiple auctions, all auctions

    /// @notice withdraw losing bids from a specific auction
    /// @param _auctionId The auction id
    function withdrawFromAuction(
        uint256 _auctionId // GAS COST +/- 125.070
    ) external updateState {
        // even when country is disabled, otherwise users cannot withdraw their bids
        require(
            _auctionId > 0 && _auctionId <= currentAuctionId,
            "auctionId does not exist"
        );

        require(
            auctionIdToAuction[_auctionId].state == AuctionState.Ended,
            "cannot withdraw while auction is active"
        );
        require(
            auctionIdToAuction[_auctionId].highestBidder != msg.sender,
            "auction winner can not withdraw"
        );
        require(auctionBids[_auctionId][msg.sender] > 0, "nothing to withdraw");

        uint256 withdrawAmount = auctionBids[_auctionId][msg.sender];
        auctionBids[_auctionId][msg.sender] = 0;
        if (withdrawableDth[msg.sender] > 0) {
            withdrawAmount = withdrawAmount.add(withdrawableDth[msg.sender]);
            withdrawableDth[msg.sender] = 0;
        }
        zoneFactory.removeActiveBidder(msg.sender);
        require(dth.transfer(msg.sender, withdrawAmount));
    }

    /// @notice withdraw from a given list of auction ids
    function withdrawFromAuctions(
        uint256[] calldata _auctionIds // GAS COST +/- 127.070
    ) external updateState {
        // even when country is disabled, can withdraw
        require(currentAuctionId > 0, "there are no auctions");

        require(_auctionIds.length > 0, "auctionIds list is empty");
        require(
            _auctionIds.length <= currentAuctionId,
            "auctionIds list is longer than allowed"
        );

        uint256 withdrawAmountTotal = 0;

        for (uint256 idx = 0; idx < _auctionIds.length; idx++) {
            uint256 auctionId = _auctionIds[idx];
            require(
                auctionId > 0 && auctionId <= currentAuctionId,
                "auctionId does not exist"
            );
            require(
                auctionIdToAuction[auctionId].state == AuctionState.Ended,
                "cannot withdraw from running auction"
            );
            require(
                auctionIdToAuction[auctionId].highestBidder != msg.sender,
                "auction winner can not withdraw"
            );
            uint256 withdrawAmount = auctionBids[auctionId][msg.sender];
            if (withdrawAmount > 0) {
                // if user supplies the same auctionId multiple times in auctionIds,
                // only the first one will get a withdrawal amount
                auctionBids[auctionId][msg.sender] = 0;
                withdrawAmountTotal = withdrawAmountTotal.add(withdrawAmount);
            }
        }
        if (withdrawableDth[msg.sender] > 0) {
            withdrawAmountTotal = withdrawAmountTotal.add(
                withdrawableDth[msg.sender]
            );
            withdrawableDth[msg.sender] = 0;
        }
        zoneFactory.removeActiveBidder(msg.sender);

        require(withdrawAmountTotal > 0, "nothing to withdraw");

        require(dth.transfer(msg.sender, withdrawAmountTotal));
    }

    // - bids in past auctions
    // - zone owner stake
    function withdrawDth() external updateState {
        uint256 dthWithdraw = withdrawableDth[msg.sender];
        require(dthWithdraw > 0, "nothing to withdraw");
        zoneFactory.removeActiveBidder(msg.sender);
        if (dthWithdraw > 0) {
            withdrawableDth[msg.sender] = 0;
            require(dth.transfer(msg.sender, dthWithdraw));
        }
    }
}
