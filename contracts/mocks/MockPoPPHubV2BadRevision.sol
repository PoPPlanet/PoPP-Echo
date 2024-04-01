// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

import {IPoPPHub} from '../interfaces/IPoPPHub.sol';
import {Events} from '../libraries/Events.sol';
import {Helpers} from '../libraries/Helpers.sol';
import {DataTypes} from '../libraries/DataTypes.sol';
import {Errors} from '../libraries/Errors.sol';
import {PublishingLogic} from '../libraries/PublishingLogic.sol';
import {InteractionLogic} from '../libraries/InteractionLogic.sol';
import {PoPPNFTBase} from '../core/base/PoPPNFTBase.sol';
import {PoPPMultiState} from '../core/base/PoPPMultiState.sol';
import {VersionedInitializable} from '../upgradeability/VersionedInitializable.sol';
import {MockPoPPHubV2Storage} from './MockPoPPHubV2Storage.sol';

/**
 * @dev A mock upgraded PoPPHub contract that is used to validate that the initializer cannot be called with the same revision.
 */
contract MockPoPPHubV2BadRevision is
    PoPPNFTBase,
    VersionedInitializable,
    PoPPMultiState,
    MockPoPPHubV2Storage
{
    uint256 internal constant REVISION = 1; // Should fail the initializer check

    function initialize(uint256 newValue) external initializer {
        _additionalValue = newValue;
    }

    function setAdditionalValue(uint256 newValue) external {
        _additionalValue = newValue;
    }

    function getAdditionalValue() external view returns (uint256) {
        return _additionalValue;
    }

    function getRevision() internal pure virtual override returns (uint256) {
        return REVISION;
    }
}
