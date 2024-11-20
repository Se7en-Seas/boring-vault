// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {FluidDexFullDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/FluidDexFullDecoderAndSanitizer.sol"; 
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract FluidDexIntegrationTest is Test, MerkleTreeHelper {
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
        uint256 blockNumber = 21215737;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new FluidDexFullDecoderAndSanitizer(address(boringVault))); 

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
    
    function testFluidDexIntegration() public {
        deal(getAddress(sourceChain, "WeETH"), address(boringVault), 1000e18); 

        ERC20[] memory supplyTokens = new ERC20[](1); 
        supplyTokens[0] = getERC20(sourceChain, "WeETH");  

        ERC20[] memory borrowTokens = new ERC20[](2); 
        borrowTokens[0] = getERC20(sourceChain, "USDC"); 
        borrowTokens[1] = getERC20(sourceChain, "USDT"); 
        
        //1) approve the dex vault address 
        //2) mint liquidity nft (deposit)?
        //3) can then borrow, etc, using NFT
        
        //3 approvals, 1 leaf for `operate()`
        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addFluidDexLeafs(
            leafs,
            getAddress(sourceChain, "WeETHDexUSDC-USDT"),
            supplyTokens,
            borrowTokens
        ); 

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](7);
        manageLeafs[0] = leafs[0];  //approval supply 
        manageLeafs[1] = leafs[1];  //approval borrow0 
        manageLeafs[2] = leafs[2];  //approval borrow1
        manageLeafs[3] = leafs[3];  //operate() deposit params
        manageLeafs[4] = leafs[3];  //operate() borrow params
        manageLeafs[5] = leafs[3];  //operate() payback params
        manageLeafs[6] = leafs[3];  //operate() withdraw params

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);
        
        //tree setup complete
        //
        //setup boring vault tx data 
        
        //this is what will be minted after we deposit 
        uint256 nftId = 2795; 

        //deal some dust to payback borrow
        //deal(getAddress(sourceChain, "USDC"), address(boringVault), 10e18); //I know USDC and USDT don't have 18decimals
        //deal(getAddress(sourceChain, "USDT"), address(boringVault), 10e18); 

        address[] memory targets = new address[](7); 
        targets[0] = getAddress(sourceChain, "WeETH"); 
        targets[1] = getAddress(sourceChain, "USDC"); 
        targets[2] = getAddress(sourceChain, "USDT"); 
        targets[3] = getAddress(sourceChain, "WeETHDexUSDC-USDT");  
        targets[4] = getAddress(sourceChain, "WeETHDexUSDC-USDT");  
        targets[5] = getAddress(sourceChain, "WeETHDexUSDC-USDT");  
        targets[6] = getAddress(sourceChain, "WeETHDexUSDC-USDT");  

        bytes[] memory targetData = new bytes[](7); 
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", 
                getAddress(sourceChain, "WeETHDexUSDC-USDT"),
                1000e18
            );
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", 
                getAddress(sourceChain, "WeETHDexUSDC-USDT"),
                1000e18
            );
        targetData[2] =
            abi.encodeWithSignature("approve(address,uint256)", 
                getAddress(sourceChain, "WeETHDexUSDC-USDT"),
                1000e18
            );
        //deposit
        targetData[3] = 
            abi.encodeWithSignature("operate(uint256,int256,int256,int256,int256,address)",
                0, 100e18, 0, 0, 0, getAddress(sourceChain, "boringVault")
            ); 
        ////borrow
        targetData[4] = 
            abi.encodeWithSignature("operate(uint256,int256,int256,int256,int256,address)",
                nftId, 0, 1e8, 1e8, 1000e18, getAddress(sourceChain, "boringVault")
            ); 
        //payback
        targetData[5] = 
            abi.encodeWithSignature("operate(uint256,int256,int256,int256,int256,address)",
                nftId, 0, -1e8, -1e8, -5e18, getAddress(sourceChain, "boringVault")  
            ); 
        ////withdraw
        targetData[6] = 
            abi.encodeWithSignature("operate(uint256,int256,int256,int256,int256,address)",
                nftId, -99.9e18, 0, 0, 0, getAddress(sourceChain, "boringVault")
            ); 
        uint256[] memory values = new uint256[](7);
        address[] memory decodersAndSanitizers = new address[](7);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[4] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[5] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[6] = rawDataDecoderAndSanitizer;
         
        
        //get the nft id first
        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values); 
        
        
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

}
