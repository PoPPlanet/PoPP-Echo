// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Errors} from '../../../libraries/Errors.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IFinancePool} from "../../../interfaces/IFinancePool.sol";
import {IPoPPHub} from "../../../interfaces/IPoPPHub.sol";

/**
 * @title FeeCollectModule
 * @author PoPP Protocol
 *
 * @notice This is a simple PoPP  CollectModule implementation, inheriting from the ICollectModule interface and
 * the FeeCollectModuleBase abstract contract.
 *
 * This module works by allowing unlimited collects for a publication at a given price.
 */
contract FinancePool is IFinancePool{

    address public hub;
    address public currency;

    //profileId => amount
    mapping(uint256 => uint256) public creatorReward;
    //profileId => creatorReward
    mapping(uint256 => uint256) public referralReward;
    //profileId => claimedReward
    mapping(uint256 => uint256) public claimedCreatorReward;
    mapping(uint256 => uint256) public claimedReferralReward;

    uint256 public creatorTotalReward;
    uint256 public referralTotalReward;
    uint256 public claimedTotalReward;

    constructor(address _hub, address _currency) {
        hub = _hub;
        currency = _currency;
    }

    event ClaimedCreatorReward(
        address claimer,
        uint256 claimerProfileId,
        uint256 amount
    );

    event ClaimedReferralReward(
        address claimer,
        uint256 claimerProfileId,
        uint256 amount
    );

    function setCreatorReward(uint256 _profileId, uint256 _creatorRewardAmount) external {
        require(IPoPPHub(hub).isCollectModuleWhitelisted(msg.sender), 'Invalid collectModule');
        creatorReward[_profileId] += _creatorRewardAmount;
        creatorTotalReward += _creatorRewardAmount;
    }

    function setReferrerReward(uint256 _profileId, uint256 _referrerRewardAmount) external {
        require(IPoPPHub(hub).isCollectModuleWhitelisted(msg.sender), 'Invalid collectModule');
        referralReward[_profileId] += _referrerRewardAmount;
        referralTotalReward += _referrerRewardAmount;
    }

    function computerCreatorReward(uint256 _claimProfileId) external view returns(uint256) {
        return creatorReward[_claimProfileId] - claimedCreatorReward[_claimProfileId];
    }

    function computerRefererReward(uint256 _claimProfileId) external view returns(uint256) {
        return referralReward[_claimProfileId] - claimedReferralReward[_claimProfileId];
    }

    function claimCreatorReward(uint256 _claimProfileId, uint256 _amount) external {
        address owner = IERC721(hub).ownerOf(_claimProfileId);
        require(msg.sender == owner, 'Not profile owner.');
        uint256 claim = creatorReward[_claimProfileId] - claimedCreatorReward[_claimProfileId];
        require(claim>=_amount, 'Invalid amount.');
        if (currency == address(0)){
            payable(msg.sender).call{value: _amount}("");
        } else {
            IERC20(currency).transfer(msg.sender, _amount);
        }
        claimedCreatorReward[_claimProfileId] += _amount;
        claimedTotalReward += _amount;
        emit ClaimedCreatorReward(msg.sender, _claimProfileId, _amount);
    }

    function claimRefererReward(uint256 _claimProfileId, uint256 _amount) external {
        address owner = IERC721(hub).ownerOf(_claimProfileId);
        require(msg.sender == owner, 'Not profile owner.');
        uint256 claim = referralReward[_claimProfileId] - claimedReferralReward[_claimProfileId];
        require(claim>=_amount, 'Invalid amount.');
        if (currency == address(0)){
            payable(msg.sender).call{value: _amount}("");
        } else {
            IERC20(currency).transfer(msg.sender, _amount);
        }
        claimedReferralReward[_claimProfileId] += _amount;
        claimedTotalReward += _amount;
        emit ClaimedReferralReward(msg.sender, _claimProfileId, _amount);
    }

    //===============get==============
    function poolInfo() external view returns(uint256 totalHistoryReward, uint256 creatorHistoryReward, uint256 referralHistoryReward, uint256 canClaimTotalReward, uint256 claimedHistoryTotalReward) {
        totalHistoryReward = creatorTotalReward + referralTotalReward;
        creatorHistoryReward = creatorTotalReward;
        referralHistoryReward = referralTotalReward;
        canClaimTotalReward = totalHistoryReward - claimedTotalReward;
        claimedHistoryTotalReward = claimedTotalReward;
    }

    function myInfo(uint256 _claimProfileId) external view returns(uint256 myTotalReward, uint256 myCreatorReward, uint256 myReferralReward
        , uint256 myCanClaimReward, uint256 myClaimedTotalReward, uint256 myClaimedCreatorReward, uint256 myClaimedReferralReward) {
        myTotalReward = creatorReward[_claimProfileId] + referralReward[_claimProfileId];
        myCreatorReward = creatorReward[_claimProfileId];
        myReferralReward = referralReward[_claimProfileId];
        myCanClaimReward = myTotalReward - myClaimedTotalReward;
        myClaimedTotalReward = claimedCreatorReward[_claimProfileId] + claimedReferralReward[_claimProfileId];
        myClaimedCreatorReward = claimedCreatorReward[_claimProfileId];
        myClaimedReferralReward = claimedReferralReward[_claimProfileId];
    }

    receive() external payable {}
}
