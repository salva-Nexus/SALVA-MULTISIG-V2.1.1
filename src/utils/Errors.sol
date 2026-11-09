// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Events } from "./Events.sol";

abstract contract Errors is Events {
    error Multisig__NotAuthorized();
    error Multisig__AlreadyApproved();
    error MultiSig__ExecutionFailed();
    error MultiSig__TimelockNotElapsedOrNotValidated();
    error Multisig_ProposalExists();
    error Multisig__ProposalDoesNotExist();
    error MultiSig__ExpiredProposal();
}
