// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IPoPPHub} from '../../../interfaces/IPoPPHub.sol';
import {IReferenceModule} from '../../../interfaces/IReferenceModule.sol';
import {ModuleBase} from '../ModuleBase.sol';
import {FollowValidationModuleBase} from '../FollowValidationModuleBase.sol';
import {Errors} from '../../../libraries/Errors.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';

/**
 * @title FollowerOnlyReferenceModule
 * @author PoPP Protocol
 *
 * @notice A simple reference module that validates that comments or mirrors originate from a profile owned
 * by a follower.
 */
contract BaseReferenceModule is FollowValidationModuleBase, IReferenceModule {
    constructor(address hub) ModuleBase(hub) {}

    /**
     * @dev There is nothing needed at initialization.
     */
    function initializeReferenceModule(
        uint256 profileId,
        uint256 pubId,
        bytes calldata data
    ) external pure override returns (bytes memory) {
        return new bytes(0);
    }

    /**
     * @notice Validates that the commenting profile's owner is a follower.
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processComment(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {

    }

    /**
     * @notice Validates that the commenting profile's owner is a follower.
     *
     * NOTE: We don't need to care what the pointed publication is in this context.
     */
    function processMirror(
        uint256 profileId,
        uint256 profileIdPointed,
        uint256 pubIdPointed,
        bytes calldata data
    ) external view override {

    }
}
