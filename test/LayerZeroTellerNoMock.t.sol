// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LayerZeroTellerNoMockTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;
    using AddressToBytes32Lib for address;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;

    address public endPoint;
    LayerZeroTeller public sourceTeller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal ZRO;
    address internal WEETH_RATE_PROVIDER;

    uint32 public constant SOURCE_ID = 1;
    uint32 public constant DESTINATION_ID = 2;

    address public solver = vm.addr(54);

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 21023546;
        _startFork(rpcKey, blockNumber);

        endPoint = getAddress(sourceChain, "LayerZeroEndPoint");

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ZRO = getERC20(sourceChain, "ZRO");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        sourceTeller = new LayerZeroTeller(
            address(this),
            address(boringVault),
            address(accountant),
            address(WETH),
            address(endPoint),
            address(this),
            address(ZRO)
        );

        rolesAuthority = new RolesAuthority(address(this), Authority(address(0)));

        boringVault.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        sourceTeller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setUserRole(address(sourceTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(sourceTeller), BURNER_ROLE, true);

        sourceTeller.updateAssetData(WETH, true, true, 0);
        sourceTeller.updateAssetData(ERC20(NATIVE), true, true, 0);
        sourceTeller.updateAssetData(EETH, true, true, 0);
        sourceTeller.updateAssetData(WEETH, true, true, 0);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        // Give BoringVault some WETH, and this address some shares.
        deal(address(WETH), address(boringVault), 1_000e18);
        deal(address(boringVault), address(this), 1_000e18, true);

        // Setup chains on bridge.
        sourceTeller.addChain(layerZeroArbitrumEndpointId, true, true, address(sourceTeller));
    }

    function testBridgingShares(uint96 sharesToBridge) external {
        sharesToBridge = uint96(bound(sharesToBridge, 1, 1_000e18));

        // Get fee.
        address to = vm.addr(1);
        uint256 fee = sourceTeller.previewFee(sharesToBridge, to, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        console.log("Fee: ", fee);
        uint256 expectedFee = 1e18;
        sourceTeller.bridge{value: fee}(
            sharesToBridge, to, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, expectedFee
        );
    }

    function testPreviewFee() external {
        uint256 previewedFee =
            sourceTeller.previewFee(1e18, address(0), abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);

        assertGt(previewedFee, 0, "Previewed fee should match set fee.");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
