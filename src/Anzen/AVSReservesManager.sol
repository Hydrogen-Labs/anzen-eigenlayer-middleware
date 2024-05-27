// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import {IAVSReservesManager} from "./interfaces/IAVSReservesManager.sol";
import {ISafetyFactorOracle} from "./interfaces/ISafetyFactorOracle.sol";
import {IServiceManager} from "../interfaces/IServiceManager.sol";

import "./static/Structs.sol";
import "./libraries/Accumulator.sol";

import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

import "forge-std/console.sol";

// The AVSReservesManager contract is responsible for managing the token flow to the Payment Master contract
// It is also responsible for updating the token flow based on the Safety Factor
// The Safety Factor is determined by the Safety Factor Oracle contract which represents the protocol's attack surface health

// The reserves manager serves as a 'battery' for the Payment Master contract:
// Storing excess tokens when the protocol is healthy and releasing them when the protocol is in need of more security
contract AVSReservesManager is IAVSReservesManager, AccessControl {
    using SafeERC20 for IERC20;
    using AccumulatorLib for Accumulator;

    // State variables
    SafetyFactorConfig public safetyFactorConfig; // Safety Factor configuration
    uint256 public performanceFeeBPS = 300; // Performance-based fee
    address[] public rewardTokens; // List of reward tokens
    mapping(address => Accumulator) public rewardTokenAccumulator; // mapping of reward tokens to Safety Factor Updaters

    uint256 public lastEpochUpdateTimestamp;
    address public protocol; // Address of the protocol in Anzen
    address public anzen; // Address of the Anzen contract

    IServiceManager public avsServiceManager; // Address of the Payment Master contract
    ISafetyFactorOracle public safetyFactorOracle; // Address of the Safety Factor Oracle contract

    // Modifier to restrict functions to only run after the epoch has expired
    modifier afterEpochExpired() {
        require(
            block.timestamp >=
                lastEpochUpdateTimestamp + safetyFactorConfig.minEpochDuration,
            "Epoch not yet expired"
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

    function setPaymentMaster(address _paymentMaster) external {
        require(hasRole(AVS_GOV_ROLE, msg.sender), "Caller is not a AVS Gov");
        avsServiceManager = IServiceManager(_paymentMaster);
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
    }

    // Function to transfer tokenFlow to the Payment Master contract
    // function transferToPaymentManager() public {
    //     // _adjustClaimableTokens();
    //     // require(
    //     //     claimableTokens > 0,
    //     //     "No tokens available for transfer to Payment Master"
    //     // );
    //     // // I_totalTokenTransferedepends on how you handle tokens, assuming Payment Master contract has a receivePayment function
    //     // uint256 _currentBalance = rewardToken.balanceOf(address(this));
    //     // // Ensure that the amount transferred is not more than the current balance
    //     // uint256 _totalTokenTransfered = Math.min(
    //     //     claimableTokens,
    //     //     _currentBalance
    //     // );
    //     // claimableTokens -= _totalTokenTransfered;
    //     // rewardToken.transfer(address(paymentMaster), _totalTokenTransfered);
    //     // // paymentMaster.increaseF_RWRD(_totalTokenTransfered);
    //     // // Will hook into eigenlayer payment infrastructure
    //     // emit TokensTransferredToPaymentMaster(_totalTokenTransfered);
    // }

    function overrideTokensPerSecond(
        uint256[] memory _newTokensPerSecond
    ) external {
        // This function is only callable by the AVS delegated address and should only be used in emergency situations
        require(hasRole(AVS_GOV_ROLE, msg.sender), "Caller is not a AVS Gov");
        for (uint256 i = 0; i < rewardTokens.length; i++) {
            rewardTokenAccumulator[rewardTokens[i]].overrideTokensPerSecond(
                _newTokensPerSecond[i],
                lastEpochUpdateTimestamp
            );
        }
        lastEpochUpdateTimestamp = block.timestamp;
    }

    function adjustFeeBps(uint256 _newFeeBps) external {
        require(
            hasRole(ANZEN_GOV_ROLE, msg.sender),
            "Caller is not a Anzen Gov"
        );
        require(
            _newFeeBps <= MAX_PERFORMANCE_FEE_BPS,
            "Fee cannot be greater than 5%"
        );
        performanceFeeBPS = _newFeeBps;
    }

    function updateSafetyFactorParams(
        SafetyFactorConfig memory _newSafetyFactorConfig
    ) external {
        require(hasRole(AVS_GOV_ROLE, msg.sender), "Caller is not a Anzen Gov");
        _validateSafetyFactorConfig(_newSafetyFactorConfig);

        safetyFactorConfig = _newSafetyFactorConfig;
    }

    function claimableTokensWithAdjustment(
        address _rewardToken
    ) external view returns (uint256 _claimableTokens) {
        // Call this to see how many tokens can be claimed by the AVS
        // (uint256 _tokensGained, ) = _calculateClaimableTokensAndFee(
        //     _rewardToken
        // );
        // _claimableTokens = claimableTokens + _tokensGained;
    }

    function getSafetyFactorConfig()
        external
        view
        returns (SafetyFactorConfig memory)
    {
        return safetyFactorConfig;
    }

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
}
