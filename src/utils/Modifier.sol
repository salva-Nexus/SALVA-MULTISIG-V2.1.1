// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Context } from "./Context.sol";
import { Errors } from "./Errors.sol";
import { Storage } from "./Storage.sol";

abstract contract Modifier is Context, Storage, Errors {
    modifier onlyValidators() {
        _requireValidator();
        _;
    }

    modifier onlyRecovery() {
        _requireRecovery();
        _;
    }

    modifier whenNotPaused() {
        _requireNotPaused();
        _;
    }

    modifier onlySelf() {
        _onlySelf();
        _;
    }

    function _requireValidator() internal view {
        address caller = _msgSender();
        if (!_isValidator[caller] && !_recovery[caller]) {
            revert Multisig__NotAuthorized();
        }
    }

    function _requireRecovery() internal view {
        if (!_recovery[_msgSender()]) {
            revert Multisig__NotAuthorized();
        }
    }

    function _requireNotPaused() internal view {
        address caller = _msgSender();
        if (multisigPaused && !_recovery[caller]) revert Multisig__NotAuthorized();
    }

    function _onlySelf() internal view {
        if (_msgSender() != address(this)) revert Multisig__NotAuthorized();
    }
}
