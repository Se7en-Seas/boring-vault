// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {LombardBTCFullMinterDecoderAndSanitizer} from
    "src/base/DecodersAndSanitizers/LombardBtcFullMinterDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LombardBTCStakingIntegrationTest is Test, MerkleTreeHelper {
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

    // Mint Deposit Data
    struct OutputWithPayload {
        uint256 chainId;
        address to;
        uint64 amount;
        bytes32 txId;
        uint32 index;
    }

    function _setUp(string memory chainName, string memory RPC_URL, uint256 blockNumber) internal {
        //setSourceChainName("bsc");
        setSourceChainName(chainName);
        // Setup forked environment.
        //string memory rpcKey = "BNB_RPC_URL";
        string memory rpcKey = RPC_URL;
        //uint256 blockNumber = 43951627;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new LombardBTCFullMinterDecoderAndSanitizer(address(boringVault)));

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

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testLombardStakingIntegrationBNB() external {
        _setUp("bsc", "BNB_RPC_URL", 43951627);
        // Deploy Mock Consortium
        MockConsortium mockConsortium = new MockConsortium();

        // Transfer ownership to Mock Consortium
        address LBTC = getAddress(sourceChain, "LBTC");
        vm.startPrank(ILBTC(LBTC).owner());
        ILBTC(LBTC).changeConsortium(address(mockConsortium));
        ILBTC(LBTC).addMinter(address(boringVault));
        ILBTC(LBTC).toggleWithdrawals();
        ILBTC(LBTC).changeTreasuryAddress(address(69));
        vm.stopPrank();

        deal(address(getAddress(sourceChain, "BTCB")), address(boringVault), 200e18);

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLombardBTCLeafs(leafs, getERC20(sourceChain, "BTCB"), getERC20(sourceChain, "LBTC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];
        manageLeafs[4] = leafs[4];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // Targets
        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "BTCB");
        targets[1] = getAddress(sourceChain, "LBTC");
        targets[2] = getAddress(sourceChain, "LBTC");
        targets[3] = getAddress(sourceChain, "BTCB");
        targets[4] = getAddress(sourceChain, "BTCBPMM");

        bytes memory depositData = abi.encode(
            OutputWithPayload(
                56, //bsc chain id
                getAddress(sourceChain, "boringVault"),
                uint64(uint256(100e18)),
                bytes32(uint256(5)),
                uint32(10)
            )
        );

        bytes memory signature = hex"00"; // Could be any bytes

        // Dummy BTC Pubkey -- P2WPKH scriptPubkey
        //bytes memory scriptPubkey = abi.encodePacked(
        //    hex"0014", // OP_0 (00) followed by OP_DATA_20 (14)
        //    hex"1234567890123456789012345678901234567890" // 20 bytes of example data
        //);

        // Target Data
        bytes[] memory targetData = new bytes[](5);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "LBTC"), type(uint256).max);

         targetData[1] = 
             abi.encodeWithSignature("mint(address,uint256)", getAddress(sourceChain, "boringVault"), 100e18);  
         targetData[2] = 
             abi.encodeWithSignature("mint(bytes,bytes)", depositData, signature); 
         targetData[3] = 
             abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "BTCBPMM"), type(uint256).max);  
         targetData[4] = 
            abi.encodeWithSignature("swapBTCBToLBTC(uint256)", 10e18); 

        // Eth Amounts 
        uint256[] memory values = new uint256[](5); //empty, not passing any ETH

        // Decoders and Sanitizers
        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        // Run the functions
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testLombardStakingIntegrationBase() external {
        _setUp("base", "BASE_RPC_URL", 22662896);
        deal(address(getAddress(sourceChain, "cbBTC")), address(boringVault), 1000e18);

        // Deploy Mock Consortium
        MockConsortium mockConsortium = new MockConsortium();

        // Transfer ownership to Mock Consortium
        address LBTC = getAddress(sourceChain, "LBTC");
        vm.startPrank(ILBTC(LBTC).owner());
        ILBTC(LBTC).changeConsortium(address(mockConsortium));
        ILBTC(LBTC).addMinter(address(boringVault));
        ILBTC(LBTC).toggleWithdrawals();
        ILBTC(LBTC).changeTreasuryAddress(address(69));
        vm.stopPrank();

        ManageLeaf[] memory leafs = new ManageLeaf[](8);
        _addLombardBTCLeafs(leafs, getERC20(sourceChain, "cbBTC"), getERC20(sourceChain, "LBTC"));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](5);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3]; 
        manageLeafs[4] = leafs[4]; 
        

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](5);
        targets[0] = getAddress(sourceChain, "cbBTC");
        targets[1] = getAddress(sourceChain, "LBTC");
        targets[2] = getAddress(sourceChain, "LBTC");
        targets[3] = getAddress(sourceChain, "cbBTC"); //approving dif swap contract
        targets[4] = getAddress(sourceChain, "cbBTCPMM");

        bytes memory depositData = abi.encode(
            OutputWithPayload(
                8453, //bsc chain id
                getAddress(sourceChain, "boringVault"),
                uint64(uint256(100e18)),
                bytes32(uint256(5)),
                uint32(10)
            )
        );

        bytes memory signature = hex"00"; // Could be any bytes

    //    // Dummy BTC Pubkey -- P2WPKH scriptPubkey
    //    bytes memory scriptPubkey = abi.encodePacked(
    //        hex"0014", // OP_0 (00) followed by OP_DATA_20 (14)
    //        hex"1234567890123456789012345678901234567890" // 20 bytes of example data
    //    );

        // Target Data
        bytes[] memory targetData = new bytes[](5);
         targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "LBTC"), type(uint256).max);
         targetData[1] = 
             abi.encodeWithSignature("mint(address,uint256)", getAddress(sourceChain, "boringVault"), 100e18);  
         targetData[2] = 
             abi.encodeWithSignature("mint(bytes,bytes)", depositData, signature); 
         targetData[3] = 
             abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "cbBTCPMM"), type(uint256).max); 
         targetData[4] = 
             abi.encodeWithSignature("swapCBBTCToLBTC(uint256)", 1e4); 

        // Eth Amounts 
        uint256[] memory values = new uint256[](5); //empty, not passing any ETH


        // Decoders and Sanitizers
        address[] memory decodersAndSanitizers = new address[](5);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;

        // Run the functions
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        //run against base fork
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface ILBTC {
    function owner() external returns (address);
    function changeConsortium(address newVal) external;
    function addMinter(address minter) external;
    function toggleWithdrawals() external;
    function changeTreasuryAddress(address newValue) external;
}

// Mock consortium that accepts any signature
contract MockConsortium {
    // This is the magic value that EIP1271 expects for valid signatures
    bytes4 internal constant MAGIC_VALUE = 0x1626ba7e;

    function isValidSignature(bytes32 hash, bytes calldata signature) external pure returns (bytes4) {
        // Always return the magic value indicating a valid signature
        hash;
        signature;
        return MAGIC_VALUE;
    }
}
