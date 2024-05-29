// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "./static/Structs.sol";
import {ISafetyFactorOracle} from "./interfaces/ISafetyFactorOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

abstract contract SafetyFactorOracleStorage is ISafetyFactorOracle, Ownable {
    mapping(address => SafetyFactorSnapshot) public safetyFactorSnapshots; // Safety Factor snapshots for each protocol
    mapping(address => ProposedSafetyFactorSnapshot)
        public proposedSafetyFactorSnapshots; // Proposed Safety Factor snapshots for each protocol

    // May need to update this to be weighted based on stake
    mapping(address => bool) public signers; // Signers for the Safety Factor update
    mapping(address => mapping(address => uint256)) public lastSignTimes; // Last time a signer signed (to prevent double signing)

    uint64 public quorum; // Quorum for the Safety Factor update
}
