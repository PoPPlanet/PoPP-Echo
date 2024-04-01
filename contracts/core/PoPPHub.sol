// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IPoPPHub} from '../interfaces/IPoPPHub.sol';
import {Events} from '../libraries/Events.sol';
import {Helpers} from '../libraries/Helpers.sol';
import {Constants} from '../libraries/Constants.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {PublishingLogic} from '../libraries/PublishingLogic.sol';
import {ProfileTokenURILogic} from '../libraries/ProfileTokenURILogic.sol';
import {InteractionLogic} from '../libraries/InteractionLogic.sol';
import {PoPPNFTBase} from './base/PoPPNFTBase.sol';
import {PoPPMultiState} from './base/PoPPMultiState.sol';
import {PoPPHubStorage} from './storage/PoPPHubStorage.sol';
import {VersionedInitializable} from '../upgradeability/VersionedInitializable.sol';
import {IERC721Enumerable} from '@openzeppelin/contracts/token/ERC721/extensions/IERC721Enumerable.sol';
import {IERC6551Registry} from '../interfaces/IERC6551Registry.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IEchoNFT} from '../interfaces/IEchoNFT.sol';
import {IMirrorNFT} from "../interfaces/IMirrorNFT.sol";

/**
 * @title PoPPHub
 * @author PoPP Protocol
 *
 * @notice This is the main entrypoint of the PoPP Protocol. It contains governance functionality as well as
 * publishing and profile interaction functionality.
 *
 * NOTE: The PoPP Protocol is unique in that frontend operators need to track a potentially overwhelming
 * number of NFT contracts and interactions at once. For that reason, we've made two quirky design decisions:
 *      1. Both Follow & Collect NFTs invoke an PoPPHub callback on transfer with the sole purpose of emitting an event.
 *      2. Almost every event in the protocol emits the current block timestamp, reducing the need to fetch it manually.
 */
