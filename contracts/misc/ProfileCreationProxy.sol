// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IPoPPHub} from '../interfaces/IPoPPHub.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title ProfileCreationProxy
 * @author PoPP Protocol
 *
 * @notice This is an ownable proxy contract that enforces ".PoPP" handle suffixes at profile creation.
 * Only the owner can create profiles.
 */
contract ProfileCreationProxy is Ownable {
    IPoPPHub immutable POPP_HUB;

    constructor(address owner, IPoPPHub hub) {
        _transferOwnership(owner);
        POPP_HUB = hub;
    }

    function proxyCreateProfile(DataTypes.CreateProfileData memory vars) external onlyOwner {
        uint256 handleLength = bytes(vars.handle).length;
        if (handleLength < 5) revert Errors.HandleLengthInvalid();

        bytes1 firstByte = bytes(vars.handle)[0];
        if (firstByte == '-' || firstByte == '_' || firstByte == '.')
            revert Errors.HandleFirstCharInvalid();

        for (uint256 i = 1; i < handleLength; ) {
            if (bytes(vars.handle)[i] == '.') revert Errors.HandleContainsInvalidCharacters();
            unchecked {
                ++i;
            }
        }

        vars.handle = string(abi.encodePacked(vars.handle, '.PoPP'));
        POPP_HUB.createProfile(vars);
    }
}
