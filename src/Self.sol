// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { Views } from "./utils/Views.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

abstract contract Self is UUPSUpgradeable, Views {
    function updateValidator(address target, bool action) public onlySelf returns (bool) {
        if (action) {
            _isValidator[target] = true;
            numOfValidators++;
        } else {
            _isValidator[target] = false;
            numOfValidators--;
        }
        return true;
    }

    function updateRecovery(address account, bool action) external onlyRecovery returns (bool success) {
        _recovery[account] = action;
        emit RecoveryUpdated(account, action);
        return true;
    }

    function pauseState() external onlyValidators returns (bool success) {
        multisigPaused = true;
        emit MultisigPaused(address(this));
        return true;
    }

    function unpauseState() external onlySelf returns (bool success) {
        multisigPaused = false;
        emit MultisigUnpaused(address(this));
        return true;
    }

    /// @dev Internal UUPS upgrade hook authorization restricted to MultiSig self-calls
    function _authorizeUpgrade(address newImplementation) internal override onlySelf { }
}
