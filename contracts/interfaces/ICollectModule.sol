// SPDX-License-Identifier: MIT

pragma solidity 0.8.10;

/**
 * @title ICollectModule
 * @author PoPP Protocol
 *
 * @notice This is the standard interface for all PoPP-compatible CollectModules.
 */
interface ICollectModule {

    struct CollectInfo {
        address collector;
        uint256 collectorProfileId;
        uint256 referrerProfileId;
        uint256 profileId;
        uint256 pubId;
        address financePool;
    }
    /**
     * @notice Initializes data for a given publication being published. This can only be called by the hub.
     *
     * @param profileId The token ID of the profile publishing the publication.
     * @param pubId The associated publication's PoPPHub publication ID.
     * @param data Arbitrary data __passed from the user!__ to be decoded.
     *
     * @return bytes An abi encoded byte array encapsulating the execution's state changes. This will be emitted by the
     * hub alongside the collect module's address and should be consumed by front ends.
     */
    function initializePublicationCollectModule(
        uint256 profileId,
        uint256 pubId,
        address financeModule,
        bytes calldata data
    ) external returns (bytes memory);

    function processCollect(
        CollectInfo calldata params,
        bytes calldata data
    ) external payable;

    function collectPrice(uint256 profileId, uint256 pubId) external view returns(uint256, address);

    function setCollectPriceRatesAddress(address _collectPriceRatesAddress) external;
}
