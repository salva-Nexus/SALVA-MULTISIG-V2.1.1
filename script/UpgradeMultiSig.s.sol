// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { MultiSig } from "../src/MultiSig.sol";
import { Script, console } from "forge-std/Script.sol";

contract UpgradeMultiSig is Script {
    function run() external returns (address newImplementationAddress, bytes32 proposalHash) {
        address payable proxyAddress = payable(0x7Fe2bB5D44bFE124A7eDbE507035246e6327CB3A); // Base sep

        vm.startBroadcast();

        MultiSig multisig = MultiSig(proxyAddress);
        uint256 currentNonce = multisig.nonce();

        MultiSig newImplementation = new MultiSig();
        newImplementationAddress = address(newImplementation);
        console.log("New MultiSig Implementation:", newImplementationAddress);

        bytes memory upgradeCalldata =
            abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementationAddress, "");

        // 1. PROPOSE
        proposalHash = multisig.propose(proxyAddress, 0, upgradeCalldata);

        console.log("Upgrade Proposal Created!");
        console.logBytes32(proposalHash);

        // 2. APPROVE
        multisig.approve(proposalHash);

        // 3. EXECUTE
        multisig.execute(proxyAddress, 0, upgradeCalldata, currentNonce);

        vm.stopBroadcast();
    }
}
