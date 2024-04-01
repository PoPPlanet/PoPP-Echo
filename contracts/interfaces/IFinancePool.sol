pragma solidity ^0.8.0;

interface IFinancePool {
    function setCreatorReward(uint256 _profileId, uint256 _creatorRewardAmount) external;
    function setReferrerReward(uint256 _profileId, uint256 _referrerRewardAmount) external;
}
