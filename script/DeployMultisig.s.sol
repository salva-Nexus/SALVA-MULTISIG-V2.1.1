// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { MultiSig } from "../src/MultiSig.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Script, console } from "forge-std/Script.sol";

contract DeployMultiSig is Script {
    function run() external returns (address proxyAddress, address implementationAddress) {
        vm.startBroadcast();
        MultiSig implementation = new MultiSig();
        implementationAddress = address(implementation);
        console.log("MultiSig Implementation deployed at:", implementationAddress);
        bytes memory initData = abi.encodeCall(MultiSig.initialize, ());
        ERC1967Proxy proxy = new ERC1967Proxy(implementationAddress, initData);
        proxyAddress = address(proxy);
        console.log("MultiSig ERC1967Proxy deployed at:", proxyAddress);
        vm.stopBroadcast();

        MultiSig multisig = MultiSig(payable(proxyAddress));
        console.log("Validator Count:", multisig.numOfValidators());

        // BASE TESTNET => 0x7Fe2bB5D44bFE124A7eDbE507035246e6327CB3A
        // BNB TESTNET => 0x8f574842E7CC0277E9256418C46A90e3398d4005
    }
}
