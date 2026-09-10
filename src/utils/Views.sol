// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Modifier } from "./Modifier.sol";

abstract contract Views is Modifier {
    function votesRemaining(bytes32 proposalHash) external view returns (uint256 remaining) {
        Proposals storage p = _proposals[proposalHash];
        remaining = uint256(p.remaining);
    }

    function isRecovery(address account) external view returns (bool) {
        return _recovery[account];
    }

    function isValidator(address account) external view returns (bool) {
        return _isValidator[account];
    }

    function proposal(bytes32 proposalHash) external view returns (Proposals memory) {
        return _proposals[proposalHash];
    }
}
