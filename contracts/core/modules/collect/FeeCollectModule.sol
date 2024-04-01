// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IPoPPHub} from '../../../interfaces/IPoPPHub.sol';
import {IFinancePool} from '../../../interfaces/IFinancePool.sol';
import {IFinancePoolModule} from '../../../interfaces/IFinancePoolModule.sol';
import {ICollectModule} from '../../../interfaces/ICollectModule.sol';
import {Errors} from '../../../libraries/Errors.sol';
import {FeeModuleBase} from '../FeeModuleBase.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {Events} from "../../../libraries/Events.sol";
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {SafeERC20} from '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {Clones} from '@openzeppelin/contracts/proxy/Clones.sol';

/**
 * @notice A struct containing the necessary data to execute collect actions on a publication.
 *
 * @param amount The collecting cost associated with this publication.
 * @param currency The currency associated with this publication.
 * @param recipient The recipient address associated with this publication.
 * @param referralFee The referral fee associated with this publication.
 * @param followerOnly Whether only followers should be able to collect.
 */
struct ProfilePublicationData {
    uint256 amount;
    address currency;
    address recipient;
    uint16 collectRewardFee;
    uint16 referralFee;
    bool followerOnly;
}

interface ICollectPriceRates{
    function getPrice(uint256 p1, uint256 n) external view returns(uint256);
}

/**
 * @title FeeCollectModule
 * @author PoPP Protocol
 *
 * @notice This is a simple PoPP  CollectModule implementation, inheriting from the ICollectModule interface and
 * the FeeCollectModuleBase abstract contract.
 *
 * This module works by allowing unlimited collects for a publication at a given price.
 */
