// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {BTCNFullMinterDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/BTCNFullMinterDecoderAndSanitizer.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BTCNMinterIntegrationTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    ManagerWithMerkleVerification public manager;
    BoringVault public boringVault;
    address public rawDataDecoderAndSanitizer;
    RolesAuthority public rolesAuthority;

    uint8 public constant MANAGER_ROLE = 1;
    uint8 public constant STRATEGIST_ROLE = 2; uint8 public constant MANGER_INTERNAL_ROLE = 3;
    uint8 public constant ADMIN_ROLE = 4;
    uint8 public constant BORING_VAULT_ROLE = 5;
    uint8 public constant BALANCER_VAULT_ROLE = 6;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21416471;

        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager =
            new ManagerWithMerkleVerification(address(this), address(boringVault), getAddress(sourceChain, "vault"));

        rawDataDecoderAndSanitizer = address(new BTCNFullMinterDecoderAndSanitizer(address(boringVault)));

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

    function testBTCNMinter() public {
        //address _authority,
        //address _feeRecipient,
        //uint256 _swapInFeeRate,
        //uint256 _swapOutFeeRate,
        //uint256 _mintCap

        //initialize so we can swap
        //ISwapFacility(cornSwap).initialize(
        //    getAddress(sourceChain, "boringVault"),
        //    getAddress(sourceChain, "boringVault"),
        //    0,
        //    0,
        //    100_000_000e18
        //);

        address cornSwap = getAddress(sourceChain, "cornSwapFacilityWBTC");
        //address authority = 0x515C7d8Fcb950f8b030ac08C994b37b4b8F3F7B5;
        //address admin = 0xaD2Bef31Db723b8ad1B9BCa41b0F1EBAfD1193d1;
        //address operator = 0x3964e3572505C1bF51496f9129249E77F55fD044;
        //vm.startPrank(admin);
        //IRolesAuthority(authority).setUserRole(address(boringVault), 11, true);
        //IRolesAuthority(authority).setUserRole(address(boringVault), 12, true);
        //vm.stopPrank();

        //vm.startPrank(operator);
        //ISwapFacility(cornSwap).setSwapInEnabled(true);
        //ISwapFacility(cornSwap).setSwapOutEnabled(true);
        //vm.stopPrank();

        assertEq(ISwapFacility(cornSwap).swapInEnabled(), true);
        assertEq(ISwapFacility(cornSwap).swapOutEnabled(), true);

        deal(getAddress(sourceChain, "WBTC"), address(boringVault), 10000e18);
        deal(getAddress(sourceChain, "BTCN"), address(boringVault), 100e18);
        
        console.log("debtMinted:", ISwapFacility(cornSwap).debtMinted());
        console.log("debtMintCap:", ISwapFacility(cornSwap).debtMintCap());

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addBTCNLeafs(
            leafs,
            getERC20(sourceChain, "WBTC"),
            getERC20(sourceChain, "BTCN"),
            getAddress(sourceChain, "cornSwapFacilityWBTC")
        );
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "WBTC");
        targets[1] = getAddress(sourceChain, "BTCN");
        targets[2] = getAddress(sourceChain, "cornSwapFacilityWBTC");
        targets[3] = getAddress(sourceChain, "cornSwapFacilityWBTC");
        
        console.log(block.timestamp + 1); 

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "cornSwapFacilityWBTC"), 10000e8);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "cornSwapFacilityWBTC"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "swapExactCollateralForDebt(uint256,uint256,address,uint256)",
            1e6,
            0,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );
        targetData[3] = abi.encodeWithSignature(
            "swapExactDebtForCollateral(uint256,uint256,address,uint256)",
            1e18, //we should get 1:1, I think
            0,
            getAddress(sourceChain, "boringVault"),
            1734370282 + 10000
        );

        uint256[] memory values = new uint256[](4);
        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    function testBTCNMintercbBTC() public {
        //address _authority,
        //address _feeRecipient,
        //uint256 _swapInFeeRate,
        //uint256 _swapOutFeeRate,
        //uint256 _mintCap

        //initialize so we can swap
        //ISwapFacility(cornSwap).initialize(
        //    getAddress(sourceChain, "boringVault"),
        //    getAddress(sourceChain, "boringVault"),
        //    0,
        //    0,
        //    100_000_000e18
        //);

        address cornSwap = getAddress(sourceChain, "cornSwapFacilitycbBTC");
        //address authority = 0x515C7d8Fcb950f8b030ac08C994b37b4b8F3F7B5;
        //address admin = 0xaD2Bef31Db723b8ad1B9BCa41b0F1EBAfD1193d1;
        //address operator = 0x3964e3572505C1bF51496f9129249E77F55fD044;
        //vm.startPrank(admin);
        //IRolesAuthority(authority).setUserRole(address(boringVault), 11, true);
        //IRolesAuthority(authority).setUserRole(address(boringVault), 12, true);
        //vm.stopPrank();

        //vm.startPrank(operator);
        //ISwapFacility(cornSwap).setSwapInEnabled(true);
        //ISwapFacility(cornSwap).setSwapOutEnabled(true);
        //vm.stopPrank();

        assertEq(ISwapFacility(cornSwap).swapInEnabled(), true);
        assertEq(ISwapFacility(cornSwap).swapOutEnabled(), true);

        deal(getAddress(sourceChain, "cbBTC"), address(boringVault), 10000e18);
        deal(getAddress(sourceChain, "BTCN"), address(boringVault), 100e18);
        
        console.log("debtMinted:", ISwapFacility(cornSwap).debtMinted());
        console.log("debtMintCap:", ISwapFacility(cornSwap).debtMintCap());

        ManageLeaf[] memory leafs = new ManageLeaf[](4);
        _addBTCNLeafs(
            leafs,
            getERC20(sourceChain, "cbBTC"),
            getERC20(sourceChain, "BTCN"),
            getAddress(sourceChain, "cornSwapFacilitycbBTC")
        );
        bytes32[][] memory manageTree = _generateMerkleTree(leafs);
        manager.setManageRoot(address(this), manageTree[manageTree.length - 1][0]);

        ManageLeaf[] memory manageLeafs = new ManageLeaf[](4);
        manageLeafs[0] = leafs[0];
        manageLeafs[1] = leafs[1];
        manageLeafs[2] = leafs[2];
        manageLeafs[3] = leafs[3];

        bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        address[] memory targets = new address[](4);
        targets[0] = getAddress(sourceChain, "cbBTC");
        targets[1] = getAddress(sourceChain, "BTCN");
        targets[2] = getAddress(sourceChain, "cornSwapFacilitycbBTC");
        targets[3] = getAddress(sourceChain, "cornSwapFacilitycbBTC");
        
        console.log(block.timestamp + 1); 

        bytes[] memory targetData = new bytes[](4);
        targetData[0] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "cornSwapFacilitycbBTC"), 10000e8);
        targetData[1] =
            abi.encodeWithSignature("approve(address,uint256)", getAddress(sourceChain, "cornSwapFacilitycbBTC"), type(uint256).max);
        targetData[2] = abi.encodeWithSignature(
            "swapExactCollateralForDebt(uint256,uint256,address,uint256)",
            1e8,
            0,
            getAddress(sourceChain, "boringVault"),
            block.timestamp + 1
        );
        targetData[3] = abi.encodeWithSignature(
            "swapExactDebtForCollateral(uint256,uint256,address,uint256)",
            1e18, //we should get 1:1, I think
            0,
            getAddress(sourceChain, "boringVault"),
            1734370282 + 10000
        );

        uint256[] memory values = new uint256[](4);
        address[] memory decodersAndSanitizers = new address[](4);
        decodersAndSanitizers[0] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[1] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[2] = rawDataDecoderAndSanitizer;
        decodersAndSanitizers[3] = rawDataDecoderAndSanitizer;

        manager.manageVaultWithMerkleVerification(manageProofs, decodersAndSanitizers, targets, targetData, values);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}

interface ISwapFacility {
    function initialize(
        address _authority,
        address _feeRecipient,
        uint256 _swapInFeeRate,
        uint256 _swapOutFeeRate,
        uint256 _mintCap
    ) external;

    function setSwapInEnabled(bool enabled) external;
    function setSwapOutEnabled(bool enabled) external;

    function swapInEnabled() external view returns (bool);
    function swapOutEnabled() external view returns (bool);

    function debtMinted() external view returns (uint256);
    function debtMintCap() external view returns (uint256);
}

interface IRolesAuthority {
    function setUserRole(address user, uint8 role, bool enabled) external;
}
