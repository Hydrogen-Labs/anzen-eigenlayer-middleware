// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import {IPaymentCoordinator} from "eigenlayer-contracts/src/contracts/interfaces/IPaymentCoordinator.sol";

import {IAVSReservesManager} from "./interfaces/IAVSReservesManager.sol";
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
contract AVSReservesManager is IAVSReservesManager, AccessControl {
    using SafeERC20 for IERC20;
    using AccumulatorLib for Accumulator;

    // State variables
    SafetyFactorConfig public safetyFactorConfig; // Safety Factor configuration
    uint256 public performanceFeeBPS = 300; // Performance-based fee
    address[] public rewardTokens; // List of reward tokens
    mapping(address => Accumulator) public rewardTokenAccumulator; // mapping of reward tokens to Safety Factor Updaters
    mapping(address => IPaymentCoordinator.StrategyAndMultiplier[])
        public strategyAndMultipliers; // mapping of reward tokens to payments (for future use
    // public rewardTokenPayments; // mapping of reward tokens to payments (for future use

    uint32 public lastPaymentTimestamp; // Timestamp of the last payment
    uint256 public lastEpochUpdateTimestamp;
    address public protocol; // Address of the protocol in Anzen
    address public anzen; // Address of the Anzen contract

    IServiceManager public avsServiceManager; // Address of the Service Manager contract
    ISafetyFactorOracle public safetyFactorOracle; // Address of the Safety Factor Oracle contract

    /**
     *
     *                            Modifiers
     *
     */

    modifier afterEpochExpired() {
        require(
            block.timestamp >=
                lastEpochUpdateTimestamp + safetyFactorConfig.minEpochDuration,
            "Epoch not yet expired"
        );
        _;
    }

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

    // Initialize contract with initial values
    constructor(
        SafetyFactorConfig memory _safetyFactorConfig,
        address _safetyFactorOracle,
        address _avsGov,
        address _protocolId,
        address[] memory _rewardTokens,
        uint256[] memory _initial_tokenFlowsPerSecond
    ) {
        _validateSafetyFactorConfig(_safetyFactorConfig);
        // require that the number of reward tokens is equal to the number of initial token flows
        require(
            _rewardTokens.length == _initial_tokenFlowsPerSecond.length,
            "Invalid number of reward tokens"
        );

        safetyFactorConfig = _safetyFactorConfig;

        safetyFactorOracle = ISafetyFactorOracle(_safetyFactorOracle);

        protocol = _protocolId;
        rewardTokens = _rewardTokens;

        // initialize token flow for each reward token
        for (uint256 i = 0; i < _rewardTokens.length; i++) {
            rewardTokenAccumulator[_rewardTokens[i]].init(
                _initial_tokenFlowsPerSecond[i],
                safetyFactorOracle.getSafetyFactor(protocol)
            );
        }

        lastEpochUpdateTimestamp = block.timestamp;

        _grantRole(AVS_GOV_ROLE, _avsGov);
        _grantRole(ANZEN_GOV_ROLE, msg.sender);
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateFlow() public afterEpochExpired {
        // This function programmatically adjusts the token flow based on the Safety Factor
        int256 currentSafetyFactor = safetyFactorOracle.getSafetyFactor(
            protocol
        );

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAccumulator[rewardTokens[i]].adjustEpochFlow(
                safetyFactorConfig,
                currentSafetyFactor,
                performanceFeeBPS,
                lastEpochUpdateTimestamp
            );
        }

        lastEpochUpdateTimestamp = uint32(block.timestamp);
    }

    // Function to transfer tokenFlow to the Service Manager contract
    function makeRangePaymentsToServiceManager() public {
        // Create a range payment for each reward token
        IPaymentCoordinator.RangePayment[]
            memory rangePayments = new IPaymentCoordinator.RangePayment[](
                rewardTokens.length
            );

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            (
                uint256 claimableTokens,
                uint256 claimableFees
            ) = rewardTokenAccumulator[rewardTokens[i]].claim(
                    performanceFeeBPS,
                    lastPaymentTimestamp
                );
            IERC20 rewardToken = IERC20(rewardTokens[i]);

            _transferPerformanceFeeToAnzen(rewardTokens[i], claimableFees);

            rangePayments[i] = _createRangePayment(
                rewardToken,
                claimableTokens
            );
        }

        // Increase Allowance for the Service Manager contract
        for (uint256 i = 0; i < rangePayments.length; i++) {
            rangePayments[i].token.safeIncreaseAllowance(
                address(avsServiceManager),
                rangePayments[i].amount
            );
        }

        // Transfer the tokens to the Service Manager contract
        avsServiceManager.payForRange(rangePayments);

        // Update the last payment timestamp
        lastPaymentTimestamp = uint32(block.timestamp);
        lastEpochUpdateTimestamp = uint32(block.timestamp);
    }

    /**
     *
     *                            AVS Governance Functions
     *
     */

    function overrideTokensPerSecond(
        uint256[] memory _newTokensPerSecond
    ) external onlyAvsGov {
        // require that the number of reward tokens is equal to the number of new token flows
        require(
            rewardTokens.length == _newTokensPerSecond.length,
            "Invalid number of reward tokens"
        );

        // This function is only callable by the AVS delegated address and should only be used in emergency situations
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAccumulator[rewardTokens[i]].overrideTokensPerSecond(
                _newTokensPerSecond[i],
                lastEpochUpdateTimestamp
            );
        }
        lastEpochUpdateTimestamp = block.timestamp;
    }

    function addRewardToken(
        address _rewardToken,
        uint256 _initialTokenFlow,
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory _strategyAndMultipliers
    ) external onlyAvsGov {
        rewardTokens.push(_rewardToken);
        rewardTokenAccumulator[_rewardToken].init(
            _initialTokenFlow,
            safetyFactorOracle.getSafetyFactor(protocol)
        );
        _setStrategyAndMultipliers(_rewardToken, _strategyAndMultipliers);
    }

    function removeRewardToken(address _rewardToken) external onlyAvsGov {
        delete rewardTokenAccumulator[_rewardToken];
        delete strategyAndMultipliers[_rewardToken];

        for (uint256 i = 0; i < rewardTokens.length; i++) {
            if (rewardTokens[i] == _rewardToken) {
                rewardTokens[i] = rewardTokens[rewardTokens.length - 1];
                rewardTokens.pop();
                break;
            }
        }
    }

    function updateSafetyFactorParams(
        SafetyFactorConfig memory _newSafetyFactorConfig
    ) external onlyAvsGov {
        _validateSafetyFactorConfig(_newSafetyFactorConfig);

        safetyFactorConfig = _newSafetyFactorConfig;
    }

    function setStrategyAndMultipliers(
        address _rewardToken,
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory _strategyAndMultipliers
    ) external onlyAvsGov {
        _setStrategyAndMultipliers(_rewardToken, _strategyAndMultipliers);
    }

    function setServiceManager(address _paymentMaster) external onlyAvsGov {
        avsServiceManager = IServiceManager(_paymentMaster);
    }

    /**
     *
     *                            Anzen Governance Functions
     *
     */

    function adjustFeeBps(uint256 _newFeeBps) external onlyAnzenGov {
        require(
            _newFeeBps <= MAX_PERFORMANCE_FEE_BPS,
            "Fee cannot be greater than 5%"
        );
        performanceFeeBPS = _newFeeBps;
    }

    /**
     *
     *                            View Functions
     *
     */

    function getSafetyFactorConfig()
        external
        view
        returns (SafetyFactorConfig memory)
    {
        return safetyFactorConfig;
    }

    /**
     *
     *                            Internal Functions
     *
     */

    function _validateSafetyFactorConfig(
        SafetyFactorConfig memory _config
    ) internal pure {
        require(
            int256(PRECISION) < _config.TARGET_SF_LOWER_BOUND,
            "Invalid lower bound"
        );
        require(
            _config.TARGET_SF_LOWER_BOUND < _config.TARGET_SF_UPPER_BOUND,
            "Invalid Safety Factor Config"
        );
        require(
            _config.REDUCTION_FACTOR < PRECISION,
            "Invalid Reduction Factor"
        );
        require(PRECISION < _config.INCREASE_FACTOR, "Invalid Increase Factor");
    }

    function _setStrategyAndMultipliers(
        address _rewardToken,
        IPaymentCoordinator.StrategyAndMultiplier[]
            memory _strategyAndMultipliers
    ) internal {
        // Clear the current storage array
        delete strategyAndMultipliers[_rewardToken];

        // Push each element from the memory array to the storage array
        for (uint256 i = 0; i < _strategyAndMultipliers.length; i++) {
            strategyAndMultipliers[_rewardToken].push(
                _strategyAndMultipliers[i]
            );
        }
    }

    function _createRangePayment(
        IERC20 _rewardToken,
        uint256 _claimableTokens
    ) internal view returns (IPaymentCoordinator.RangePayment memory) {
        // Create a range payment for the reward token

        // Get the claimable tokens for the reward token
        uint256 maxClaimableTokens = Math.max(
            _claimableTokens,
            _rewardToken.balanceOf(address(this))
        );

        return
            IPaymentCoordinator.RangePayment({
                token: _rewardToken,
                amount: maxClaimableTokens,
                duration: lastPaymentTimestamp - uint32(block.timestamp),
                strategiesAndMultipliers: strategyAndMultipliers[
                    address(_rewardToken)
                ],
                startTimestamp: lastPaymentTimestamp
            });
    }

    function _transferPerformanceFeeToAnzen(
        address _rewardToken,
        uint256 _fee
    ) internal {
        // Transfer the fee to the Anzen contract
        IERC20 rewardToken = IERC20(_rewardToken);
        rewardToken.safeTransfer(anzen, _fee);
    }
}
