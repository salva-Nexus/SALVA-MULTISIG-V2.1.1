// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Modifier } from "./Modifier.sol";

abstract contract Views is Modifier {
    function isRecovery(address account) external view returns (bool) {
        return _recovery[account];
    }

    function isValidator(address account) external view returns (bool) {
        return _isValidator[account];
    }

    function proposal(bytes32 proposalHash)
        external
        view
        returns (
            uint256 timeLock,
            uint256 remaining,
            uint256 isProposed,
            uint256 isValidated,
            uint256 isExecuted,
            uint256 nonce
        )
    {
        Proposals storage p = _proposals[proposalHash];
        return (p.timeLock, p.remaining, p.isProposed, p.isValidated, p.isExecuted, p.nonce);
    }
}