contract PoPPHub is PoPPNFTBase, VersionedInitializable, PoPPMultiState, PoPPHubStorage, IPoPPHub {
    uint256 internal constant REVISION = 1;

    address internal immutable FOLLOW_NFT_IMPL;
    address internal immutable ERC6551_ACCOUNT_IMPL;
    address internal immutable ERC6551_REGISTRY;
    address internal immutable ECHO_NFT_ADDRESS;
    address internal immutable MIRROR_NFT_ADDRESS;
    address internal immutable FINANCE_POOL_ADDRESS;
    bytes32 internal ERC6551_SALT = '0x000000000000000000000000000';

    /**
     * @dev This modifier reverts if the caller is not the configured governance address.
     */
    modifier onlyGov() {
        _validateCallerIsGovernance();
        _;
    }

    /**
     * @dev The constructor sets the immutable follow & collect NFT implementations.
     *
     * @param followNFTImpl The follow NFT implementation address.
     */
    constructor(address followNFTImpl
                , address erc6551AccountImpl
                , address erc6551Registry
                , address echoNFTAddress
                , address mirrorNFTAddress
                , address financePoolAddress
    ) {
        if (followNFTImpl == address(0)) revert Errors.InitParamsInvalid();
        if (erc6551AccountImpl == address(0)) revert Errors.InitParamsInvalid();
        if (echoNFTAddress == address(0)) revert Errors.InitParamsInvalid();
        if (mirrorNFTAddress == address(0)) revert Errors.InitParamsInvalid();
        FOLLOW_NFT_IMPL = followNFTImpl;
        ERC6551_ACCOUNT_IMPL = erc6551AccountImpl;
        ERC6551_REGISTRY = erc6551Registry;
        ECHO_NFT_ADDRESS = echoNFTAddress;
        MIRROR_NFT_ADDRESS = mirrorNFTAddress;
        FINANCE_POOL_ADDRESS = financePoolAddress;
    }

    /// @inheritdoc IPoPPHub
    function initialize(
        string calldata name,
        string calldata symbol,
        address newGovernance
    ) external override initializer {
        super._initialize(name, symbol);
        _setState(DataTypes.ProtocolState.Paused);
        _setGovernance(newGovernance);
    }

    /// ***********************
    /// *****GOV FUNCTIONS*****
    /// ***********************

    /// @inheritdoc IPoPPHub
    function setGovernance(address newGovernance) external override onlyGov {
        _setGovernance(newGovernance);
    }

    /// @inheritdoc IPoPPHub
    function setEmergencyAdmin(address newEmergencyAdmin) external override onlyGov {
        address prevEmergencyAdmin = _emergencyAdmin;
        _emergencyAdmin = newEmergencyAdmin;
        emit Events.EmergencyAdminSet(
            msg.sender,
            prevEmergencyAdmin,
            newEmergencyAdmin,
            block.timestamp
        );
    }

    /// @inheritdoc IPoPPHub
    function setState(DataTypes.ProtocolState newState) external override {
        if (msg.sender == _emergencyAdmin) {
            if (newState == DataTypes.ProtocolState.Unpaused)
                revert Errors.EmergencyAdminCannotUnpause();
            _validateNotPaused();
        } else if (msg.sender != _governance) {
            revert Errors.NotGovernanceOrEmergencyAdmin();
        }
        _setState(newState);
    }

    ///@inheritdoc IPoPPHub
    function whitelistProfileCreator(address profileCreator, bool whitelist)
    external
    override
    onlyGov
    {
        _profileCreatorWhitelisted[profileCreator] = whitelist;
        emit Events.ProfileCreatorWhitelisted(profileCreator, whitelist, block.timestamp);
    }

    /// @inheritdoc IPoPPHub
    function whitelistFollowModule(address followModule, bool whitelist) external override onlyGov {
        _followModuleWhitelisted[followModule] = whitelist;
        emit Events.FollowModuleWhitelisted(followModule, whitelist, block.timestamp);
    }

    function whitelistFinanceModule(address financeModule, bool whitelist) external override onlyGov {
        _financeModuleWhitelisted[financeModule] = whitelist;
        emit Events.FinanceModuleWhitelisted(financeModule, whitelist, block.timestamp);
    }

    /// @inheritdoc IPoPPHub
    function whitelistReferenceModule(address referenceModule, bool whitelist)
    external
    override
    onlyGov
    {
        _referenceModuleWhitelisted[referenceModule] = whitelist;
        emit Events.ReferenceModuleWhitelisted(referenceModule, whitelist, block.timestamp);
    }

    /// @inheritdoc IPoPPHub
    function whitelistCollectModule(address collectModule, bool whitelist)
    external
    override
    onlyGov
    {
        _collectModuleWhitelisted[collectModule] = whitelist;
        emit Events.CollectModuleWhitelisted(collectModule, whitelist, block.timestamp);
    }

    /// *********************************
    /// *****PROFILE OWNER FUNCTIONS*****
    /// *********************************

    /// @inheritdoc IPoPPHub
    function createProfile(DataTypes.CreateProfileData calldata vars)
    external
    override
    whenNotPaused
    returns (uint256)
    {
        //if (!_profileCreatorWhitelisted[msg.sender]) revert Errors.ProfileCreatorNotWhitelisted();
    unchecked {
        uint256 profileId = ++_profileCounter;
        _mint(vars.to, profileId);
        IERC6551Registry(ERC6551_REGISTRY).createAccount(ERC6551_ACCOUNT_IMPL, ERC6551_SALT, block.chainid, address(this), profileId);
        PublishingLogic.createProfile(
            vars,
            profileId,
            _profileIdByHandleHash,
            _profileById,
            _followModuleWhitelisted
        );
        return profileId;
    }
    }

    /// @inheritdoc IPoPPHub
    function setDefaultProfile(uint256 profileId) external override whenNotPaused {
        _setDefaultProfile(msg.sender, profileId);
    }

    /// @inheritdoc IPoPPHub
    function setFollowModule(
        uint256 profileId,
        address followModule,
        bytes calldata followModuleInitData
    ) external override whenNotPaused {
        _validateCallerIsProfileOwner(profileId);
        PublishingLogic.setFollowModule(
            profileId,
            followModule,
            followModuleInitData,
            _profileById[profileId],
            _followModuleWhitelisted
        );
    }

    /// @inheritdoc IPoPPHub
    function setDispatcher(uint256 profileId, address dispatcher) external override whenNotPaused {
        _validateCallerIsProfileOwner(profileId);
        _setDispatcher(profileId, dispatcher);
    }

    /// @inheritdoc IPoPPHub
    function setProfileImageURI(uint256 profileId, string calldata imageURI)
    external
    override
    whenNotPaused
    {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setProfileImageURI(profileId, imageURI);
    }

    /// @inheritdoc IPoPPHub
    function setFollowNFTURI(uint256 profileId, string calldata followNFTURI)
    external
    override
    whenNotPaused
    {
        _validateCallerIsProfileOwnerOrDispatcher(profileId);
        _setFollowNFTURI(profileId, followNFTURI);
    }

    /// @inheritdoc IPoPPHub
    function post(DataTypes.PostData calldata vars)
    external
    override
    whenPublishingEnabled
    returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        return
        _createPost(
            vars.profileId,
            vars.contentURI,
            vars.collectModule,
            vars.financeModule,
            vars.collectModuleInitData,
            vars.referenceModule,
            vars.referenceModuleInitData
        );
    }

    /// @inheritdoc IPoPPHub
    function mirror(DataTypes.MirrorData calldata vars)
    external
    override
    whenPublishingEnabled
    returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(vars.profileId);
        return _createMirror(vars);
    }

    /**
     * @notice Burns a profile, this maintains the profile data struct, but deletes the
     * handle hash to profile ID mapping value.
     *
     * NOTE: This overrides the PoPPNFTBase contract's `burn()` function and calls it to fully burn
     * the NFT.
     */
    function burn(uint256 tokenId) public override whenNotPaused {
        super.burn(tokenId);
        _clearHandleHash(tokenId);
    }

    /// ***************************************
    /// *****PROFILE INTERACTION FUNCTIONS*****
    /// ***************************************

    /// @inheritdoc IPoPPHub
    function follow(uint256 followerProfileId, uint256 profileId, bytes calldata data)
    external
    override
    whenNotPaused
    returns (uint256)
    {
        _validateCallerIsProfileOwnerOrDispatcher(followerProfileId);
        address erc6551Account = _getERC6551Account(followerProfileId);
        return
        InteractionLogic.follow(
            msg.sender,
            erc6551Account,
            profileId,
            data,
            _profileById,
            _profileIdByHandleHash
        );
    }

    /// @inheritdoc IPoPPHub
    function collect(
        uint256 collectorProfileId,
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external payable override whenNotPaused returns (uint256) {
        _validateCallerIsProfileOwnerOrDispatcher(collectorProfileId);
        (uint256 tokenId, uint256 rootProfileId, uint256 rootPubId) = InteractionLogic.collect(
            collectorProfileId,
            msg.sender,
            profileId,
            pubId,
            data,
            ECHO_NFT_ADDRESS,
            _pubByIdByProfile,
            _profileById
        );
        address erc6551Account = _getERC6551Account(collectorProfileId);
        uint256 echoId = _pubByIdByProfile[rootProfileId][rootPubId].echoId;
        IEchoNFT(ECHO_NFT_ADDRESS).mint(erc6551Account, echoId, 1);
        return tokenId;
    }

    /// @inheritdoc IPoPPHub
    function emitFollowNFTTransferEvent(
        uint256 profileId,
        uint256 followNFTId,
        address from,
        address to
    ) external override {
        address expectedFollowNFT = _profileById[profileId].followNFT;
        if (msg.sender != expectedFollowNFT) revert Errors.CallerNotFollowNFT();
        emit Events.FollowNFTTransferred(profileId, followNFTId, from, to, block.timestamp);
    }

    /// *********************************
    /// *****EXTERNAL VIEW FUNCTIONS*****
    /// *********************************

    /// @inheritdoc IPoPPHub
    function isProfileCreatorWhitelisted(address profileCreator)
    external
    view
    override
    returns (bool)
    {
        //return _profileCreatorWhitelisted[profileCreator];
        return true;
    }

    /// @inheritdoc IPoPPHub
    function defaultProfile(address wallet) external view override returns (uint256) {
        return _defaultProfileByAddress[wallet];
    }

    /// @inheritdoc IPoPPHub
    function isFollowModuleWhitelisted(address followModule) external view override returns (bool) {
        return _followModuleWhitelisted[followModule];
    }

    /// @inheritdoc IPoPPHub
    function isFinanceModuleWhitelisted(address financeModule) external view override returns (bool) {
        return _financeModuleWhitelisted[financeModule];
    }

    /// @inheritdoc IPoPPHub
    function isReferenceModuleWhitelisted(address referenceModule)
    external
    view
    override
    returns (bool)
    {
        return _referenceModuleWhitelisted[referenceModule];
    }

    /// @inheritdoc IPoPPHub
    function isCollectModuleWhitelisted(address collectModule)
    external
    view
    override
    returns (bool)
    {
        return _collectModuleWhitelisted[collectModule];
    }

    /// @inheritdoc IPoPPHub
    function getGovernance() external view override returns (address) {
        return _governance;
    }

    /// @inheritdoc IPoPPHub
    function getDispatcher(uint256 profileId) external view override returns (address) {
        return _dispatcherByProfile[profileId];
    }

    /// @inheritdoc IPoPPHub
    function getPubCount(uint256 profileId) external view override returns (uint256) {
        return _profileById[profileId].pubCount;
    }

    /// @inheritdoc IPoPPHub
    function getFollowNFT(uint256 profileId) external view override returns (address) {
        return _profileById[profileId].followNFT;
    }

    /// @inheritdoc IPoPPHub
    function getFollowNFTURI(uint256 profileId) external view override returns (string memory) {
        return _profileById[profileId].followNFTURI;
    }

    /// @inheritdoc IPoPPHub
    function getCollectNFT(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (uint256)
    {
        return _pubByIdByProfile[profileId][pubId].echoId;
    }

    function getMirrorNFT(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (uint256)
    {
        return _pubByIdByProfile[profileId][pubId].mirrorId;
    }

    /// @inheritdoc IPoPPHub
    function getFollowModule(uint256 profileId) external view override returns (address) {
        return _profileById[profileId].followModule;
    }

    /// @inheritdoc IPoPPHub
    function getCollectModule(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (address)
    {
        return _pubByIdByProfile[profileId][pubId].collectModule;
    }

    /// @inheritdoc IPoPPHub
    function getReferenceModule(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (address)
    {
        return _pubByIdByProfile[profileId][pubId].referenceModule;
    }

    /// @inheritdoc IPoPPHub
    function getHandle(uint256 profileId) external view override returns (string memory) {
        return _profileById[profileId].handle;
    }

    /// @inheritdoc IPoPPHub
    function getPubPointer(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (uint256, uint256)
    {
        uint256 profileIdPointed = _pubByIdByProfile[profileId][pubId].profileIdPointed;
        uint256 pubIdPointed = _pubByIdByProfile[profileId][pubId].pubIdPointed;
        return (profileIdPointed, pubIdPointed);
    }

    /// @inheritdoc IPoPPHub
    function getContentURI(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (string memory)
    {
        (uint256 rootProfileId, uint256 rootPubId,) = Helpers.getPointedIfMirror(
            profileId,
            pubId,
            _pubByIdByProfile
        );
        return _pubByIdByProfile[rootProfileId][rootPubId].contentURI;
    }

    /// @inheritdoc IPoPPHub
    function getProfileIdByHandle(string calldata handle) external view override returns (uint256) {
        bytes32 handleHash = keccak256(bytes(handle));
        return _profileIdByHandleHash[handleHash];
    }

    /// @inheritdoc IPoPPHub
    function getProfile(uint256 profileId)
    external
    view
    override
    returns (DataTypes.ProfileStruct memory)
    {
        return _profileById[profileId];
    }

    /// @inheritdoc IPoPPHub
    function getPub(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (DataTypes.PublicationStruct memory)
    {
        return _pubByIdByProfile[profileId][pubId];
    }

    /// @inheritdoc IPoPPHub
    function getPubType(uint256 profileId, uint256 pubId)
    external
    view
    override
    returns (DataTypes.PubType)
    {
        if (pubId == 0 || _profileById[profileId].pubCount < pubId) {
            return DataTypes.PubType.Nonexistent;
        } else if (_pubByIdByProfile[profileId][pubId].collectModule == address(0)) {
            return DataTypes.PubType.Mirror;
        } else if (_pubByIdByProfile[profileId][pubId].profileIdPointed == 0) {
            return DataTypes.PubType.Post;
        } else {
            return DataTypes.PubType.Comment;
        }
    }

    /**
     * @dev Overrides the ERC721 tokenURI function to return the associated URI with a given profile.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address followNFT = _profileById[tokenId].followNFT;
        return
        ProfileTokenURILogic.getProfileTokenURI(
            tokenId,
            followNFT == address(0) ? 0 : IERC721Enumerable(followNFT).totalSupply(),
            ownerOf(tokenId),
            _profileById[tokenId].handle,
            _profileById[tokenId].imageURI
        );
    }

    function imageURI(uint256 tokenId) public view override returns (string memory) {
        return _profileById[tokenId].imageURI;
    }

    /// @inheritdoc IPoPPHub
    function getFollowNFTImpl() external view override returns (address) {
        return FOLLOW_NFT_IMPL;
    }

    function getFinancePoolImpl() external view override returns (address) {
        return FINANCE_POOL_ADDRESS;
    }

    /// @inheritdoc IPoPPHub
    function getEchoNFTImpl() external view override returns (address) {
        return ECHO_NFT_ADDRESS;
    }

    function getMirrorNFTImpl() external view override returns (address) {
        return MIRROR_NFT_ADDRESS;
    }

    /// @inheritdoc IPoPPHub
    function getERC6551Account(uint256 profileId) external view returns (address){
        return _getERC6551Account(profileId);
    }

    function _getERC6551Account(uint256 profileId) internal view returns (address){
        return IERC6551Registry(ERC6551_REGISTRY).account(ERC6551_ACCOUNT_IMPL, ERC6551_SALT, block.chainid, address(this), profileId);
    }

    function _isFollowing(uint256 followerProfileId, uint256 followedProfileId) internal view returns (bool) {
        address followNFT = _profileById[followedProfileId].followNFT;
        if (followNFT == address(0)){
            return false;
        }
        address erc6551Account = _getERC6551Account(followerProfileId);
        return IERC721(followNFT).balanceOf(erc6551Account) > 0;
    }

    /// ****************************
    /// *****INTERNAL FUNCTIONS*****
    /// ****************************

    function _setGovernance(address newGovernance) internal {
        address prevGovernance = _governance;
        _governance = newGovernance;
        emit Events.GovernanceSet(msg.sender, prevGovernance, newGovernance, block.timestamp);
    }

    function _createPost(
        uint256 profileId,
        string memory contentURI,
        address collectModule,
        address financeModule,
        bytes memory collectModuleData,
        address referenceModule,
        bytes memory referenceModuleData
    ) internal returns (uint256) {
    unchecked {
        uint256 pubId = ++_profileById[profileId].pubCount;
        if (!_financeModuleWhitelisted[financeModule]) revert Errors.FinanceModuleNotWhitelisted();
        PublishingLogic.createPost(
            profileId,
            contentURI,
            collectModule,
            financeModule,
            collectModuleData,
            referenceModule,
            referenceModuleData,
            pubId,
            _pubByIdByProfile,
            _collectModuleWhitelisted,
            _referenceModuleWhitelisted
        );
        uint256 echoId = IEchoNFT(ECHO_NFT_ADDRESS).setTokenIdTokenUri(profileId, pubId, contentURI);
        _pubByIdByProfile[profileId][pubId].echoId = echoId;
        return pubId;
    }
    }

    /*
     * If the profile ID is zero, this is the equivalent of "unsetting" a default profile.
     * Note that the wallet address should either be the message sender or validated via a signature
     * prior to this function call.
     */
    function _setDefaultProfile(address wallet, uint256 profileId) internal {
        if (profileId > 0 && wallet != ownerOf(profileId)) revert Errors.NotProfileOwner();

        _defaultProfileByAddress[wallet] = profileId;

        emit Events.DefaultProfileSet(wallet, profileId, block.timestamp);
    }

    function _createMirror(DataTypes.MirrorData memory vars) internal returns (uint256) {
    unchecked {
        uint256 pubId = ++_profileById[vars.profileId].pubCount;
        (uint256 rootProfileIdPointed, uint256 rootPubIdPointed) = PublishingLogic.createMirror(
            vars,
            pubId,
            _pubByIdByProfile,
            _referenceModuleWhitelisted
        );
        address erc6551Account = _getERC6551Account(vars.profileId);
        uint256 mirrorNFTTokenId = IMirrorNFT(MIRROR_NFT_ADDRESS)
            .mint(erc6551Account, rootProfileIdPointed, rootPubIdPointed, _pubByIdByProfile[rootProfileIdPointed][rootPubIdPointed].contentURI);
        if (_pubByIdByProfile[rootProfileIdPointed][rootPubIdPointed].mirrorId == 0){
            _pubByIdByProfile[rootProfileIdPointed][rootPubIdPointed].mirrorId = mirrorNFTTokenId;
        }
        if (_pubByIdByProfile[vars.profileIdPointed][vars.pubIdPointed].mirrorId == 0) {
            _pubByIdByProfile[vars.profileIdPointed][vars.pubIdPointed].mirrorId = mirrorNFTTokenId;
        }
        _pubByIdByProfile[vars.profileId][pubId].mirrorId = mirrorNFTTokenId;
        return pubId;
    }
    }

    function _setDispatcher(uint256 profileId, address dispatcher) internal {
        _dispatcherByProfile[profileId] = dispatcher;
        emit Events.DispatcherSet(profileId, dispatcher, block.timestamp);
    }

    function _setProfileImageURI(uint256 profileId, string calldata imageURI) internal {
        if (bytes(imageURI).length > Constants.MAX_PROFILE_IMAGE_URI_LENGTH)
            revert Errors.ProfileImageURILengthInvalid();
        _profileById[profileId].imageURI = imageURI;
        emit Events.ProfileImageURISet(profileId, imageURI, block.timestamp);
    }

    function _setFollowNFTURI(uint256 profileId, string calldata followNFTURI) internal {
        _profileById[profileId].followNFTURI = followNFTURI;
        emit Events.FollowNFTURISet(profileId, followNFTURI, block.timestamp);
    }

    function _clearHandleHash(uint256 profileId) internal {
        bytes32 handleHash = keccak256(bytes(_profileById[profileId].handle));
        _profileIdByHandleHash[handleHash] = 0;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override whenNotPaused {
        if (_dispatcherByProfile[tokenId] != address(0)) {
            _setDispatcher(tokenId, address(0));
        }

        if (_defaultProfileByAddress[from] == tokenId) {
            _defaultProfileByAddress[from] = 0;
        }

        super._beforeTokenTransfer(from, to, tokenId);
    }

    function _validateCallerIsProfileOwnerOrDispatcher(uint256 profileId) internal view {
        if (msg.sender == ownerOf(profileId) || msg.sender == _dispatcherByProfile[profileId]) {
            return;
        }
        revert Errors.NotProfileOwnerOrDispatcher();
    }

    function _validateCallerIsProfileOwner(uint256 profileId) internal view {
        if (msg.sender != ownerOf(profileId)) revert Errors.NotProfileOwner();
    }

    function _validateCallerIsGovernance() internal view {
        if (msg.sender != _governance) revert Errors.NotGovernance();
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return REVISION;
    }

    function getEchoNftAddress()  external view returns (address){
        return ECHO_NFT_ADDRESS;
    }

    function isFollowing(uint256 followerProfileId, uint256 followedProfileId) external view returns (bool) {
        return _isFollowing(followerProfileId, followedProfileId);
    }
}
