// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {VersionedInitializable} from '../upgradeability/VersionedInitializable.sol';
import {IPoPPHub} from '../interfaces/IPoPPHub.sol';
import {IFollowModule} from '../interfaces/IFollowModule.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {IERC1155} from '@openzeppelin/contracts/token/ERC1155/IERC1155.sol';

/**
 * @title AccessControl
 * @author PoPP Protocol
 *
 * @notice This contract enables additional access control for encrypted publications on PoPP by reporting whether
 *      an address owns or has control over a given profile.
 */
contract AccessControlV2 is VersionedInitializable {
    uint256 internal constant REVISION = 2;

    address internal immutable POPP_HUB;

    constructor(address _poppHub) {
        POPP_HUB = _poppHub;
    }

    function initialize() external initializer {}

    /**
     * @dev Function used to check whether an address is the owner of a profile.
     *
     * @param requestorAddress The address to check ownership over a profile.
     * @param profileId The ID of the profile being checked for ownership.
     * @param data Optional data parameter, which may be used in future upgrades.
     * @return Boolean indicating whether address owns the profile or not.
     */
    function hasAccess(
        address requestorAddress,
        uint256 profileId,
        bytes memory data
    ) external view returns (bool) {
        return IERC721(POPP_HUB).ownerOf(profileId) == requestorAddress;
    }

    function hasCollected(
        address requestorAddress,
        uint256 publisherId,
        uint256 pubId,
        uint256 collectorProfileId,
        bytes memory data
    ) external view returns (bool) {
        uint256 echoId = IPoPPHub(POPP_HUB).getCollectNFT(publisherId, pubId);

        return IERC1155(IPoPPHub(POPP_HUB).getEchoNftAddress()).balanceOf(requestorAddress, echoId)>0;
    }

    function isFollowing(
        address requestorAddress,
        uint256 profileId,
        uint256 followerProfileId,
        bytes memory data
    ) external view returns (bool) {
        address followModule = IPoPPHub(POPP_HUB).getFollowModule(profileId);
        bool following;
        if (followModule != address(0)) {
            following = IFollowModule(followModule).isFollowing(profileId, requestorAddress, 0);
        } else {
            address followNFT = IPoPPHub(POPP_HUB).getFollowNFT(profileId);
            following =
                followNFT != address(0) &&
                IERC721(followNFT).balanceOf(requestorAddress) != 0;
        }
        return following || IERC721(POPP_HUB).ownerOf(profileId) == requestorAddress;
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return REVISION;
    }
}
