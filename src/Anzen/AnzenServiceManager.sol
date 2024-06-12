// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

import "eigenlayer-contracts/src/contracts/libraries/BytesLib.sol";
import "./interfaces/IAnzenTaskManager.sol";
import "../ServiceManagerBase.sol";

contract AnzenServiceManager is ServiceManagerBase {
    using BytesLib for bytes;

    IAnzenTaskManager public immutable anzenTaskManager;

    /// @notice when applied to a function, ensures that the function is only callable by the `registryCoordinator`.
    modifier onlyAnzenTaskManager() {
        require(
            msg.sender == address(anzenTaskManager),
            "onlyAnzenTaskManager: not from anzen task manager"
        );
        _;
    }

    constructor(
        IAVSDirectory _avsDirectory,
        IRegistryCoordinator _registryCoordinator,
        IStakeRegistry _stakeRegistry,
        IPaymentCoordinator _paymentCoordinator,
        IAnzenTaskManager _anzenTaskManager
    )
        ServiceManagerBase(
            _avsDirectory,
            _paymentCoordinator,
            _registryCoordinator,
            _stakeRegistry
        )
    {
        anzenTaskManager = _anzenTaskManager;
    }

    /// @notice Called in the event of challenge resolution, in order to forward a call to the Slasher, which 'freezes' the `operator`.
    /// @dev The Slasher contract is under active development and its interface expected to change.
    ///      We recommend writing slashing logic without integrating with the Slasher at this point in time.
    function freezeOperator(
        address operatorAddr
    ) external onlyAnzenTaskManager {
        // slasher.freezeOperator(operatorAddr);
    }
}
