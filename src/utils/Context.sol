// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

abstract contract Context {
    function _msgSender() internal view returns (address msgSender) {
        msgSender = msg.sender;
    }
}