contract FeeCollectModule is FeeModuleBase, FollowValidationModuleBase, ICollectModule {
    using SafeERC20 for IERC20;

    mapping(uint256 => mapping(uint256 => ProfilePublicationData))
        internal _dataByPublicationByProfile;

    mapping(uint256 => mapping(uint256 => uint256)) private _pubIdOfIndex;
    mapping(uint256 => mapping(uint256 => address)) private _financePool;
    address public admin;
    address public collectPriceRatesAddress;

    constructor(address hub, address moduleGlobals, address _collectPriceRatesAddress) FeeModuleBase(moduleGlobals) ModuleBase(hub) {
        admin = msg.sender;
        collectPriceRatesAddress = _collectPriceRatesAddress;
    }

    struct SetRewardParams {
        uint256 index;
        uint256 amount;
        uint256 treasuryAmount;
        uint256 collectReward;
        uint256 referralAmount;
        address currency;
    }

    function setCollectPriceRatesAddress(address _collectPriceRatesAddress) public {
        require(msg.sender == admin, 'Not owner');
        collectPriceRatesAddress = _collectPriceRatesAddress;
    }

    /**
     * @notice This collect module levies a fee on collects and supports referrals. Thus, we need to decode data.
     *
     * @param profileId The token ID of the profile of the publisher, passed by the hub.
     * @param pubId The publication ID of the newly created publication, passed by the hub.
     * @param data The arbitrary data parameter, decoded into:
     *      uint256 amount: The currency total amount to levy.
     *      address currency: The currency address, must be internally whitelisted.
     *      address recipient: The custom recipient address to direct earnings to.
     *      uint16 referralFee: The referral fee to set.
     *      bool followerOnly: Whether only followers should be able to collect.
     *
     * @return bytes An abi encoded bytes parameter, which is the same as the passed data parameter.
     */
    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        address financeModule,
        bytes calldata data
    ) external override onlyHub returns (bytes memory) {
        (
            uint256 initPrice,
            address currency,
            uint16 collectRewardFee,
            uint16 referralFee,
            address[] memory nfts,
            uint256[] memory nftsRates
        ) = abi.decode(data, (uint256, address, uint16, uint16, address[], uint256[]));

        if (
            !_currencyWhitelisted(currency) ||
            referralFee > BPS_MAX ||
            nfts.length != nftsRates.length
        ) revert Errors.InitParamsInvalid();

        _checkParams(nftsRates, collectRewardFee, referralFee);

        _dataByPublicationByProfile[profileId][pubId].amount = initPrice;
        _dataByPublicationByProfile[profileId][pubId].currency = currency;
        _dataByPublicationByProfile[profileId][pubId].collectRewardFee = collectRewardFee;
        _dataByPublicationByProfile[profileId][pubId].referralFee = referralFee;

        address financePool = _deployFinancePool(profileId, pubId, currency, financeModule);
        _financePool[profileId][pubId] = financePool;

        return data;
    }

    function collectIndexInfo(uint256 profileId, uint256 pubId) external view returns(uint256, uint256, uint256) {
        uint256 index0 = _pubIdOfIndex[profileId][pubId];
        uint256 startPrice = _dataByPublicationByProfile[profileId][pubId].amount;
        if (index0 == 0) {
            return (1, startPrice, startPrice);
        }
        uint256 index1 = index0+1;
        uint256 p0 = ICollectPriceRates(collectPriceRatesAddress).getPrice(startPrice, index0);
        uint256 p1 = ICollectPriceRates(collectPriceRatesAddress).getPrice(startPrice, index1);
        return (index1, p0, p1);
    }

    function collectPrice(uint256 profileId, uint256 pubId) external view returns(uint256, address) {
        return _collectPrice(profileId, pubId);
    }

    function _collectPrice(uint256 profileId, uint256 pubId) internal view returns(uint256, address) {
        uint256 index = _pubIdOfIndex[profileId][pubId]+1;
        uint256 p1 = ICollectPriceRates(collectPriceRatesAddress).getPrice(_dataByPublicationByProfile[profileId][pubId].amount, index);
        address currency = _dataByPublicationByProfile[profileId][pubId].currency;
        return (p1, currency);
    }

    /**
     * @dev Processes a collect by:
     *  1. Ensuring the collector is a follower
     *  2. Charging a fee
     */
    function processCollect(
        CollectInfo calldata params,
        bytes calldata data
    ) external payable virtual override onlyHub {
        _processCollect(params.referrerProfileId, params.collector, params.collectorProfileId, params.profileId, params.pubId, data);
    }

    function _processCollect(
        uint256 referrerProfileId,
        address collector,
        uint256 collectorProfileId,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) internal {
        if (_dataByPublicationByProfile[profileId][pubId].followerOnly){
            if (!IPoPPHub(HUB).isFollowing(collectorProfileId, profileId)){
                revert Errors.FollowInvalid();
            }
        }
        address financePool = _financePool[profileId][pubId];
        CollectInfo memory collectInfo;
        collectInfo.collector = collector;
        collectInfo.collectorProfileId = collectorProfileId;
        collectInfo.profileId = profileId;
        collectInfo.pubId = pubId;
        collectInfo.financePool = financePool;
        collectInfo.referrerProfileId = referrerProfileId;
        if (referrerProfileId == profileId) {
            _processCollect(collectInfo, data);
        } else {
            _processCollectWithReferral(collectInfo, data);
        }
    }

    /**
     * @notice Returns the publication data for a given publication, or an empty struct if that publication was not
     * initialized with this module.
     *
     * @param profileId The token ID of the profile mapped to the publication to query.
     * @param pubId The publication ID of the publication to query.
     *
     * @return ProfilePublicationData The ProfilePublicationData struct mapped to that publication.
     */
    function getPublicationData(uint256 profileId, uint256 pubId)
        external
        view
        returns (ProfilePublicationData memory)
    {
        return _dataByPublicationByProfile[profileId][pubId];
    }

    function getFinancePool(uint256 profileId, uint256 pubId) external
    view
    returns (address)
    {
        return _financePool[profileId][pubId];
    }

    function _processCollect(
        CollectInfo memory collectInfo,
        bytes calldata data
    ) internal {
        (uint256 amount, address currency) = _collectPrice(collectInfo.profileId, collectInfo.pubId);
        uint256 collectRewardFee = _dataByPublicationByProfile[collectInfo.profileId][collectInfo.pubId].collectRewardFee;
        (uint256 collectReward, uint256 treasuryAmount, address treasury) = _treasuryAmountAndCollectReward(amount, collectRewardFee);
        uint256 adjustedAmount = amount - treasuryAmount;
        uint256 index = ++_pubIdOfIndex[collectInfo.profileId][collectInfo.pubId];
        SetRewardParams memory r;
        r.index = index;
        r.amount = amount;
        r.treasuryAmount = treasuryAmount;
        r.collectReward = collectReward;
        r.referralAmount = 0;
        r.currency = currency;

        _setReward(collectInfo, r);

        if (treasuryAmount > 0){
            if (currency == address(0)){
                payable(treasury).call{value: treasuryAmount}("");
            } else {
                IERC20(currency).safeTransferFrom(collectInfo.collector, treasury, treasuryAmount);
            }
        }
    }

    function _processCollectWithReferral(
        CollectInfo memory collectInfo,
        bytes calldata data
    ) internal {
        (uint256 amount, address currency) = _collectPrice(collectInfo.profileId, collectInfo.pubId);
        uint256 collectRewardFee = _dataByPublicationByProfile[collectInfo.profileId][collectInfo.pubId].collectRewardFee;
        uint256 referralFee = _dataByPublicationByProfile[collectInfo.profileId][collectInfo.pubId].referralFee;
        (uint256 collectReward, uint256 treasuryAmount, address treasury) = _treasuryAmountAndCollectReward(amount, collectRewardFee);
        uint256 index = ++_pubIdOfIndex[collectInfo.profileId][collectInfo.pubId];
        uint256 adjustedAmount = amount - treasuryAmount;
        uint256 referralAmount = 0;
        if (referralFee != 0) {
            referralAmount = (amount * referralFee) / BPS_MAX;
        }
        {
            SetRewardParams memory r;
            r.index = index;
            r.amount = amount;
            r.treasuryAmount = treasuryAmount;
            r.collectReward = collectReward;
            r.referralAmount = referralAmount;
            r.currency = currency;

            _setReward(collectInfo, r);
        }

        if (treasuryAmount > 0){
            if (currency == address(0)){
                payable(treasury).call{value: treasuryAmount}("");
            } else {
                IERC20(currency).safeTransferFrom(collectInfo.collector, treasury, treasuryAmount);
            }
        }
    }

    function _treasuryAmountAndCollectReward(uint256 amount, uint256 collectRewardFee) internal returns(uint256, uint256, address) {
        {
            (address treasury, uint16 treasuryFee) = _treasuryData();
            uint256 treasuryAmount = (amount * treasuryFee) / BPS_MAX;
            uint256 collectReward = (amount * collectRewardFee) / BPS_MAX;
            return (collectReward, treasuryAmount, treasury);
        }
    }

    function _setReward(
        CollectInfo memory collectInfo, SetRewardParams memory rewardParams
    ) internal{
        uint256 creatorRewardAmount = rewardParams.amount - rewardParams.treasuryAmount - rewardParams.collectReward - rewardParams.referralAmount;
        if (rewardParams.index == 1) {
            creatorRewardAmount +=  rewardParams.collectReward;
        }
        IFinancePoolModule(collectInfo.financePool).setCreatorRewardRecord(creatorRewardAmount);
        if (rewardParams.currency==address(0)){
            payable(IPoPPHub(HUB).getFinancePoolImpl()).call{value: creatorRewardAmount+rewardParams.referralAmount}("");
        } else {
            IERC20(rewardParams.currency).safeTransferFrom(collectInfo.collector, IPoPPHub(HUB).getFinancePoolImpl(), creatorRewardAmount+rewardParams.referralAmount);
        }
        IFinancePool(IPoPPHub(HUB).getFinancePoolImpl()).setCreatorReward(collectInfo.profileId, creatorRewardAmount);
        if (rewardParams.index > 1) {
            uint256 collectRewardPer = rewardParams.collectReward / (rewardParams.index-1);
            IFinancePoolModule(collectInfo.financePool).setCollectReward(collectInfo.collectorProfileId, collectRewardPer, rewardParams.index);
            if (rewardParams.currency==address(0)){
                payable(collectInfo.financePool).call{value: rewardParams.collectReward}("");
            } else {
                IERC20(rewardParams.currency).safeTransferFrom(collectInfo.collector, collectInfo.financePool, rewardParams.collectReward);
            }
        } else {
            IFinancePoolModule(collectInfo.financePool).setFirstCollectProfileId(collectInfo.collectorProfileId);
        }

        if (rewardParams.referralAmount > 0) {
            IFinancePoolModule(collectInfo.financePool).setRefererRewardRecord(collectInfo.referrerProfileId, rewardParams.referralAmount);
            IFinancePool(IPoPPHub(HUB).getFinancePoolImpl()).setReferrerReward(collectInfo.referrerProfileId, rewardParams.referralAmount);
        }
    }

    function _deployFinancePool(uint256 profileId, uint256 pubId, address currency, address financeModule) private returns (address) {
        address financePool = Clones.clone(financeModule);
        IFinancePoolModule(financePool).initialize(profileId, pubId, currency, HUB);
        emit Events.FinancePoolDeployed(profileId, pubId, financePool, block.timestamp);
        return financePool;
    }

    function _checkParams(uint256[] memory nftsRates, uint256 collectRewardFee, uint256 referralFee) internal view {

        (address treasury, uint16 treasuryFee) = _treasuryData();
        uint256 totalFeeRate = treasuryFee + collectRewardFee + referralFee;
        if (nftsRates.length>0) {
            for (uint i=0;i<nftsRates.length;i++){
                totalFeeRate = totalFeeRate + nftsRates[i];
            }
        }

        if (totalFeeRate > 10000){
            revert Errors.HeathError();
        }
    }

    receive() external payable {}
}
