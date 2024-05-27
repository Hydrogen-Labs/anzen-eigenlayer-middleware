// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

import "../../static/Structs.sol";
import {ISafetyFactorOracle} from "../../interfaces/ISafetyFactorOracle.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract MockSafetyFactorOracle is ISafetyFactorOracle, Ownable {
    mapping(address => SafetyFactorSnapshot) public safetyFactorSnapshots;

    // Safety Factor snapshots for each protocol

    function mockSetSafetyFactor(address _protocol, int256 _newSF) external {
        safetyFactorSnapshots[_protocol] = SafetyFactorSnapshot(
            _newSF,
            block.timestamp
        );
    }

    function getSafetyFactor(
        address _protocol
    ) external view override returns (int256) {
        return safetyFactorSnapshots[_protocol].safetyFactor;
    }

    function getProposedSafetyFactor(
        address protocol
    ) external view override returns (int256) {}

    function signers(address signer) external view override returns (bool) {}

    function quorum() external view override returns (uint64) {}

    function addSigner(address signer) external override {}

    function removeSigner(address signer) external override {}

    function updateQuorum(uint64 quorum) external override {}

    function proposeSafetyFactor(
        int256 newSF,
        address protocol
    ) external override {}

    function approveSafetyFactor(address protocol) external override {}

    function rejectSafetyFactor(address protocol) external override {}
}
