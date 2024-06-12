// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import {IPaymentCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IPaymentCoordinator.sol";

import {IAVSReservesManager} from "./interfaces/IAVSReservesManager.sol";
import {AVSReservesManagerStorage} from "./AVSReservesManagerStorage.sol";

import {ISafetyFactorOracle} from "./interfaces/ISafetyFactorOracle.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

import "./static/Structs.sol";
import "./libraries/Accumulator.sol";

import "forge-std/console.sol";

// The AVSReservesManager contract is responsible for managing the token flow to the Service Manager contract
// It is also responsible for updating the token flow based on the Safety Factor
// The Safety Factor is determined by the Safety Factor Oracle contract which represents the protocol's attack surface health

// The reserves manager serves as a 'battery' for the Service Manager contract:
// Storing excess tokens when the protocol is healthy and releasing them when the protocol is in need of more security
contract AnzenCoordinator is AccessControl {
    using SafeERC20 for IERC20;
    using AccumulatorLib for Accumulator;

    /**
     *
     *                            Immutables
     *
     */

    /**
     *
     *                            Modifiers
     *
     */

    modifier onlyAvsGov() {
        require(hasRole(AVS_GOV_ROLE, msg.sender), "Caller is not a AVS Gov");
        _;
    }

    modifier onlyAnzenGov() {
        require(
            hasRole(ANZEN_GOV_ROLE, msg.sender),
            "Caller is not a Anzen Gov"
        );
        _;
    }
}
