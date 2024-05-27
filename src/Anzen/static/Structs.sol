// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

uint256 constant BPS_DENOMINATOR = 10_000; // 10,000
uint256 constant MAX_PERFORMANCE_FEE_BPS = 500; // 5%
uint256 constant PRECISION = 10 ** 9; // Precision for tokenFlow

bytes32 constant ANZEN_GOV_ROLE = keccak256("ANZEN_GOV_ROLE");
bytes32 constant AVS_GOV_ROLE = keccak256("AVS_GOV_ROLE");

enum SafetyFactorStatus {
    Operational,
    Inactive
}

struct SafetyFactorConfig {
    int256 TARGET_SF_LOWER_BOUND;
    int256 TARGET_SF_UPPER_BOUND;
    uint256 REDUCTION_FACTOR;
    uint256 INCREASE_FACTOR;
    uint256 minEpochDuration;
}

struct Accumulator {
    uint256 claimableTokens;
    uint256 claimableFees;
    uint256 tokensPerSecond;
    uint256 prevTokensPerSecond;
    int256 lastSafetyFactor;
}

enum Status {
    Rejected,
    Pending,
    Approved
}
struct SafetyFactorSnapshot {
    int256 safetyFactor;
    uint256 timestamp;
}
struct ProposedSafetyFactorSnapshot {
    int256 safetyFactor;
    uint64 approved;
    uint64 rejected;
    Status status;
    uint256 timestamp;
}
