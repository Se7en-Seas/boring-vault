// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {LayerZeroTeller} from "src/base/Roles/CrossChain/Bridges/LayerZero/LayerZeroTeller.sol";
import {PairwiseRateLimiter} from "src/base/Roles/CrossChain/PairwiseRateLimiter.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MockLayerZeroEndPoint} from "src/helper/MockLayerZeroEndPoint.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract LayerZeroTellerTest is Test, MerkleTreeHelper {
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

    MockLayerZeroEndPoint public endPoint;
    LayerZeroTeller public sourceTeller;
    LayerZeroTeller public destinationTeller;
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

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        ZRO = getERC20(sourceChain, "ZRO");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        endPoint = new MockLayerZeroEndPoint();

        sourceTeller = new LayerZeroTeller(
            address(this),
            address(boringVault),
            address(accountant),
            address(WETH),
            address(endPoint),
            address(this),
            address(ZRO)
        );

        destinationTeller = new LayerZeroTeller(
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
        destinationTeller.setAuthority(rolesAuthority);

        rolesAuthority.setRoleCapability(MINTER_ROLE, address(boringVault), BoringVault.enter.selector, true);
        rolesAuthority.setRoleCapability(BURNER_ROLE, address(boringVault), BoringVault.exit.selector, true);

        rolesAuthority.setUserRole(address(sourceTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(sourceTeller), BURNER_ROLE, true);
        rolesAuthority.setUserRole(address(destinationTeller), MINTER_ROLE, true);
        rolesAuthority.setUserRole(address(destinationTeller), BURNER_ROLE, true);

        sourceTeller.updateAssetData(WETH, true, true, 0);
        sourceTeller.updateAssetData(ERC20(NATIVE), true, true, 0);
        sourceTeller.updateAssetData(EETH, true, true, 0);
        sourceTeller.updateAssetData(WEETH, true, true, 0);

        destinationTeller.updateAssetData(WETH, true, true, 0);
        destinationTeller.updateAssetData(ERC20(NATIVE), true, true, 0);
        destinationTeller.updateAssetData(EETH, true, true, 0);
        destinationTeller.updateAssetData(WEETH, true, true, 0);

        endPoint.setFee(NATIVE_ERC20, 0.001e18);
        endPoint.setFee(ZRO, 0);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        endPoint.setSenderToId(address(sourceTeller), SOURCE_ID);
        endPoint.setSenderToId(address(destinationTeller), DESTINATION_ID);

        // Give BoringVault some WETH, and this address some shares.
        deal(address(WETH), address(boringVault), 1_000e18);
        deal(address(boringVault), address(this), 1_000e18, true);

        // Setup chains on bridge.
        sourceTeller.addChain(DESTINATION_ID, true, true, address(destinationTeller), 1_000_000);
        destinationTeller.addChain(SOURCE_ID, true, true, address(sourceTeller), 1_000_000);

        // Setup rate limiting.
        sourceTeller.setOutboundRateLimits(createRateLimitConfig(DESTINATION_ID, 2000 ether, 4 hours));
        destinationTeller.setInboundRateLimits(createRateLimitConfig(SOURCE_ID, 2000 ether, 4 hours));
    }

    function testBridgingShares(uint96 sharesToBridge) external {
        sharesToBridge = uint96(bound(sharesToBridge, 1, 1_000e18));
        // uint256 startingShareBalance = boringVault.balanceOf(address(this));

        // Bridge 100 shares.
        address to = vm.addr(1);
        uint256 expectedFee = 1e18;
        sourceTeller.bridge{value: 0.001e18}(sharesToBridge, to, abi.encode(DESTINATION_ID), NATIVE_ERC20, expectedFee);

        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();

        // Send message to destination.
        vm.prank(address(endPoint));
        LayerZeroTeller(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        assertEq(boringVault.balanceOf(to), sharesToBridge, "To address should have received shares.");
    }

    function testPreviewFee(uint256 fee) external {
        endPoint.setFee(NATIVE_ERC20, fee);

        uint256 previewedFee = sourceTeller.previewFee(1e18, address(0), abi.encode(DESTINATION_ID), NATIVE_ERC20);

        assertEq(previewedFee, fee, "Previewed fee should match set fee.");
    }

    function testAdminFunctions(uint128 msgGas) external {
        uint32 newSelector = 3;
        address targetTeller = vm.addr(1);
        msgGas = uint128(bound(msgGas, 1, 1_000_000));

        sourceTeller.addChain(newSelector, true, true, targetTeller, msgGas);

        (bool allowMessagesFrom, bool allowMessagesTo, uint128 messageGasLimit) = sourceTeller.idToChains(newSelector);

        assertEq(allowMessagesFrom, true, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should allow messages to new chain.");
        assertEq(messageGasLimit, msgGas, "Should have set message gas limit.");

        sourceTeller.stopMessagesFromChain(newSelector);

        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from destination chain.");
        assertEq(allowMessagesTo, true, "Should still allow messages to destination chain.");
        assertEq(messageGasLimit, msgGas, "Should have not changed message gas limit.");

        sourceTeller.stopMessagesToChain(newSelector);
        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from destination chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to destination chain.");
        assertEq(messageGasLimit, msgGas, "Should have not changed message gas limit.");

        address newTargetTeller = vm.addr(2);
        msgGas += 2;
        sourceTeller.allowMessagesToChain(newSelector, newTargetTeller, msgGas);
        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should not allow messages to new chain.");
        assertEq(messageGasLimit, msgGas, "Should have changed message gas limit.");

        address anotherNewTargetTeller = vm.addr(3);
        sourceTeller.allowMessagesFromChain(newSelector, anotherNewTargetTeller);
        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, true, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should allow messages to new chain.");
        assertEq(messageGasLimit, msgGas, "Should have not changed message gas limit.");

        sourceTeller.removeChain(newSelector);
        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from new chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to new chain.");
        assertEq(messageGasLimit, 0, "Should have zeroed message gas limit.");

        sourceTeller.setChainGasLimit(newSelector, msgGas + 1);
        (allowMessagesFrom, allowMessagesTo, messageGasLimit) = sourceTeller.idToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from new chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to new chain.");
        assertEq(messageGasLimit, msgGas + 1, "Should have changed message gas limit.");
    }

    function testReverts() external {
        uint96 sharesToBridge = uint96(bound(uint96(101), 1, 1_000e18));
        bytes memory bridgeData = abi.encode(DESTINATION_ID);
        uint256 bridgeValue = 0.001e18;

        // Test outbound rate limit.
        sourceTeller.setOutboundRateLimits(createRateLimitConfig(DESTINATION_ID, 100, 4 hours));
        // Expect failure by exceeding limit.
        vm.expectRevert(PairwiseRateLimiter.OutboundRateLimitExceeded.selector);
        sourceTeller.bridge{value: bridgeValue}( sharesToBridge, vm.addr(1), bridgeData, NATIVE_ERC20, 1e18);
        
        // Increase limit and retry
        sourceTeller.setOutboundRateLimits(createRateLimitConfig(DESTINATION_ID, 2000 ether, 4 hours));
        sourceTeller.bridge{value: bridgeValue}( sharesToBridge, vm.addr(1), bridgeData, NATIVE_ERC20, 1e18);

        // Test inbound rate limit.
        destinationTeller.setInboundRateLimits(createRateLimitConfig(SOURCE_ID, 100, 4 hours));
        MockLayerZeroEndPoint.Packet memory m = endPoint.getLastMessage();
        // Expect failure by exceeding limit.
        vm.prank(address(endPoint));
        vm.expectRevert(PairwiseRateLimiter.InboundRateLimitExceeded.selector);
        LayerZeroTeller(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);
    
        // Reset limit.
        destinationTeller.setInboundRateLimits(createRateLimitConfig(SOURCE_ID, 2000 ether, 4 hours));

        // Adding a chain with a zero message gas limit should revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(LayerZeroTeller.LayerZeroTeller__ZeroMessageGasLimit.selector)));
        sourceTeller.addChain(DESTINATION_ID, true, true, address(destinationTeller), 0);

        // Allowing messages to a chain with a zero message gas limit should revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(LayerZeroTeller.LayerZeroTeller__ZeroMessageGasLimit.selector)));
        sourceTeller.allowMessagesToChain(DESTINATION_ID, address(destinationTeller), 0);

        // Changing the gas limit to zero should revert.
        vm.expectRevert(bytes(abi.encodeWithSelector(LayerZeroTeller.LayerZeroTeller__ZeroMessageGasLimit.selector)));
        sourceTeller.setChainGasLimit(DESTINATION_ID, 0);

        // If teller is paused bridging is not allowed.
        sourceTeller.pause();
        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector))
        );
        sourceTeller.bridge(0, address(0), hex"", NATIVE_ERC20, 0);

        sourceTeller.unpause();
        sourceTeller.removeChain(DESTINATION_ID);

        // Trying to send messages to a chain that is not supported should revert.
        uint256 expectedFee = 1e18;
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(LayerZeroTeller.LayerZeroTeller__MessagesNotAllowedTo.selector, DESTINATION_ID)
            )
        );
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_ID), NATIVE_ERC20, expectedFee);

        // setup chains.
        sourceTeller.addChain(DESTINATION_ID, true, true, address(destinationTeller), 1_000_000);
        destinationTeller.addChain(SOURCE_ID, true, true, address(sourceTeller), 1_000_000);

        // If the max fee is exceeded the transaction should revert.
        uint256 newFee = 1.01e18;
        endPoint.setFee(NATIVE_ERC20, newFee);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    LayerZeroTeller.LayerZeroTeller__FeeExceedsMax.selector, DESTINATION_ID, newFee, expectedFee
                )
            )
        );
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_ID), NATIVE_ERC20, expectedFee);

        endPoint.setFee(NATIVE_ERC20, 0.001e18);

        sourceTeller.bridge{value: 0.001e18}(1e18, address(this), abi.encode(DESTINATION_ID), NATIVE_ERC20, 1e18);

        m = endPoint.getLastMessage();

        // Send message to destination.
        vm.startPrank(address(endPoint));

        // If source chain selector is wrong messages revert.
        m._origin.srcEid = 7;
        vm.expectRevert();
        LayerZeroTeller(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        m._origin.srcEid = SOURCE_ID;

        // If messages come from the wrong sender they should revert.
        m._origin.sender = vm.addr(100).toBytes32();

        vm.expectRevert();
        LayerZeroTeller(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);

        m._origin.sender = address(sourceTeller).toBytes32();
        vm.stopPrank();

        // Even if destination teller is paused messages still go through.
        destinationTeller.pause();

        vm.prank(address(endPoint));
        LayerZeroTeller(m.to).lzReceive(m._origin, m._guid, m._message, m._executor, m._extraData);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }

    function createRateLimitConfig(
        uint32 peerId,
        uint256 limit,
        uint256 window
    ) internal pure returns (PairwiseRateLimiter.RateLimitConfig[] memory) {
        PairwiseRateLimiter.RateLimitConfig[] memory configs = new PairwiseRateLimiter.RateLimitConfig[](1);
        configs[0] = PairwiseRateLimiter.RateLimitConfig({
            peerEid: peerId,
            limit: limit,
            window: window
        });
        return configs;
    }
}
