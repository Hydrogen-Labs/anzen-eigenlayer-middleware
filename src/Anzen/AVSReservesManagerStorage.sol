// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IPaymentCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IPaymentCoordinator.sol";

import {IAVSReservesManager} from "./interfaces/IAVSReservesManager.sol";
import {ISafetyFactorOracle} from "./interfaces/ISafetyFactorOracle.sol";

import "./libraries/Accumulator.sol";

// The AVSReservesManager contract is responsible for managing the token flow to the Service Manager contract
// It is also responsible for updating the token flow based on the Safety Factor
// The Safety Factor is determined by the Safety Factor Oracle contract which represents the protocol's attack surface health

// The reserves manager serves as a 'battery' for the Service Manager contract:
// Storing excess tokens when the protocol is healthy and releasing them when the protocol is in need of more security
abstract contract AVSReservesManagerStorage is IAVSReservesManager {
    SafetyFactorConfig public safetyFactorConfig; // Safety Factor configuration
    uint256 public performanceFeeBPS = 300; // Performance-based fee
    address[] public rewardTokens; // List of reward tokens

    mapping(address => Accumulator) public rewardTokenAccumulator; // mapping of reward tokens to Safety Factor Updaters
    mapping(address => IPaymentCoordinator.StrategyAndMultiplier[])
        public strategyAndMultipliers; // mapping of reward tokens to payments (for future use

    uint32 public lastPaymentTimestamp; // Timestamp of the last payment
    uint256 public lastEpochUpdateTimestamp;

    address public protocol; // Address of the protocol in Anzen
    address public anzen; // Address of the Anzen contract

    ISafetyFactorOracle public safetyFactorOracle; // Address of the Safety Factor Oracle contract

    uint256[39] private __GAP;
}
