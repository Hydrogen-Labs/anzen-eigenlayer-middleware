// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import {IServiceManager} from "./interfaces/IServiceManager.sol";
import {IRegistryCoordinator} from "./interfaces/IRegistryCoordinator.sol";
import {IStakeRegistry} from "./interfaces/IStakeRegistry.sol";

import {IAVSDirectory} from "eigenlayer-contracts/src/contracts/interfaces/IAVSDirectory.sol";
import {IPaymentCoordinator} from
    "eigenlayer-contracts/src/contracts/interfaces/IPaymentCoordinator.sol";

/**
 * @title Storage variables for the `ServiceManagerBase` contract.
 * @author Layr Labs, Inc.
 * @notice This storage contract is separate from the logic to simplify the upgrade process.
 */
abstract contract ServiceManagerBaseStorage is IServiceManager {
    /**
     *
     *                            CONSTANTS AND IMMUTABLES
     *
     */
    IAVSDirectory internal immutable _avsDirectory;
    IPaymentCoordinator internal immutable _paymentCoordinator;
    IRegistryCoordinator internal immutable _registryCoordinator;
    IStakeRegistry internal immutable _stakeRegistry;

    /**
     *
     *                            STATE VARIABLES
     *
     */

    /// @notice The address of the entity that can initiate payments
    address public paymentInitiator;

    /// @notice Sets the (immutable) `_avsDirectory`, `_paymentCoordinator`, `_registryCoordinator`, and `_stakeRegistry` addresses
    constructor(
        IAVSDirectory __avsDirectory,
        IPaymentCoordinator __paymentCoordinator,
        IRegistryCoordinator __registryCoordinator,
        IStakeRegistry __stakeRegistry
    ) {
        _avsDirectory = __avsDirectory;
        _paymentCoordinator = __paymentCoordinator;
        _registryCoordinator = __registryCoordinator;
        _stakeRegistry = __stakeRegistry;
    }

    // storage gap for upgradeability
    uint256[49] private __GAP;
}