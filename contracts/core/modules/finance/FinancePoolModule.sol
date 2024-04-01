// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {Errors} from '../../../libraries/Errors.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IFinancePoolModule} from "../../../interfaces/IFinancePoolModule.sol";

/**
 * @title FeeCollectModule
 * @author PoPP Protocol
 *
 * @notice This is a simple PoPP  CollectModule implementation, inheriting from the ICollectModule interface and
 * the FeeCollectModuleBase abstract contract.
 *
 * This module works by allowing unlimited collects for a publication at a given price.
 */
contract FinancePoolModule is IFinancePoolModule{
    using SafeERC20 for IERC20;

    address public hub;
    address public collectModule;
    address public currency;
    uint256 public profileId;
    uint256 public pubId;

    uint256 private _collectReward;
    mapping(uint256 => uint256) private _collectRewardInitial;
    //profileId => claimedReward
    mapping(uint256 => uint256) private _claimedReward;

    uint256 private _totalHistoryCollectReward;
    uint256 public claimedTotalReward;

    uint256 public totalCreatorReward;
    //referer profileId=> referer reward
    mapping(uint256=>uint256) public totalRefererRewardMapping;
    uint256 public totalRefererReward;

    bool initialized = false;
    uint256 public firstCollectProfileId;

    constructor() {}

    event Claimed(
        address claimer,
        uint256 claimerProfileId,
        uint256 profileId,
        uint256 pubId,
        uint256 amount
    );

    function initialize(uint256 _profileId, uint256 _pubId, address _currency, address _hub) external  {
        require(!initialized, 'initialized.');
        profileId = _profileId;
        pubId = _pubId;
        collectModule = msg.sender;
        currency = _currency;
        hub = _hub;
        initialized = true;
    }

    function setFirstCollectProfileId(uint256 _firstCollectProfileId) external{
        require(msg.sender == collectModule, 'Not collectModule');
        firstCollectProfileId = _firstCollectProfileId;
    }

    function setCollectReward(uint256 _profileId, uint256 _collectRewardAmount, uint256 _collectIndex) external {
        require(msg.sender == collectModule, 'Not collectModule');
        //不可重复臻藏，如果每次每次_collectRewardAmount数值都是一样的则可以重复臻藏，否则须分别记录数据，分配奖励时须找出多次臻藏的 profile 对他们进行处理...
        require(_profileId != firstCollectProfileId && _collectRewardInitial[_profileId] == 0, 'Repeat collect');
        if (_collectIndex > 1) {
            _collectReward += _collectRewardAmount;
            _collectRewardInitial[_profileId] = _collectReward;
            _totalHistoryCollectReward = _totalHistoryCollectReward + (_collectIndex-1) * _collectRewardAmount;
        } else {
            firstCollectProfileId = _profileId;
        }
    }

    function setCreatorRewardRecord(uint256 _creatorReward) external {
        require(msg.sender == collectModule, 'Not collectModule');
        totalCreatorReward += _creatorReward;
    }

    function setRefererRewardRecord(uint256 _refererProfileId, uint256 _refererReward) external {
        require(msg.sender == collectModule, 'Not collectModule');
        totalRefererRewardMapping[_refererProfileId] += _refererReward;
        totalRefererReward += _refererReward;
    }

    function computerReward(uint256 _claimProfileId) external view returns(uint256) {
        return _computerReward(_claimProfileId);
    }

    function claimReward(uint256 _claimProfileId, uint256 amount) external {
        address owner = IERC721(hub).ownerOf(_claimProfileId);
        require(msg.sender == owner, 'Not profile owner.');
        uint256 claim = _computerReward(_claimProfileId);
        require(claim>=amount, 'Invalid amount.');
        if (currency == address(0)){
            payable(msg.sender).call{value: amount}("");
        } else {
            IERC20(currency).transfer(msg.sender, amount);
        }
        _claimedReward[_claimProfileId] += amount;
        claimedTotalReward += amount;
        emit Claimed(msg.sender, _claimProfileId, profileId, pubId, amount);
    }
    //===============get==============
    function poolInfo() external view returns(uint256 totalHistoryCollectReward, uint256 canClaimTotalReward, uint256 claimedHistoryTotalReward, uint256 totalHistoryCreatorReward, uint256 totalHistoryRefererReward) {
        canClaimTotalReward = _totalHistoryCollectReward - claimedTotalReward;
        claimedHistoryTotalReward = claimedTotalReward;
        totalHistoryCollectReward = _totalHistoryCollectReward;
        totalHistoryCreatorReward = totalCreatorReward;
        totalHistoryRefererReward = totalRefererReward;
    }

    function myInfo(uint256 _profileId) external view returns(uint256 myTotalReward, uint256 myCanClaimReward, uint256 myClaimedTotalReward, uint256 myCreatorReward, uint256 myRefererTotalReward) {
        myCreatorReward = 0;
        if (_profileId == profileId) {
            myCreatorReward = totalCreatorReward;
        }
        uint256 myCollectReward = 0;
        if (_profileId == firstCollectProfileId || _collectRewardInitial[_profileId]>0){
            myCollectReward = _collectReward - _collectRewardInitial[_profileId];
        }
        //注意 myClaimedTotalReward 是我的历史臻藏奖励总和
        myClaimedTotalReward = myCollectReward;
        myTotalReward = myCreatorReward + totalRefererRewardMapping[_profileId] + myCollectReward;
        myCanClaimReward = _computerReward(_profileId);
        myRefererTotalReward = totalRefererRewardMapping[_profileId];
    }

    //===============internal==================
    function _computerReward(uint256 _claimProfileId) internal view returns(uint256){
        if (_claimProfileId != firstCollectProfileId && _collectRewardInitial[_claimProfileId] == 0) {
            return 0;
        }
        return  _collectReward - _collectRewardInitial[_claimProfileId] - _claimedReward[_claimProfileId];
    }

    function getCollectReward() public view returns(uint256) {
        return _collectReward;
    }

    receive() external payable {}
}
