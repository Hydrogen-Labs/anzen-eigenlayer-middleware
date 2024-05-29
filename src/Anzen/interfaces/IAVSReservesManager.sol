// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../static/Structs.sol";

interface IAVSReservesManager {
    // Event declaration
    event TokenFlowUpdated(uint256 newTokenFlow);
    event TokensTransferredToPaymentMaster(uint256 totalTokenTransfered);

    function updateFlow() external;

    // function transferToPaymentManager() external;

    function overrideTokensPerSecond(
        uint256[] memory newTokensPerSecond
    ) external;

    function updateSafetyFactorParams(
        SafetyFactorConfig memory newSafetyFactorConfig
    ) external;

    // Use this function to get the amount of tokens that can be claimed by the AVS
}
