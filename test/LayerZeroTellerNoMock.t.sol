// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {
    LayerZeroTeller,
    CrossChainTellerWithGenericBridge
} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
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
        rolesAuthority.setPublicCapability(
            address(sourceTeller), CrossChainTellerWithGenericBridge.depositAndBridge.selector, true
        );
        rolesAuthority.setPublicCapability(
            address(sourceTeller), CrossChainTellerWithGenericBridge.depositAndBridgeWithPermit.selector, true
        );

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

        // Setup deposit assets.
        sourceTeller.updateAssetData(WETH, true, true, 0);

        // Setup chains on bridge.
        sourceTeller.addChain(layerZeroArbitrumEndpointId, true, true, address(sourceTeller), 1_000_000);
    }

    function testBridgingShares(uint96 sharesToBridge) external {
        sharesToBridge = uint96(bound(sharesToBridge, 1, 1_000e18));

        // Get fee.
        address to = vm.addr(1);
        uint256 fee = sourceTeller.previewFee(sharesToBridge, to, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        uint256 expectedFee = 1e18;
        sourceTeller.bridge{value: fee}(
            sharesToBridge, to, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, expectedFee
        );
    }

    function testDepositAndBridgeShares(uint256 depositAmount) external {
        depositAmount = bound(depositAmount, 1, 1_000e18);

        address user = vm.addr(1);
        deal(address(WETH), user, depositAmount);
        uint256 fee =
            sourceTeller.previewFee(uint96(depositAmount), user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        deal(user, fee);
        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        sourceTeller.depositAndBridge{value: fee}(
            WETH, depositAmount, 0, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, fee
        );
        vm.stopPrank();
    }

    function testDepositAndBridgeWithPermit(uint256 amount) external {
        amount = bound(amount, 0.0001e18, 10_000e18);

        uint256 userKey = 111;
        address user = vm.addr(userKey);

        uint256 weETH_amount = amount.mulDivDown(1e18, IRateProvider(WEETH_RATE_PROVIDER).getRate());
        deal(address(WEETH), user, weETH_amount);
        // function sign(uint256 privateKey, bytes32 digest) external pure returns (uint8 v, bytes32 r, bytes32 s);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                WEETH.DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                        user,
                        address(boringVault),
                        weETH_amount,
                        WEETH.nonces(user),
                        block.timestamp
                    )
                )
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(userKey, digest);

        deal(address(WEETH), user, weETH_amount);
        uint256 fee =
            sourceTeller.previewFee(uint96(weETH_amount), user, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20);
        deal(user, fee);

        vm.startPrank(user);
        sourceTeller.depositAndBridgeWithPermit{value: fee}(
            WEETH, weETH_amount, 0, block.timestamp, v, r, s, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, fee
        );
        vm.stopPrank();
    }

    function testDepositAndBridgeSharesReverts() external {
        accountant.updateExchangeRate(0.001e18);
        accountant.unpause();
        uint256 depositAmount = type(uint96).max;

        address user = vm.addr(1);
        deal(address(WETH), user, depositAmount);
        vm.startPrank(user);
        WETH.approve(address(boringVault), depositAmount);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    CrossChainTellerWithGenericBridge.CrossChainTellerWithGenericBridge__UnsafeCastToUint96.selector
                )
            )
        );
        sourceTeller.depositAndBridge(WETH, depositAmount, 0, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, 0);
        vm.stopPrank();

        // Trying to deposit with native asset should revert.
        vm.startPrank(user);
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    CrossChainTellerWithGenericBridge
                        .CrossChainTellerWithGenericBridge__CannotDepositWithNativeAndBridge
                        .selector
                )
            )
        );
        sourceTeller.depositAndBridge(
            NATIVE_ERC20, depositAmount, 0, abi.encode(layerZeroArbitrumEndpointId), NATIVE_ERC20, 0
        );
        vm.stopPrank();
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
