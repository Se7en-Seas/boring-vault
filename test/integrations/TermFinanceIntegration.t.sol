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
    }

    function testTermFinanceIntegrationLockOffer() public {
        _setupEnv(20684989);
        address weth = getAddress(sourceChain, "WETH");
        deal(weth, address(boringVault), 10000e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2);
        ERC20[] memory purchaseTokens = new ERC20[](1);
        purchaseTokens[0] = ERC20(getAddress(sourceChain, "WETH"));
        address[] memory termAuctionOfferLockers = new address[](1);
        termAuctionOfferLockers[0] = getAddress(sourceChain, "termAuctionOfferLocker");
        address[] memory termRepoLockers = new address[](1);
        termRepoLockers[0] = getAddress(sourceChain, "termRepoLocker");
        _addTermFinanceLockOfferLeafs(leafs, purchaseTokens, termAuctionOfferLockers, termRepoLockers);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](2);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](2);
        targets[0] = weth;
        targets[1] = getAddress(sourceChain, "termAuctionOfferLocker");
        bytes[] memory targetData = new bytes[](2);
        targetData[0] = abi.encodeWithSignature(
            "approve(address,uint256)", getAddress(sourceChain, "termRepoLocker"), type(uint256).max
        );
        DecoderCustomTypes.TermAuctionOfferSubmission memory termAuctionOfferSubmission = DecoderCustomTypes.TermAuctionOfferSubmission(
            keccak256(abi.encodePacked(uint256(block.timestamp), address(boringVault))),
            address(boringVault),
            keccak256(abi.encode(uint256(10e17), uint256(1e18))),
            2e18,
            weth   
        );
        DecoderCustomTypes.TermAuctionOfferSubmission[] memory offerSubmissions = new DecoderCustomTypes.TermAuctionOfferSubmission[](1);
        offerSubmissions[0] = termAuctionOfferSubmission;
        targetData[1] = abi.encodeWithSignature("lockOffers((bytes32,address,bytes32,uint256,address)[])", offerSubmissions);

        address[] memory decodersAndSanitizers = new address[](2);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](2)
        );
    }

    function testTermFinanceIntegrationUnlockOffer() external {
        testTermFinanceIntegrationLockOffer();
        leafIndex = type(uint256).max;
        ManageLeaf[] memory leafs = new ManageLeaf[](2); // only need 1 leaf, but _generateMerkleTree needs at least 2.
        address[] memory termAuctionOfferLockers = new address[](1);
        termAuctionOfferLockers[0] = getAddress(sourceChain, "termAuctionOfferLocker");
        _addTermFinanceUnlockOfferLeafs(leafs, termAuctionOfferLockers);


        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "termAuctionOfferLocker");

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory offerIds = new bytes32[](1);
        bytes32 idHash =  keccak256(abi.encodePacked(uint256(block.timestamp), address(boringVault)));
        offerIds[0] = keccak256(
            abi.encodePacked(idHash, address(boringVault), termAuctionOfferLockers[0])
        );
        targetData[0] = abi.encodeWithSignature("unlockOffers(bytes32[])", offerIds);
        
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testTermFinanceIntegrationRevealOffer() external {
        testTermFinanceIntegrationLockOffer();
        bytes32 idHash =  keccak256(abi.encodePacked(uint256(block.timestamp), address(boringVault)));

        vm.warp(1725555601);
        leafIndex = type(uint256).max;
        ManageLeaf[] memory leafs = new ManageLeaf[](2); // only need 1 leaf, but _generateMerkleTree needs at least 2.
        address[] memory termAuctionOfferLockers = new address[](1);
        termAuctionOfferLockers[0] = getAddress(sourceChain, "termAuctionOfferLocker");
        _addTermFinanceRevealOfferLeafs(leafs, termAuctionOfferLockers);


        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "termAuctionOfferLocker");

        bytes[] memory targetData = new bytes[](1);
        bytes32[] memory offerIds = new bytes32[](1);
        offerIds[0] = keccak256(
            abi.encodePacked(idHash, address(boringVault), termAuctionOfferLockers[0])
        );

        uint256[] memory prices = new uint256[](1);
        prices[0] = uint256(10e17);

        uint256[] memory nonces = new uint256[](1);
        nonces[0] = uint256(1e18);

        targetData[0] = abi.encodeWithSignature("revealOffers(bytes32[],uint256[],uint256[])", offerIds, prices, nonces);
        
        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    function testTermFinanceIntegrationRedeemTermRepoTokens() external {
        _setupEnv(20896437);

        address termRepoToken = getAddress(sourceChain, "termRepoToken");
        deal(termRepoToken, address(boringVault), 10e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](2); // only need 1 leaf, but _generateMerkleTree needs at least 2.
        address[] memory termRepoServicers = new address[](1);
        termRepoServicers[0] = getAddress(sourceChain, "termRepoServicer");

        _addTermFinanceRedeemTermRepoTokensLeafs(leafs, termRepoServicers);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](1);
        manageLeafs[0] = leafs[0];
  
        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
 
        address[] memory targets = new address[](1);
        targets[0] = getAddress(sourceChain, "termRepoServicer");

        bytes[] memory targetData = new bytes[](1);
        targetData[0] = abi.encodeWithSignature("redeemTermRepoTokens(address,uint256)", address(boringVault), 10e18);

        address[] memory decodersAndSanitizers = new address[](1);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        manager.manageVaultWithMerkleVerification(
            manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](1)
        );
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _setupEnv(uint256 blockNumber) internal {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
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

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
