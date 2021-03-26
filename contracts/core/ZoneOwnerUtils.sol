// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.3;

library ZoneOwnerUtils {
    struct ZoneOwner {
        address addr;
        uint256 startTime;
        uint256 staked;
        uint256 balance;
        uint256 lastTaxTime;
        uint256 auctionId;
    }

    function init(
        uint256 _zoneOwnerPtr, 
        address _addr, 
        uint256 _startTime,
        uint256 _dthAmount,
        uint256 _auctionId
    ) public {
        ZoneOwner storage zoneOwner;
        assembly {
            zoneOwner.slot := _zoneOwnerPtr
        }
        zoneOwner.addr = _addr;
        zoneOwner.startTime = _startTime;
        zoneOwner.staked = _dthAmount;
        zoneOwner.balance = _dthAmount;
        zoneOwner.lastTaxTime = _startTime;
        zoneOwner.auctionId = _auctionId;
    }

    function extendZoneOwnership(
        uint256 _zoneOwnerPtr, 
        uint256 _increaseAmount, 
        uint256 _auctionId
    ) public {
        ZoneOwner storage zoneOwner;
        assembly {
            zoneOwner.slot := _zoneOwnerPtr
        }
        zoneOwner.staked += _increaseAmount;
        zoneOwner.balance += _increaseAmount;
        zoneOwner.auctionId = _auctionId;
    }

    function payTax(uint256 _zoneOwnerPtr, uint256 _amount) public {
        ZoneOwner storage zoneOwner;
        assembly {
            zoneOwner.slot := _zoneOwnerPtr
        }
        zoneOwner.balance -= _amount;
        zoneOwner.lastTaxTime = block.timestamp;
    }
}