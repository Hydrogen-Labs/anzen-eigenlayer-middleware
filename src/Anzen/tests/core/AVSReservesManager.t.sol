//SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.12;

import "forge-std/Test.sol";
import "forge-std/console.sol";

import "../../static/Structs.sol";
import "../../AVSReservesManager.sol";
import "../harnesses/AVSReservesManagerHarness.sol";

import "eigenlayer-contracts/src/contracts/interfaces/IStrategy.sol";
// Mocks
import "../mocks/MockSafetyFactorOracle.sol";
import "../mocks/MockERC20.sol";

contract AVSReservesManagerTests is Test {
    AVSReservesManagerHarness public reservesManager;
    MockSafetyFactorOracle public safetyFactorOracle;
    SafetyFactorConfig public safetyFactorConfig;

    address public anzenGov;
    address public avsGov;
    address public avsId;
    address public avsServiceManager;
    uint256 public performanceBPS;

    MockToken[] public rewardTokens;
    address[] public avsRewardTokens;
    uint256[] public initialTokenFlows;

    function setUp() public {
        safetyFactorOracle = new MockSafetyFactorOracle();

        anzenGov = address(0x555);
        avsGov = address(0x456);
        avsId = address(0x789);
        avsServiceManager = address(0x333);

        // a healthy safety factor in between the bounds
        int256 safetyFactorInit = (int256(PRECISION) * 130) / 100;
        safetyFactorOracle.mockSetSafetyFactor(avsId, safetyFactorInit);

        MockToken rewardToken1 = new MockToken("Token1", "TK1");
        MockToken rewardToken2 = new MockToken("Token2", "TK2");

        rewardTokens = [rewardToken1, rewardToken2];

        avsRewardTokens = new address[](2);
        avsRewardTokens[0] = address(rewardToken1);
        avsRewardTokens[1] = address(rewardToken2);

        initialTokenFlows = new uint256[](2);
        initialTokenFlows[0] = 100;
        initialTokenFlows[1] = 200;

        performanceBPS = 300;

        safetyFactorConfig = SafetyFactorConfig(
            (int256(PRECISION) * 120) / 100, // 120% of the current value
            (int256(PRECISION) * 140) / 100, // 140% of the current value
            (PRECISION * 95) / 100, // 95% of the current value
            (PRECISION * 105) / 10, // 105% of the current value
            3 days
        );

        vm.prank(anzenGov);
        reservesManager = new AVSReservesManagerHarness(
            safetyFactorConfig,
            performanceBPS,
            address(safetyFactorOracle),
            avsGov,
            avsId,
            avsServiceManager,
            avsRewardTokens,
            initialTokenFlows
        );
    }

    function test_constructor() public virtual {
        SafetyFactorConfig memory newConfig = reservesManager
            .getSafetyFactorConfig();

        assertEq(
            newConfig.TARGET_SF_LOWER_BOUND,
            safetyFactorConfig.TARGET_SF_LOWER_BOUND
        );
        assertEq(
            newConfig.TARGET_SF_UPPER_BOUND,
            safetyFactorConfig.TARGET_SF_UPPER_BOUND
        );
        assertEq(
            newConfig.REDUCTION_FACTOR,
            safetyFactorConfig.REDUCTION_FACTOR
        );
        assertEq(newConfig.INCREASE_FACTOR, safetyFactorConfig.INCREASE_FACTOR);
        assertEq(
            newConfig.minEpochDuration,
            safetyFactorConfig.minEpochDuration
        );
        assertEq(reservesManager.lastEpochUpdateTimestamp(), 1);

        // Loop through each reward token and perform assertions
        for (uint256 i = 0; i < avsRewardTokens.length; i++) {
            (
                uint256 claimableTokens,
                uint256 claimableFees,
                uint256 tokensPerSecond,
                uint256 prevTokensPerSecond,
                int256 lastSafetyFactor
            ) = reservesManager.rewardTokenAccumulator(avsRewardTokens[i]);

            // Assert that the values match the expected initial token flows and default values
            assertEq(tokensPerSecond, initialTokenFlows[i]);
            assertEq(prevTokensPerSecond, initialTokenFlows[i]);
            assertEq(claimableTokens, 0);
            assertEq(claimableFees, 0);
            assertEq(lastSafetyFactor, (int256(PRECISION) * 130) / 100);
        }
    }

    function test_updateFlow(uint256 timeElapsed) public {
        vm.assume(timeElapsed >= 3 days);
        vm.assume(timeElapsed < 180 days);

        vm.warp(timeElapsed + 1); // 1 second default start time

        reservesManager.updateFlow();

        // Loop through each reward token and perform assertions
        for (uint256 i = 0; i < avsRewardTokens.length; i++) {
            (
                uint256 claimableTokens,
                uint256 claimableFees,
                uint256 tokensPerSecond,
                uint256 prevTokensPerSecond,
                int256 safetyFactor
            ) = reservesManager.rewardTokenAccumulator(avsRewardTokens[i]);

            // Assert that the values match the expected initial token flows and default values
            assertEq(tokensPerSecond, initialTokenFlows[i]);
            assertEq(prevTokensPerSecond, initialTokenFlows[i]);
            assertEq(claimableFees, 0);
            assertEq(claimableTokens, timeElapsed * initialTokenFlows[i]);
            assertEq(safetyFactor, (int256(PRECISION) * 130) / 100);
        }

        assertEq(reservesManager.lastEpochUpdateTimestamp(), timeElapsed + 1);
    }

    function test_rejectUpdateBeforeEpoch(uint256 timeElapsed) public {
        vm.assume(timeElapsed < 3 days);

        vm.warp(timeElapsed + 1); // 1 second default start time

        vm.expectRevert("Epoch not yet expired");
        reservesManager.updateFlow();
    }

    function test_updateSafetyFactorParams() public {
        SafetyFactorConfig memory newConfig = SafetyFactorConfig(
            (int256(PRECISION) * 110) / 100,
            (int(PRECISION) * 150) / 100,
            (PRECISION * 90) / 100,
            (PRECISION * 110) / 10,
            4 days
        );

        vm.prank(avsGov);
        reservesManager.updateSafetyFactorParams(newConfig);

        SafetyFactorConfig memory updatedConfig = reservesManager
            .getSafetyFactorConfig();

        assertEq(
            updatedConfig.TARGET_SF_LOWER_BOUND,
            newConfig.TARGET_SF_LOWER_BOUND
        );
        assertEq(
            updatedConfig.TARGET_SF_UPPER_BOUND,
            newConfig.TARGET_SF_UPPER_BOUND
        );
        assertEq(updatedConfig.REDUCTION_FACTOR, newConfig.REDUCTION_FACTOR);
        assertEq(updatedConfig.INCREASE_FACTOR, newConfig.INCREASE_FACTOR);
        assertEq(updatedConfig.minEpochDuration, newConfig.minEpochDuration);
    }

    function test_rejectSafetyFactorConfigUpdateNotGov() public {
        SafetyFactorConfig memory newConfig = SafetyFactorConfig(
            (int256(PRECISION) * 110) / 100,
            (int(PRECISION) * 150) / 100,
            (PRECISION * 90) / 100,
            (PRECISION * 110) / 10,
            4 days
        );

        vm.expectRevert("Caller is not a AVS Gov");
        vm.prank(address(0x123)); // not the AVS Gov
        reservesManager.updateSafetyFactorParams(newConfig);
    }

    function test_adjustPerfomanceBPS(uint256 newFeeBps) public {
        vm.assume(newFeeBps <= MAX_PERFORMANCE_FEE_BPS);

        vm.prank(anzenGov);
        reservesManager.adjustFeeBps(newFeeBps);

        assertEq(reservesManager.performanceFeeBPS(), newFeeBps);
    }

    function rejects_adjustPerformanceBPSHigherThanMax(
        uint256 newFeeBps
    ) public {
        vm.assume(newFeeBps > MAX_PERFORMANCE_FEE_BPS);

        vm.expectRevert("Fee cannot be greater than 5%");
        vm.prank(anzenGov);
        reservesManager.adjustFeeBps(newFeeBps);
    }

    function test_addRewardToken(
        address newToken,
        uint256 newTokenFlow
    ) public {
        vm.assume(newToken != address(rewardTokens[0]));
        vm.assume(newToken != address(rewardTokens[1]));
        vm.assume(newTokenFlow > 0);
        vm.prank(avsGov);
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultiplier = new IPaymentCoordinator.StrategyAndMultiplier[](
                0
            );

        reservesManager.addRewardToken(
            newToken,
            newTokenFlow,
            strategyAndMultiplier
        );

        (
            uint256 claimableTokens,
            uint256 claimableFees,
            uint256 tokensPerSecond,
            uint256 prevTokensPerSecond,
            int256 lastSafetyFactor
        ) = reservesManager.rewardTokenAccumulator(newToken);

        assertEq(tokensPerSecond, newTokenFlow);
        assertEq(prevTokensPerSecond, newTokenFlow);
        assertEq(claimableTokens, 0);
        assertEq(claimableFees, 0);
        assertEq(lastSafetyFactor, (int256(PRECISION) * 130) / 100);
    }

    function test_rejectAddRewardTokenNotGov(
        address newToken,
        uint256 newTokenFlow
    ) public {
        vm.expectRevert("Caller is not a AVS Gov");
        vm.prank(address(0x123)); // not the AVS Gov
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultiplier = new IPaymentCoordinator.StrategyAndMultiplier[](
                0
            );

        reservesManager.addRewardToken(
            newToken,
            newTokenFlow,
            strategyAndMultiplier
        );
    }

    function test_rejectsAddRewardTokenAlreadyExists() public {
        vm.expectRevert("Reward token already exists");
        vm.prank(avsGov);
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultiplier = new IPaymentCoordinator.StrategyAndMultiplier[](
                0
            );

        reservesManager.addRewardToken(
            avsRewardTokens[0],
            123,
            strategyAndMultiplier
        );
    }

    function test_removeRewardToken() public {
        address tokenToRemove = avsRewardTokens[0];
        vm.prank(avsGov);
        reservesManager.removeRewardToken(tokenToRemove);

        address[] memory remainingTokens = reservesManager.getRewardTokens();

        assertEq(remainingTokens.length, 1);
        assertEq(remainingTokens[0], avsRewardTokens[1]);
    }

    function test_setStrategyAndMultiplier() public {
        address token = avsRewardTokens[0];
        uint256 numStrategies = 3;

        // Create an array of StrategyAndMultiplier with three elements
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory strategyAndMultiplier = new IPaymentCoordinator.StrategyAndMultiplier[](
                numStrategies
            );

        // Initialize the strategies with different addresses and multipliers
        for (uint256 i = 0; i < numStrategies; i++) {
            strategyAndMultiplier[i] = IPaymentCoordinator
                .StrategyAndMultiplier(
                    IStrategy(address(uint160(0x111 + i))),
                    uint96(i + 1)
                );
        }

        // Set the strategies using a prank to simulate the governance address
        vm.prank(avsGov);
        reservesManager.setStrategyAndMultipliers(token, strategyAndMultiplier);

        // Retrieve the strategies from the contract
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory newStrategyAndMultiplier = reservesManager
                .getStrategyAndMultipliers(token);

        // Assert that the lengths match
        assertEq(newStrategyAndMultiplier.length, numStrategies);

        // Assert each strategy and multiplier in a loop
        for (uint256 i = 0; i < numStrategies; i++) {
            assertEq(
                address(newStrategyAndMultiplier[i].strategy),
                address(strategyAndMultiplier[i].strategy)
            );
            assertEq(
                newStrategyAndMultiplier[i].multiplier,
                strategyAndMultiplier[i].multiplier
            );
        }
    }

    function test_overrideClaimableTokens(uint256 newClaimableTokens) public {
        address token = avsRewardTokens[0];
        vm.prank(avsGov);
        reservesManager.overrideClaimableTokens(token, newClaimableTokens);

        (
            uint256 claimableTokens,
            uint256 claimableFees,
            uint256 tokensPerSecond,
            uint256 prevTokensPerSecond,
            int256 lastSafetyFactor
        ) = reservesManager.rewardTokenAccumulator(token);

        assertEq(claimableTokens, newClaimableTokens);
        assertEq(claimableFees, 0);
        assertEq(tokensPerSecond, initialTokenFlows[0]);
        assertEq(prevTokensPerSecond, initialTokenFlows[0]);
        assertEq(lastSafetyFactor, (int256(PRECISION) * 130) / 100);
    }

    function test_createRangePaymentSufficientFundsInReserves(
        uint256 duration,
        uint256 totalAmount,
        uint256 amountInReserves
    ) public {
        uint256 claimableFees = totalAmount / 100;
        uint256 claimableAmount = totalAmount - claimableFees;
        vm.assume(duration > 1);
        vm.assume(duration < 180 days);
        vm.assume(claimableAmount > 0);
        vm.assume(claimableAmount + claimableFees < UINT256_MAX);
        vm.assume(claimableAmount + claimableFees <= amountInReserves);

        vm.warp(duration);
        rewardTokens[0].mint(address(reservesManager), amountInReserves);

        IPaymentCoordinator.RangePayment memory rangePayment = reservesManager
            .createRangePayment(
                rewardTokens[0],
                claimableAmount,
                claimableFees
            );

        assertEq(address(rangePayment.token), address(rewardTokens[0]));
        assertEq(rangePayment.amount, claimableAmount);
        assertEq(rangePayment.duration, duration - 1);
        assertEq(rangePayment.startTimestamp, 1);
    }

    function test_createRangePaymentInsufficientFundsInReserves(
        uint256 duration,
        uint256 totalAmount,
        uint256 amountInReserves
    ) public {
        uint256 claimableFees = totalAmount / 100;
        uint256 claimableAmount = totalAmount - claimableFees;

        vm.assume(duration > 1);
        vm.assume(duration < 180 days);
        vm.assume(claimableAmount + claimableFees > amountInReserves);

        vm.warp(duration);
        rewardTokens[0].mint(address(reservesManager), amountInReserves);

        vm.expectRevert("Insufficient balance");
        reservesManager.createRangePayment(
            rewardTokens[0],
            claimableAmount,
            claimableFees
        );
    }
}
