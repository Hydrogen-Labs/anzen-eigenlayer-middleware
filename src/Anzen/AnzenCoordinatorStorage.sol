// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IPaymentCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IPaymentCoordinator.sol";

import {IAVSReservesManager} from "./interfaces/IAVSReservesManager.sol";
import {ISafetyFactorOracle} from "./interfaces/ISafetyFactorOracle.sol";

// The AVSReservesManager contract is responsible for managing the token flow to the Service Manager contract
// It is also responsible for updating the token flow based on the Safety Factor
// The Safety Factor is determined by the Safety Factor Oracle contract which represents the protocol's attack surface health

// The reserves manager serves as a 'battery' for the Service Manager contract:
// Storing excess tokens when the protocol is healthy and releasing them when the protocol is in need of more security
abstract contract AnzenCoordinatorStorage {

}
