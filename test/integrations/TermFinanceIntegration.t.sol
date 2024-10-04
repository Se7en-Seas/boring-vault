// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {
    TermFinanceDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/TermFinanceDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract TermFinanceIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2;
    uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19826676;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(
            new TermFinanceDecoderAndSanitizer(
                address(boringVault)
            )
        );

        setAddress(false, sourceChain, "boringVault", address(boringVault));
        setAddress(false, sourceChain, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);
        setAddress(false, sourceChain, "manager", address(manager));
        setAddress(false, sourceChain, "managerAddress", address(manager));
        setAddress(false, sourceChain, "accountantAddress", address(1));

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));
        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);

        // Setup roles authority.
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address,bytes,uint256)"))),
            true
        );
        rolesAuthority.setRoleCapability(
            MANAGER_ROLE,
            address(boringVault),
            bytes4(keccak256(abi.encodePacked("manage(address[],bytes[],uint256[])"))),
            true
        );

        rolesAuthority.setRoleCapability(
            STRATEGIST_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            MANGER_INTERNAL_ROLE,
            address(manager),
            ManagerWithMerkleVerification.manageVaultWithMerkleVerification.selector,
            true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(manager), ManagerWithMerkleVerification.setManageRoot.selector, true
        );
        rolesAuthority.setRoleCapability(
            BORING_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.flashLoan.selector, true
        );
        rolesAuthority.setRoleCapability(
            BALANCER_VAULT_ROLE, address(manager), ManagerWithMerkleVerification.receiveFlashLoan.selector, true
        );

        // Grant roles
        rolesAuthority.setUserRole(address(this), STRATEGIST_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANGER_INTERNAL_ROLE, true);
        rolesAuthority.setUserRole(address(this), ADMIN_ROLE, true);
        rolesAuthority.setUserRole(address(manager), MANAGER_ROLE, true);
        rolesAuthority.setUserRole(address(boringVault), BORING_VAULT_ROLE, true);
        rolesAuthority.setUserRole(getAddress(sourceChain, "vault"), BALANCER_VAULT_ROLE, true);
    }

    function testTermFinanceIntegrationLockOffer() external {
        address usdc = getAddress(sourceChain, "USDC");
        deal(getAddress(sourceChain, "USDC"), address(boringVault), 1000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        ERC20[] memory purchaseTokens = new ERC20[](1);
        purchaseTokens[0] = ERC20(getAddress(sourceChain, "USDC"));
        address[] memory termAuctionOfferLockers = new address[](1);
        termAuctionOfferLockers[0] = getAddress(sourceChain, "termAuctionOfferLocker");
        address[] memory termRepoLockers = new address[](1);
        termRepoLockers[0] = getAddress(sourceChain, "termRepoLocker");
        _addTermFinanceLockOfferLeafs(leafs, purchaseTokens, termAuctionOfferLockers, termRepoLockers);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[3];
        manageLeafs[1] = leafs[7];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = usdc;
        targets[1] = getAddress(sourceChain, "termAuctionOfferLocker");
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "termRepoLocker"), type(uint256).max
        );
        DecoderCustomTypes.TermAuctionOfferSubmission memory termAuctionOfferSubmission = DecoderCustomTypes.TermAuctionOfferSubmission(
            keccak256(abi.encodePacked(uint256(block.timestamp), address(boringVault))),
            address(boringVault),
            keccak256(abi.encodePacked(uint256(10e17), uint256(1e18))),
            1000e6,
            usdc   
        );
        DecoderCustomTypes.TermAuctionOfferSubmission[] memory offerSubmissions = new DecoderCustomTypes.TermAuctionOfferSubmission[](1);
        offerSubmissions[0] = termAuctionOfferSubmission;
        targetData[1] = abi.encodeWithSignature("lockOffers(TermAuctionOfferSubmission[])", offerSubmissions);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );
    }

    function testTermFinanceIntegrationRedeemTermRepoTokens() external {
        address termRepoToken = getAddress(sourceChain, "termRepoToken");
        deal(termRepoToken, address(boringVault), 1000e6);

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        address[] memory termRepoServicers = new address[](1);
        termRepoServicers[0] = getAddress(sourceChain, "termRepoServicer");

        _addTermFinanceRedeemTermRepoTokensLeafs(leafs, termRepoServicers);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[3];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "termRepoServicer");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("redeemTermRepoTokens(address,uint256)", address(boringVault), 1000e6);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
