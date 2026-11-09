// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import { MultiSig } from "../src/MultiSig.sol";
import { Self } from "../src/Self.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { Test, console } from "forge-std/Test.sol";

contract MockTarget {
    uint256 public value;

    function setValue(uint256 newValue) external {
        value = newValue;
    }

    function alwaysReverts() external pure {
        revert("MockTarget: nope");
    }

    receive() external payable { }
}

contract MultiSigV2Mock is MultiSig {
    function version() external pure returns (string memory) {
        return "v2-mock";
    }
}

contract MultiSigTest is Test {
    MultiSig internal impl;
    MultiSig internal multisig;
    MockTarget internal target;

    address internal deployer = makeAddr("deployer");
    address internal validator2 = makeAddr("validator2");
    address internal validator3 = makeAddr("validator3");
    address internal stranger = makeAddr("stranger");

    uint256 internal constant TIME_INTERVAL = 24 hours;

    function setUp() public {
        vm.prank(deployer);
        impl = new MultiSig();

        bytes memory initData = abi.encodeCall(MultiSig.initialize, ());
        vm.prank(deployer);
        multisig = MultiSig(payable(address(new ERC1967Proxy(address(impl), initData))));
        assertEq(multisig.isValidator(deployer), true);

        target = new MockTarget();
    }

    /// @dev Adds `newValidator` through the required self-governance path
    ///      (propose -> approve -> wait 24h -> execute, as `deployer`).
    function _addValidator(address newValidator) internal {
        bytes memory data = abi.encodeCall(Self.updateValidator, (newValidator, true));
        uint256 n = multisig.nonce();

        vm.startPrank(deployer);
        multisig.propose(address(multisig), 0, data);
        multisig.approve(multisig.getProposalHash(address(multisig), 0, data, n));
        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(multisig), 0, data, n);
        vm.stopPrank();
    }

    // ─────────────────────────────────────────────────────────────
    // INITIALIZE
    // ─────────────────────────────────────────────────────────────

    function test_Initialize_SetsDeployerAsValidatorAndRecovery() public view {
        assertTrue(multisig.isValidator(deployer));
        assertTrue(multisig.isRecovery(deployer));
        assertEq(multisig.numOfValidators(), 1);
    }

    function test_Initialize_RevertsOnSecondCall() public {
        vm.expectRevert();
        multisig.initialize();
    }

    function test_Initialize_ImplementationCannotBeInitializedDirectly() public {
        vm.expectRevert();
        impl.initialize();
    }

    // ─────────────────────────────────────────────────────────────
    // PROPOSAL HASHING
    // ─────────────────────────────────────────────────────────────

    function test_GetProposalHash_MatchesManualEncoding() public view {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));
        bytes32 expected = keccak256(abi.encode(address(target), uint256(0), keccak256(data), uint256(0)));
        assertEq(multisig.getProposalHash(address(target), 0, data, 0), expected);
    }

    function test_GetProposalHash_DiffersByNonce() public view {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (42));
        bytes32 h0 = multisig.getProposalHash(address(target), 0, data, 0);
        bytes32 h1 = multisig.getProposalHash(address(target), 0, data, 1);
        assertTrue(h0 != h1);
    }

    // ─────────────────────────────────────────────────────────────
    // PROPOSE
    // ─────────────────────────────────────────────────────────────

    function test_Propose_RevertsForNonValidatorNonRecovery() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1));
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.propose(address(target), 0, data);
    }

    // ─────────────────────────────────────────────────────────────
    // APPROVE
    // ─────────────────────────────────────────────────────────────

    function test_Approve_RevertsIfProposalDoesNotExist() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Multisig__ProposalDoesNotExist()"));
        multisig.approve(bytes32(uint256(0xdead)));
    }

    function test_Approve_RevertsIfAlreadyApproved() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1));
        vm.startPrank(deployer);
        multisig.propose(address(target), 0, data);
        bytes32 hash_ = multisig.getProposalHash(address(target), 0, data, 0);

        multisig.approve(hash_);

        vm.expectRevert(abi.encodeWithSignature("Multisig__AlreadyApproved()"));
        multisig.approve(hash_);
    }

    // ─────────────────────────────────────────────────────────────
    // EXECUTE
    // ─────────────────────────────────────────────────────────────

    function test_Execute_RevertsBeforeTimelockElapsed() public {
        _addValidator(validator2);
        uint256 n = multisig.nonce();
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1));
        vm.startPrank(validator2);
        multisig.propose(address(target), 0, data);
        multisig.approve(multisig.getProposalHash(address(target), 0, data, n));

        // Quorum met (1 of 2), but the 24h timelock hasn't elapsed yet.
        vm.expectRevert(abi.encodeWithSignature("MultiSig__TimelockNotElapsedOrNotValidated()"));
        multisig.execute(address(target), 0, data, n);
    }

    function test_Execute_RevertsIfNeverApproved() public {
        _addValidator(validator2);
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1));
        uint256 n = multisig.nonce();
        vm.prank(deployer);
        multisig.propose(address(target), 0, data);

        vm.prank(validator2); // not recovery, and never approved
        vm.expectRevert(abi.encodeWithSignature("MultiSig__TimelockNotElapsedOrNotValidated()"));
        multisig.execute(address(target), 0, data, n);
    }

    function test_Execute_SucceedsAfterTimelockElapsed() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (123));
        vm.startPrank(deployer);
        multisig.propose(address(target), 0, data);
        multisig.approve(multisig.getProposalHash(address(target), 0, data, 0));

        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(target), 0, data, 0);
        assertEq(target.value(), 123);
    }

    function test_Execute_ForwardsEtherValue() public {
        vm.deal(address(multisig), 1 ether);
        bytes memory data = "";
        vm.startPrank(deployer);
        multisig.propose(address(target), 1 ether, data);
        multisig.approve(multisig.getProposalHash(address(target), 1 ether, data, 0));

        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(target), 1 ether, data, 0);
        assertEq(address(target).balance, 1 ether);
    }

    function test_Execute_RevertsIfInnerCallFails() public {
        bytes memory data = abi.encodeCall(MockTarget.alwaysReverts, ());
        vm.startPrank(deployer);
        multisig.propose(address(target), 0, data);
        multisig.approve(multisig.getProposalHash(address(target), 0, data, 0));

        vm.warp(block.timestamp + TIME_INTERVAL);
        vm.expectRevert(abi.encodeWithSignature("MultiSig__ExecutionFailed()"));
        multisig.execute(address(target), 0, data, 0);
    }

    /// @dev IMPORTANT — documents a real, notable property of the current code rather
    ///      than working around it: `execute()` only checks `isValidated`/timelock when
    ///      the caller is NOT a recovery address. It never checks `isProposed` at all.
    ///      A recovery address can therefore execute an arbitrary call to any target
    ///      that was never proposed or approved by anyone. See the README.
    function test_Execute_RecoveryCanExecuteWithoutAnyProposal() public {
        bytes memory data = abi.encodeCall(MockTarget.setValue, (1234));
        vm.prank(deployer); // deployer is recovery; nothing was ever proposed
        multisig.execute(address(target), 0, data, 999);
        assertEq(target.value(), 1234);
    }

    function test_RecoveryOnly_NonValidator_CanProposeApproveExecute() public {
        address recoveryOnly = makeAddr("recoveryOnly");
        vm.prank(deployer);
        multisig.updateRecovery(recoveryOnly, true);
        assertFalse(multisig.isValidator(recoveryOnly));
        assertTrue(multisig.isRecovery(recoveryOnly));

        bytes memory data = abi.encodeCall(MockTarget.setValue, (55));
        vm.startPrank(recoveryOnly);
        multisig.propose(address(target), 0, data);
        multisig.approve(multisig.getProposalHash(address(target), 0, data, 0));

        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(target), 0, data, 0);
        assertEq(target.value(), 55);
    }

    // ─────────────────────────────────────────────────────────────
    // SELF-GOVERNANCE: VALIDATOR SET
    // ─────────────────────────────────────────────────────────────

    function test_UpdateValidator_DirectCallReverts() public {
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.updateValidator(validator2, true);
    }

    function test_UpdateValidator_ViaSelfGovernance_AddsValidator() public {
        _addValidator(validator2);
        assertTrue(multisig.isValidator(validator2));
        assertEq(multisig.numOfValidators(), 2);
    }

    function test_UpdateValidator_ViaSelfGovernance_RemovesValidator() public {
        _addValidator(validator2);

        bytes memory data = abi.encodeCall(Self.updateValidator, (validator2, false));
        uint256 n = multisig.nonce();
        vm.startPrank(deployer);
        multisig.propose(address(multisig), 0, data);
        multisig.approve(multisig.getProposalHash(address(multisig), 0, data, n));
        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(multisig), 0, data, n);

        assertFalse(multisig.isValidator(validator2));
        assertEq(multisig.numOfValidators(), 1);
    }

    // ─────────────────────────────────────────────────────────────
    // RECOVERY MANAGEMENT
    // ─────────────────────────────────────────────────────────────

    function test_UpdateRecovery_OnlyRecoveryCanCall() public {
        vm.prank(deployer);
        multisig.updateRecovery(validator2, true);
        assertTrue(multisig.isRecovery(validator2));
    }

    function test_UpdateRecovery_RevertsForNonRecovery() public {
        _addValidator(validator2); // a validator, but not recovery
        vm.prank(validator2);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.updateRecovery(validator3, true);
    }

    // ─────────────────────────────────────────────────────────────
    // PAUSE / UNPAUSE
    // ─────────────────────────────────────────────────────────────

    function test_PauseState_AnyValidatorCanPauseImmediately() public {
        _addValidator(validator2);
        _addValidator(validator3);

        vm.startPrank(validator2); // a plain validator, not recovery
        multisig.pauseState();

        bytes memory data = abi.encodeCall(MockTarget.setValue, (1));
        uint256 n = multisig.nonce();
        multisig.propose(address(target), 0, data);
        multisig.approve(multisig.getProposalHash(address(target), 0, data, n));
        vm.stopPrank();
        vm.prank(validator3);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.execute(address(target), 0, data, 0);
    }

    function test_PauseState_RevertsForNonValidator() public {
        vm.prank(stranger);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.pauseState();
    }

    function test_UnpauseState_DirectCallReverts() public {
        vm.prank(deployer);
        multisig.pauseState();

        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.unpauseState();
    }

    // ─────────────────────────────────────────────────────────────
    // UUPS UPGRADE (SELF-GOVERNED)
    // ─────────────────────────────────────────────────────────────

    function test_Upgrade_DirectCallReverts() public {
        MultiSigV2Mock newImpl = new MultiSigV2Mock();
        vm.prank(deployer);
        vm.expectRevert(abi.encodeWithSignature("Multisig__NotAuthorized()"));
        multisig.upgradeToAndCall(address(newImpl), "");
    }

    function test_Upgrade_ViaSelfGovernance_Succeeds() public {
        MultiSigV2Mock newImpl = new MultiSigV2Mock();
        bytes memory data = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", address(newImpl), "");
        uint256 n = multisig.nonce();

        vm.startPrank(deployer);
        multisig.propose(address(multisig), 0, data);
        multisig.approve(multisig.getProposalHash(address(multisig), 0, data, n));
        vm.warp(block.timestamp + TIME_INTERVAL);
        multisig.execute(address(multisig), 0, data, n);

        assertEq(MultiSigV2Mock(payable(address(multisig))).version(), "v2-mock");
        // Storage carries over through the upgrade — same validator/recovery state.
        assertTrue(MultiSigV2Mock(payable(address(multisig))).isValidator(deployer));
    }

    // ─────────────────────────────────────────────────────────────
    // VIEWS
    // ─────────────────────────────────────────────────────────────

    function test_Views_IsValidatorAndIsRecovery_FalseForStranger() public view {
        assertFalse(multisig.isValidator(stranger));
        assertFalse(multisig.isRecovery(stranger));
    }

    function test_prep() public pure {
        console.logBytes(
            abi.encodeWithSignature(
                "updateValidator(address,bool)", address(0xFb371759745Adf3a2ea5ae3BCC6AEcfFDc0Bf791), true
            )
        );
    }
}
