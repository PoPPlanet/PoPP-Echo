pragma solidity ^0.8.0;

interface IFinancePoolModule {
    function initialize(uint256 _profileId, uint256 _pubId, address _currency, address _hub) external;
    function setFirstCollectProfileId(uint256 _firstCollectProfileId) external;
    function setCollectReward(uint256 _profileId, uint256 _collectRewardAmount, uint256 _collectIndex) external;
    function setCreatorRewardRecord(uint256 _creatorReward) external;
    function setRefererRewardRecord(uint256 _refererProfileId, uint256 _refererReward) external;
    function computerReward(uint256 _claimProfileId) external returns(uint256);
    function claimReward(uint256 _claimProfileId, uint256 amount) external;
    function poolInfo() external view returns(uint256 totalHistoryCollectReward, uint256 canClaimTotalReward, uint256 claimedHistoryTotalReward, uint256 totalHistoryCreatorReward, uint256 totalHistoryRefererReward);
    function myInfo(uint256 _profileId) external view returns(uint256 myTotalReward, uint256 myCanClaimReward, uint256 myClaimedTotalReward, uint256 myCreatorReward, uint256 myRefererTotalReward);
}
