// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Events {
    event ProposalCreated(bytes32 indexed proposalHash, address indexed proposer);
    event ProposalApproved(bytes32 indexed proposalHash, address indexed validator);
    event ProposalExecuted(bytes32 indexed proposalHash, address indexed validator);
    event RecoveryUpdated(address indexed account, bool action);
    event MultisigPaused(address indexed multisig);
    event MultisigUnpaused(address indexed multisig);
}
