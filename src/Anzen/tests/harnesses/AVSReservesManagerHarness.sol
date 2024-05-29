// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../AVSReservesManager.sol";

// wrapper around the AVSReservesManager contract that exposes the internal functions for unit testing.
contract AVSReservesManagerHarness is AVSReservesManager {
    constructor(
        SafetyFactorConfig memory _safetyFactorConfig,
        uint256 _performanceFeeBPS,
        address _safetyFactorOracle,
        address _avsGov,
        address _protocolId,
        address _avsServiceManager,
        address[] memory _rewardTokens,
        uint256[] memory _initial_tokenFlowsPerSecond
    )
        AVSReservesManager(
            _safetyFactorConfig,
            _performanceFeeBPS,
            _safetyFactorOracle,
            _avsGov,
            _protocolId,
            _avsServiceManager,
            _rewardTokens,
            _initial_tokenFlowsPerSecond
        )
    {}

    function getSafetyFactorConfig()
        external
        view
        returns (SafetyFactorConfig memory)
    {
        return safetyFactorConfig;
    }

    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    function getStrategyAndMultipliers(
        address _rewardToken
    )
        external
        view
        returns (IPaymentCoordinator.StrategyAndMultiplier[] memory)
    {
        return strategyAndMultipliers[_rewardToken];
    }

    function createRangePayment(
        IERC20 _rewardToken,
        uint256 _claimableAmount,
        uint256 _fee
    ) external view returns (IPaymentCoordinator.RangePayment memory) {
        return _createRangePayment(_rewardToken, _claimableAmount, _fee);
    }

    function createAllRangePayments()
        external
        returns (IPaymentCoordinator.RangePayment[] memory)
    {
        return _createAllRangePayments();
    }
}
