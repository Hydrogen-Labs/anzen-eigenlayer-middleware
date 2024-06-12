// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;
import "forge-std/console.sol";
import {Accumulator, SafetyFactorConfig, BPS_DENOMINATOR, PRECISION, MAX_PERFORMANCE_FEE_BPS} from "../static/Structs.sol";

library AccumulatorLib {
    function init(
        Accumulator storage accumulator,
        uint256 tokensPerSecond,
        int256 initSafetyFactor
    ) external {
        accumulator.tokensPerSecond = tokensPerSecond;
        accumulator.prevTokensPerSecond = tokensPerSecond;
        accumulator.lastSafetyFactor = initSafetyFactor;
    }

    function adjustEpochFlow(
        Accumulator storage accumulator,
        SafetyFactorConfig memory config,
        int256 currentSafetyFactor,
        uint256 performanceFeeBPS,
        uint256 lastEpochUpdateTimestamp
    ) external {
        _adjustClaimableTokens(
            accumulator,
            performanceFeeBPS,
            lastEpochUpdateTimestamp
        );

        if (accumulator.lastSafetyFactor == currentSafetyFactor) {
            return;
        }

        uint256 prevTokensPerSecond = accumulator.tokensPerSecond;

        uint256 newTokensPerSecond;
        // Todo: make this linearly interpolate with these max and min bounds
        // This will be basically "newton's method" to converge to the target safety factor

        if (currentSafetyFactor > config.TARGET_SF_UPPER_BOUND) {
            newTokensPerSecond =
                (accumulator.tokensPerSecond * config.REDUCTION_FACTOR) /
                PRECISION;
        } else if (currentSafetyFactor < config.TARGET_SF_LOWER_BOUND) {
            newTokensPerSecond =
                accumulator.tokensPerSecond +
                (accumulator.tokensPerSecond * config.INCREASE_FACTOR) /
                PRECISION;
        } else {
            newTokensPerSecond = accumulator.tokensPerSecond;
        }

        accumulator.tokensPerSecond = newTokensPerSecond;
        accumulator.prevTokensPerSecond = prevTokensPerSecond;
    }

    function claim(
        Accumulator storage accumulator,
        uint256 performanceFeeBPS,
        uint256 lastEpochUpdateTimestamp
    ) external returns (uint256, uint256) {
        _adjustClaimableTokens(
            accumulator,
            performanceFeeBPS,
            lastEpochUpdateTimestamp
        );

        uint256 claimableTokens = accumulator.claimableTokens;
        uint256 claimableFees = accumulator.claimableFees;

        accumulator.claimableTokens = 0;
        accumulator.claimableFees = 0;

        return (claimableTokens, claimableFees);
    }

    function overrideTokensPerSecond(
        Accumulator storage accumulator,
        uint256 tokensPerSecond,
        uint256 lastEpochUpdateTimestamp
    ) external {
        _adjustClaimableTokens(accumulator, 0, lastEpochUpdateTimestamp);

        accumulator.tokensPerSecond = tokensPerSecond;
        accumulator.prevTokensPerSecond = tokensPerSecond;
    }

    function overrideClaimableTokens(
        Accumulator storage accumulator,
        uint256 claimableTokens
    ) external {
        accumulator.claimableTokens = claimableTokens;
    }

    function _calculateClaimableTokensAndFee(
        Accumulator memory accumulator,
        uint256 performanceFeeBPS,
        uint256 currentTimestamp,
        uint256 lastEpochUpdateTimestamp
    ) internal pure returns (uint256 tokensGained, uint256 fee) {
        uint256 elapsedTime = currentTimestamp - lastEpochUpdateTimestamp;

        if (accumulator.prevTokensPerSecond > accumulator.tokensPerSecond) {
            uint256 tokensSaved = elapsedTime *
                (accumulator.prevTokensPerSecond - accumulator.tokensPerSecond);
            fee = (tokensSaved * performanceFeeBPS) / BPS_DENOMINATOR;
        }

        tokensGained = (elapsedTime * accumulator.tokensPerSecond) - fee;
    }

    function _adjustClaimableTokens(
        Accumulator storage accumulator,
        uint256 performanceFeeBPS,
        uint256 lastEpochUpdateTimestamp
    ) internal {
        (uint256 tokensGained, uint256 fee) = _calculateClaimableTokensAndFee(
            accumulator,
            performanceFeeBPS,
            block.timestamp,
            lastEpochUpdateTimestamp
        );

        accumulator.claimableTokens += tokensGained;
        accumulator.claimableFees += fee;
    }
}
