// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BoringVault} from "./../../src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "./../../src/base/Roles/ManagerWithMerkleVerification.sol";
import {IonPoolDecoderAndSanitizer} from "./../../src/base/DecodersAndSanitizers/IonPoolDecoderAndSanitizer.sol";
import {IonPoolSharedSetup} from "./IonPoolSharedSetup.sol";

import {IIonPool} from "@ion-protocol/interfaces/IIonPool.sol";

import { console2 } from "forge-std/console2.sol";

/// Simple setup with one deposit asset and IonPool deposit strategies.

// contract IonPoolDepositForkTest is IondPoolSharedSetup {
//     function test_Deposit() public {}
// }

// contract IonPoolWithdrawForkTest is IonPoolSharedSetup {
//     function test_Withdraw() public {}
// }

contract IonPoolManagerForkTest is IonPoolSharedSetup {    
    /**
     * The vault needs to call `supply`, `withdraw`, and approve IonPool to
     * transfer the base tokens.
     * Merkle Proof. 
     * Root is bytes32
     * Leafs are bytes32
     * What goes on the leaf?
     * address decoderAndSanitizer = address of the decoder for the function call
     * address target = address of the contract to call
     * bool valueNonZero = whether the value is non zero or not
     * selector = the first 4 bytes of `targetData` which is the function selector. 
     * packedArgumentAddresses = 
     * bytes32 leaf =
     *      keccak256(abi.encodePacked(decoderAndSanitizer, target, valueNonZero, selector, packedArgumentAddresses));
     */
    function test_ManageIonPoolApprove_CorrectAddress() public {         
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        targets[0] = address(WSTETH);

        bytes[] memory targetData = new bytes[](1);
        uint256 allowance = 100 ether;
        targetData[0] = abi.encodeWithSelector(WSTETH.approve.selector, address(WEETH_IONPOOL), allowance);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;
        
        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[0]; // approval is the first leaf

        vm.prank(VAULT_STRATEGIST);
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );

        assertEq(WSTETH.allowance(address(boringVault), address(WEETH_IONPOOL)), allowance, "vault approves ionPool");
    }

    function test_Revert_ManageIonPoolApprove_WrongAddress() public {
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);
        address[] memory targets = new address[](1);
        targets[0] = address(WSTETH);
        bytes[] memory targetData = new bytes[](1);
        uint256 allowance = 100 ether;
        address wrongSpender = makeAddr("WRONG_SPENDER");
        targetData[0] = abi.encodeWithSelector(WSTETH.approve.selector, wrongSpender, allowance);

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[0]; // approval is the first leaf

        vm.startPrank(VAULT_STRATEGIST);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );        
        vm.stopPrank();
    }

    function test_ManageIonPoolSupply_CorrectAddress() public {
        uint256 supplyAmt = 1 ether;
        
        vm.prank(address(boringVault));
        WSTETH.approve(address(WEETH_IONPOOL), supplyAmt);
        
        // 2. Supply base asset to IonPool from boringVault.
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        targets[0] = address(WEETH_IONPOOL);

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory whitelistProof = new bytes32[](0);
        targetData[0] = abi.encodeWithSelector(WEETH_IONPOOL.supply.selector, address(boringVault), supplyAmt, whitelistProof);

        uint256[] memory values = new uint256[](1);
        values[0] = 0; 

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[1]; // supply is the second leaf

        deal(address(WSTETH), address(boringVault), supplyAmt);

        vm.prank(VAULT_STRATEGIST);
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );

        uint256 roundingError = WEETH_IONPOOL.supplyFactor() / 1e27 + 1;

        assertEq(WSTETH.allowance(address(boringVault), address(WEETH_IONPOOL)), 0, "approval spent");
        assertApproxEqAbs(WEETH_IONPOOL.balanceOf(address(boringVault)), supplyAmt, roundingError, "boringVault supplied to IonPool");
    }

    function test_Revert_ManageIonPoolSupply_WrongIonPool() public {
        uint256 supplyAmt = 1 ether;
        
        vm.prank(address(boringVault));
        WSTETH.approve(address(WEETH_IONPOOL), supplyAmt);
        
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        address wrongIonPool = makeAddr("WRONG_IONPOOL");
        targets[0] = wrongIonPool;

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory whitelistProof = new bytes32[](0);
        targetData[0] = abi.encodeWithSelector(WEETH_IONPOOL.supply.selector, address(boringVault), supplyAmt, whitelistProof);

        uint256[] memory values = new uint256[](1);
        values[0] = 0; 

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[1]; // supply is the second leaf

        deal(address(WSTETH), address(boringVault), supplyAmt);

        vm.prank(VAULT_STRATEGIST);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );        
    }

    function test_Revert_ManageIonPoolSupply_WrongRecipient() public {
        uint256 supplyAmt = 1 ether;
        
        vm.prank(address(boringVault));
        WSTETH.approve(address(WEETH_IONPOOL), supplyAmt);
        
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        targets[0] = address(WEETH_IONPOOL);

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory whitelistProof = new bytes32[](0);
        address wrongRecipient = makeAddr("WRONG_RECIPIENT");
        targetData[0] = abi.encodeWithSelector(WEETH_IONPOOL.supply.selector, wrongRecipient, supplyAmt, whitelistProof);

        uint256[] memory values = new uint256[](1);
        values[0] = 0; 

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[1]; // supply is the second leaf

        deal(address(WSTETH), address(boringVault), supplyAmt);

        vm.prank(VAULT_STRATEGIST);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );   
    }

    function test_ManageIonPoolWithdraw() public {
        uint256 supplyAmt = 1 ether;
        deal(address(WSTETH), address(boringVault), supplyAmt); 
        
        vm.startPrank(address(boringVault));
        WSTETH.approve(address(WEETH_IONPOOL), supplyAmt); 
        WEETH_IONPOOL.supply(address(boringVault), supplyAmt, new bytes32[](0));
        vm.stopPrank(); 

        uint256 withdrawAmt = WEETH_IONPOOL.balanceOf(address(boringVault));

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        targets[0] = address(WEETH_IONPOOL);

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSelector(WEETH_IONPOOL.withdraw.selector, address(boringVault), withdrawAmt);

        uint256[] memory values = new uint256[](1);
        values[0] = 0; 

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[2]; // withdraw is the third leaf 

        vm.prank(VAULT_STRATEGIST);
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        );

        assertEq(WSTETH.balanceOf(address(boringVault)), withdrawAmt, "withdraw amount");
        assertEq(WEETH_IONPOOL.balanceOf(address(boringVault)), 0, "boringVault withdrew from IonPool");
    }

    function test_Revert_ManageIonPoolWithdraw_WrongRecipient() public {
         uint256 supplyAmt = 1 ether;
        deal(address(WSTETH), address(boringVault), supplyAmt); 
        
        vm.startPrank(address(boringVault));
        WSTETH.approve(address(WEETH_IONPOOL), supplyAmt); 
        WEETH_IONPOOL.supply(address(boringVault), supplyAmt, new bytes32[](0));
        vm.stopPrank(); 

        uint256 withdrawAmt = WEETH_IONPOOL.balanceOf(address(boringVault));

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = address(ionPoolDecoderAndSanitizer);

        address[] memory targets = new address[](1);
        targets[0] = address(WEETH_IONPOOL);

        bytes[] memory targetData = new bytes[](1);
        address wrongRecipient = makeAddr("WRONG_RECIPIENT");
        targetData[0] = abi.encodeWithSelector(WEETH_IONPOOL.withdraw.selector, wrongRecipient, withdrawAmt);

        uint256[] memory values = new uint256[](1);
        values[0] = 0; 

        bytes32[][] memory proofs = new bytes32[][](1);
        proofs[0] = manageProofs[2]; // withdraw is the third leaf 

        vm.prank(VAULT_STRATEGIST);
        vm.expectRevert(
            abi.encodeWithSelector(
                ManagerWithMerkleVerification.ManagerWithMerkleVerification__FailedToVerifyManageProof.selector,
                targets[0],
                targetData[0],
                values[0]
            )
        );
        manager.manageVaultWithMerkleVerification(
            proofs,
            decodersAndSanitizers,
            targets,
            targetData,
            values
        ); 
    }

    function test_ManageIonPoolMultipleTransactions() public {

    }
}

