// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {BoringVault} from "src/base/BoringVault.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {
    EtherFiLiquidDecoderAndSanitizer,
    MorphoBlueDecoderAndSanitizer,
    UniswapV3DecoderAndSanitizer,
    BalancerV2DecoderAndSanitizer,
    PendleRouterDecoderAndSanitizer
} from "src/base/DecodersAndSanitizers/EtherFiLiquidDecoderAndSanitizer.sol";
import {RenzoLiquidDecoderAndSanitizer} from "src/base/DecodersAndSanitizers/RenzoLiquidDecoderAndSanitizer.sol";
import {BalancerVault} from "src/interfaces/BalancerVault.sol";
import {IUniswapV3Router} from "src/interfaces/IUniswapV3Router.sol";
import {DecoderCustomTypes} from "src/interfaces/DecoderCustomTypes.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract CreateMerkleRootTest is Test, MainnetAddresses {
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

    address public weEthOracle = 0x3fa58b74e9a8eA8768eb33c8453e9C2Ed089A40a;
    address public weEthIrm = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19369928;
        _startFork(rpcKey, blockNumber);

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        manager = new ManagerWithMerkleVerification(address(this), address(boringVault), vault);

        rawDataDecoderAndSanitizer =
            address(new EtherFiLiquidDecoderAndSanitizer(address(boringVault), uniswapV3NonFungiblePositionManager));

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
        rolesAuthority.setUserRole(vault, BALANCER_VAULT_ROLE, true);

        // Allow the boring vault to receive ETH.
        rolesAuthority.setPublicCapability(address(boringVault), bytes4(0), true);
    }

    function testGenerateMerkleRoot() external {
        address decoderAndSanitizer = address(1);
        // Make sure the vault can
        // swap wETH -> rETH
        // add liquidity rETH/wETH
        // add to an existing position rETH/wETH
        // stake in balancer
        // unstake from balancer
        // stake in aura
        // unstake from aura
        // remove liquidity from rETH/wETH
        ManageLeaf[] memory leafs = new ManageLeaf[](16);
        leafs[0] = ManageLeaf(
            address(WETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend wETH",
            decoderAndSanitizer
        );
        leafs[0].argumentAddresses[0] = vault;
        leafs[1] = ManageLeaf(
            vault,
            false,
            "swap((bytes32,uint8,address,address,uint256,bytes),(address,bool,address,bool),uint256,uint256)",
            new address[](5),
            "Swap wETH -> rETH using Balancer",
            decoderAndSanitizer
        );
        leafs[1].argumentAddresses[0] = address(rETH_wETH);
        leafs[1].argumentAddresses[1] = address(WETH);
        leafs[1].argumentAddresses[2] = address(RETH);
        leafs[1].argumentAddresses[3] = address(boringVault);
        leafs[1].argumentAddresses[4] = address(boringVault);
        leafs[2] = ManageLeaf(
            address(RETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer Vault to spend rETH",
            decoderAndSanitizer
        );
        leafs[2].argumentAddresses[0] = vault;
        leafs[3] = ManageLeaf(
            vault,
            false,
            "joinPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Join rETH-wETH Balancer pool",
            decoderAndSanitizer
        );
        leafs[3].argumentAddresses[0] = address(rETH_wETH);
        leafs[3].argumentAddresses[1] = address(boringVault);
        leafs[3].argumentAddresses[2] = address(boringVault);
        leafs[3].argumentAddresses[3] = address(RETH);
        leafs[3].argumentAddresses[4] = address(WETH);
        leafs[4] = ManageLeaf(
            address(rETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Balancer rETH-wETH gauge to spend rETH-wETH bpts",
            decoderAndSanitizer
        );
        leafs[4].argumentAddresses[0] = rETH_wETH_gauge;
        leafs[5] = ManageLeaf(
            rETH_wETH_gauge,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit rETH-wETH bpts into Balancer gauge",
            decoderAndSanitizer
        );
        leafs[5].argumentAddresses[0] = address(boringVault);
        leafs[6] = ManageLeaf(
            rETH_wETH_gauge,
            false,
            "withdraw(uint256)",
            new address[](0),
            "Withdraw rETH-wETH bpts from Balancer gauge",
            decoderAndSanitizer
        );
        leafs[7] = ManageLeaf(
            address(rETH_wETH),
            false,
            "approve(address,uint256)",
            new address[](1),
            "Approve Aura rETH-wETH gauge to spend rETH-wETH bpts",
            decoderAndSanitizer
        );
        leafs[7].argumentAddresses[0] = aura_reth_weth;
        leafs[8] = ManageLeaf(
            aura_reth_weth,
            false,
            "deposit(uint256,address)",
            new address[](1),
            "Deposit rETH-wETH bpts into Aura gauge",
            decoderAndSanitizer
        );
        leafs[8].argumentAddresses[0] = address(boringVault);
        leafs[9] = ManageLeaf(
            aura_reth_weth,
            false,
            "withdraw(uint256,address,address)",
            new address[](2),
            "Withdraw rETH-wETH bpts from Aura gauge",
            decoderAndSanitizer
        );
        leafs[9].argumentAddresses[0] = address(boringVault);
        leafs[9].argumentAddresses[1] = address(boringVault);
        leafs[10] = ManageLeaf(
            vault,
            false,
            "exitPool(bytes32,address,address,(address[],uint256[],bytes,bool))",
            new address[](5),
            "Exit rETH-wETH Balancer pool",
            decoderAndSanitizer
        );
        leafs[10].argumentAddresses[0] = address(rETH_wETH);
        leafs[10].argumentAddresses[1] = address(boringVault);
        leafs[10].argumentAddresses[2] = address(boringVault);
        leafs[10].argumentAddresses[3] = address(RETH);
        leafs[10].argumentAddresses[4] = address(WETH);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/StrategistLeavesV0.json";

        // address target;
        // bool canSendValue;
        // string signature;
        // address[] argumentAddresses;
        if (vm.exists(filePath)) {
            // Need to delete it
            vm.removeFile(filePath);
        }
        vm.writeLine(filePath, "{ metadata: ");
        // string memory rootAsString = Strings.toHexString(uint256(manageTree[manageTree.length - 1][0]));
        string[] memory composition = new string[](5);
        composition[0] = "Bytes20(DECODER_AND_SANITIZER)";
        composition[1] = "Bytes20(TARGET_ADDRESS)";
        composition[2] = "Bytes1(CAN_SEND_VALUE)";
        composition[3] = "Bytes4(TARGET_FUNCTION_SELECTOR)";
        composition[4] = "Bytes{N*20}(ADDRESS_ARGUMENT_0,...ADDRESS_ARGUMENT_N)";
        string memory metadata = "ManageRoot";
        vm.serializeUint(metadata, "LeafCount", leafs.length);
        vm.serializeString(metadata, "DigestComposition", composition);
        string memory finalMetadata = vm.serializeBytes32(metadata, "manageRoot", manageTree[manageTree.length - 1][0]);

        vm.writeLine(filePath, finalMetadata);
        vm.writeLine(filePath, ",");
        vm.writeLine(filePath, "leafs: [");

        for (uint256 i; i < leafs.length; ++i) {
            string memory leaf = "leaf";
            vm.serializeAddress(leaf, "TargetAddress", leafs[i].target);
            vm.serializeBool(leaf, "CanSendValue", leafs[i].canSendValue);
            vm.serializeString(leaf, "FunctionSignature", leafs[i].signature);
            bytes4 sel = bytes4(keccak256(abi.encodePacked(leafs[i].signature)));
            string memory selector = Strings.toHexString(uint32(sel), 4);
            vm.serializeString(leaf, "FunctionSelector", selector);
            bytes memory packedData;
            for (uint256 j; j < leafs[i].argumentAddresses.length; ++j) {
                packedData = abi.encodePacked(packedData, leafs[i].argumentAddresses[j]);
            }
            vm.serializeBytes(leaf, "PackedArgumentAddresses", packedData);
            vm.serializeAddress(leaf, "AddressArguments", leafs[i].argumentAddresses);
            bytes32 digest = keccak256(
                abi.encodePacked(leafs[i].decoderAndSanitizer, leafs[i].target, leafs[i].canSendValue, sel, packedData)
            );
            vm.serializeBytes32(leaf, "LeafDigest", digest);

            string memory finalJson = vm.serializeString(leaf, "Description", leafs[i].description);

            // vm.writeJson(finalJson, filePath);
            vm.writeLine(filePath, finalJson);
            vm.writeLine(filePath, ",");
        }
        vm.writeLine(filePath, "]}");
    }

    function sliceString(string calldata ss) external pure returns (string memory s) {
        s = ss[:8];
    }

    // ========================================= HELPER FUNCTIONS =========================================
    struct ManageLeaf {
        address target;
        bool canSendValue;
        string signature;
        address[] argumentAddresses;
        string description;
        address decoderAndSanitizer;
    }

    function _buildTrees(bytes32[][] memory merkleTreeIn) internal pure returns (bytes32[][] memory merkleTreeOut) {
        // We are adding another row to the merkle tree, so make merkleTreeOut be 1 longer.
        uint256 merkleTreeIn_length = merkleTreeIn.length;
        merkleTreeOut = new bytes32[][](merkleTreeIn_length + 1);
        uint256 layer_length;
        // Iterate through merkleTreeIn to copy over data.
        for (uint256 i; i < merkleTreeIn_length; ++i) {
            layer_length = merkleTreeIn[i].length;
            merkleTreeOut[i] = new bytes32[](layer_length);
            for (uint256 j; j < layer_length; ++j) {
                merkleTreeOut[i][j] = merkleTreeIn[i][j];
            }
        }

        uint256 next_layer_length;
        if (layer_length % 2 != 0) {
            next_layer_length = (layer_length + 1) / 2;
        } else {
            next_layer_length = layer_length / 2;
        }
        merkleTreeOut[merkleTreeIn_length] = new bytes32[](next_layer_length);
        uint256 count;
        for (uint256 i; i < layer_length; i += 2) {
            merkleTreeOut[merkleTreeIn_length][count] =
                _hashPair(merkleTreeIn[merkleTreeIn_length - 1][i], merkleTreeIn[merkleTreeIn_length - 1][i + 1]);
            count++;
        }

        if (next_layer_length > 1) {
            // We need to process the next layer of leaves.
            merkleTreeOut = _buildTrees(merkleTreeOut);
        }
    }

    function _generateMerkleTree(ManageLeaf[] memory manageLeafs) internal view returns (bytes32[][] memory tree) {
        uint256 leafsLength = manageLeafs.length;
        bytes32[][] memory leafs = new bytes32[][](1);
        leafs[0] = new bytes32[](leafsLength);
        for (uint256 i; i < leafsLength; ++i) {
            bytes4 selector = bytes4(keccak256(abi.encodePacked(manageLeafs[i].signature)));
            bytes memory rawDigest = abi.encodePacked(
                rawDataDecoderAndSanitizer, manageLeafs[i].target, manageLeafs[i].canSendValue, selector
            );
            uint256 argumentAddressesLength = manageLeafs[i].argumentAddresses.length;
            for (uint256 j; j < argumentAddressesLength; ++j) {
                rawDigest = abi.encodePacked(rawDigest, manageLeafs[i].argumentAddresses[j]);
            }
            leafs[0][i] = keccak256(rawDigest);
        }
        tree = _buildTrees(leafs);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b ? _efficientHash(a, b) : _efficientHash(b, a);
    }

    function _efficientHash(bytes32 a, bytes32 b) private pure returns (bytes32 value) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, a)
            mstore(0x20, b)
            value := keccak256(0x00, 0x40)
        }
    }

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function _finalizeRequest(uint256 requestId, uint256 amount) internal {
        // Spoof unstEth contract into finalizing our request.
        IWithdrawRequestNft w = IWithdrawRequestNft(withdrawalRequestNft);
        address owner = w.owner();
        vm.startPrank(owner);
        w.updateAdmin(address(this), true);
        vm.stopPrank();

        ILiquidityPool lp = ILiquidityPool(EETH_LIQUIDITY_POOL);

        deal(address(this), amount);
        lp.deposit{value: amount}();
        address admin = lp.etherFiAdminContract();

        vm.startPrank(admin);
        lp.addEthAmountLockedForWithdrawal(uint128(amount));
        vm.stopPrank();

        w.finalizeRequests(requestId);
    }
}

interface IWithdrawRequestNft {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 tokenId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function finalizeRequests(uint256 requestId) external;

    function owner() external view returns (address);

    function updateAdmin(address admin, bool isAdmin) external;
}

interface ILiquidityPool {
    function deposit() external payable returns (uint256);

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);

    function amountForShare(uint256 shares) external view returns (uint256);

    function etherFiAdminContract() external view returns (address);

    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
}
