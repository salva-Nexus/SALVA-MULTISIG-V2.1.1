// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Storage {
    uint256 internal constant _TIME_INTERVAL = 24 hours;

    struct Proposals {
        uint128 timeLock; // 16 bytes
        uint32 remaining; //  4 bytes
        uint32 isProposed; //  4 bytes
        uint32 isValidated; //  4 bytes
        uint32 isExecuted; //  4 bytes
        uint256 nonce; // 32 bytes
        mapping(address => bool) hasApproved;
    }
    uint256 public numOfValidators;
    bool internal multisigPaused;
    uint256 public nonce;
    mapping(address => bool) internal _isValidator;
    mapping(address => bool) internal _recovery;
    mapping(bytes32 => Proposals) internal _proposals;
}
