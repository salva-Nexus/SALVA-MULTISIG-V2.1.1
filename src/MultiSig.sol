// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Self } from "./Self.sol";
import { ERC1967Utils } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import { Initializable } from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract MultiSig is Initializable, Self {
    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        _isValidator[_msgSender()] = true;
        _recovery[_msgSender()] = true;
        numOfValidators = 1;
    }

    function getProposalHash(address target, uint256 value, bytes calldata data, uint256 _nonce)
        public
        pure
        returns (bytes32)
    {
        return keccak256(abi.encode(target, value, keccak256(data), _nonce));
    }

    function propose(address target, uint256 value, bytes calldata data) external onlyValidators returns (bytes32) {
        bytes32 proposalHash = getProposalHash(target, value, data, nonce);
        nonce++;
        Proposals storage p = _proposals[proposalHash];
        if (p.isProposed == 1 || p.isExecuted == 1) revert Multisig_ProposalExists();
        p.isProposed = 1;
        p.remaining = uint32((numOfValidators - 1) / 2 + 1);
        p.nonce = nonce;
        emit ProposalCreated(proposalHash, msg.sender);
        return proposalHash;
    }

    function approve(bytes32 proposalHash) external onlyValidators returns (address voter, uint256 remaining) {
        Proposals storage p = _proposals[proposalHash];
        address caller = _msgSender();
        if (p.isProposed == 0) revert Multisig__ProposalDoesNotExist();
        if (p.hasApproved[caller]) revert Multisig__AlreadyApproved();

        uint256 rem = p.remaining - 1;
        p.hasApproved[caller] = true;
        p.remaining = uint32(rem);

        if (rem == 0 || _recovery[caller]) {
            p.timeLock = uint128(block.timestamp + _TIME_INTERVAL);
            p.isValidated = 1;
        }

        emit ProposalApproved(proposalHash, msg.sender);
        return (caller, rem);
    }

    function execute(address target, uint256 value, bytes calldata data, uint256 nonce)
        external
        payable
        onlyValidators
        whenNotPaused
        returns (bytes memory)
    {
        bytes32 proposalHash = getProposalHash(target, value, data, nonce);
        Proposals storage p = _proposals[proposalHash];
        if (!_recovery[_msgSender()]) {
            if (p.isValidated == 0 || block.timestamp < p.timeLock) {
                revert MultiSig__TimelockNotElapsedOrNotValidated();
            }
        }
        p.isExecuted = 1;

        emit ProposalExecuted(proposalHash, msg.sender);
        (bool success, bytes memory returnData) = target.call{ value: value }(data);
        if (!success) revert MultiSig__ExecutionFailed();
        return returnData;
    }
}
