// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {BoringVault} from "src/base/BoringVault.sol";
import {ChainlinkCCIPTeller} from "src/base/Roles/CrossChain/Bridges/CCIP/ChainlinkCCIPTeller.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {IRateProvider} from "src/interfaces/IRateProvider.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MockCCIPRouter} from "src/helper/MockCCIPRouter.sol";
import {Client} from "@ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {TellerWithMultiAssetSupport} from "src/base/Roles/TellerWithMultiAssetSupport.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract ChainlinkCCIPTellerTest is Test, MerkleTreeHelper {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;
    using stdStorage for StdStorage;

    BoringVault public boringVault;

    uint8 public constant ADMIN_ROLE = 1;
    uint8 public constant MINTER_ROLE = 7;
    uint8 public constant BURNER_ROLE = 8;
    uint8 public constant SOLVER_ROLE = 9;
    uint8 public constant QUEUE_ROLE = 10;
    uint8 public constant CAN_SOLVE_ROLE = 11;

    MockCCIPRouter public router;
    ChainlinkCCIPTeller public sourceTeller;
    ChainlinkCCIPTeller public destinationTeller;
    AccountantWithRateProviders public accountant;
    address public payout_address = vm.addr(7777777);
    address internal constant NATIVE = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    ERC20 internal constant NATIVE_ERC20 = ERC20(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE);
    RolesAuthority public rolesAuthority;

    uint64 public constant SOURCE_SELECTOR = 1;
    uint64 public constant DESTINATION_SELECTOR = 2;

    address public solver = vm.addr(54);

    ERC20 internal WETH;
    ERC20 internal EETH;
    ERC20 internal WEETH;
    ERC20 internal LINK;
    address internal liquidV1PriceRouter;
    address internal pendleEethPt;
    ERC20 internal METH;
    address internal mantleLspStaking;
    address internal WEETH_RATE_PROVIDER;

    function setUp() external {
        setSourceChainName("mainnet");
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 19363419;
        _startFork(rpcKey, blockNumber);

        WETH = getERC20(sourceChain, "WETH");
        EETH = getERC20(sourceChain, "EETH");
        WEETH = getERC20(sourceChain, "WEETH");
        LINK = getERC20(sourceChain, "LINK");
        liquidV1PriceRouter = getAddress(sourceChain, "liquidV1PriceRouter");
        pendleEethPt = getAddress(sourceChain, "pendleEethPt");
        METH = getERC20(sourceChain, "METH");
        mantleLspStaking = getAddress(sourceChain, "mantleLspStaking");
        WEETH_RATE_PROVIDER = getAddress(sourceChain, "WEETH_RATE_PROVIDER");

        boringVault = new BoringVault(address(this), "Boring Vault", "BV", 18);

        accountant = new AccountantWithRateProviders(
            address(this), address(boringVault), payout_address, 1e18, address(WETH), 1.001e4, 0.999e4, 1, 0, 0
        );

        router = new MockCCIPRouter();

        sourceTeller = new ChainlinkCCIPTeller(
            address(this), address(boringVault), address(accountant), address(WETH), address(router)
        );

        destinationTeller = new ChainlinkCCIPTeller(
            address(this), address(boringVault), address(accountant), address(WETH), address(router)
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

        router.setFee(LINK, 1e18);

        accountant.setRateProviderData(EETH, true, address(0));
        accountant.setRateProviderData(WEETH, false, address(WEETH_RATE_PROVIDER));

        router.setSenderToSelector(address(sourceTeller), SOURCE_SELECTOR);
        router.setSenderToSelector(address(destinationTeller), DESTINATION_SELECTOR);

        // Give BoringVault some WETH, and this address some shares, and LINK.
        deal(address(WETH), address(boringVault), 1_000e18);
        deal(address(boringVault), address(this), 1_000e18, true);
        deal(address(LINK), address(this), 1_000e18);
    }

    function testBridgingShares(uint96 sharesToBridge) external {
        sharesToBridge = uint96(bound(sharesToBridge, 1, 1_000e18));
        uint256 startingShareBalance = boringVault.balanceOf(address(this));
        // Setup chains on bridge.
        sourceTeller.addChain(DESTINATION_SELECTOR, true, true, address(destinationTeller), 100_000);
        destinationTeller.addChain(SOURCE_SELECTOR, true, true, address(sourceTeller), 100_000);

        // Bridge 100 shares.
        address to = vm.addr(1);
        uint256 expectedFee = 1e18;
        LINK.safeApprove(address(sourceTeller), expectedFee);
        sourceTeller.bridge(sharesToBridge, to, abi.encode(DESTINATION_SELECTOR), LINK, expectedFee);

        assertEq(
            boringVault.balanceOf(address(this)), startingShareBalance - sharesToBridge, "Should have burned shares."
        );

        Client.Any2EVMMessage memory m = router.getLastMessage();

        // Send message to destination.
        vm.prank(address(router));
        destinationTeller.ccipReceive(m);

        assertEq(boringVault.balanceOf(to), sharesToBridge, "To address should have received shares.");
    }

    function testPreviewFee(uint256 fee) external {
        router.setFee(WETH, fee);

        uint256 previewedFee = sourceTeller.previewFee(1e18, address(0), abi.encode(DESTINATION_SELECTOR), WETH);

        assertEq(previewedFee, fee, "Previewed fee should match set fee.");
    }

    function testAdminFunctions() external {
        uint64 newSelector = 3;
        address targetTeller = vm.addr(1);
        uint64 messageGasLimit = 100_000;

        sourceTeller.addChain(newSelector, true, true, targetTeller, messageGasLimit);

        (bool allowMessagesFrom, bool allowMessagesTo, address target, uint64 gasLimit) =
            sourceTeller.selectorToChains(newSelector);

        assertEq(allowMessagesFrom, true, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should allow messages to new chain.");
        assertEq(target, targetTeller, "Target should be set to targetTeller.");
        assertEq(gasLimit, messageGasLimit, "Gas limit should be set to messageGasLimit.");

        sourceTeller.stopMessagesFromChain(newSelector);

        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from destination chain.");
        assertEq(allowMessagesTo, true, "Should still allow messages to destination chain.");
        assertEq(target, targetTeller, "Target should be set to destinationTeller.");
        assertEq(gasLimit, messageGasLimit, "Gas limit should be set to messageGasLimit.");

        sourceTeller.stopMessagesToChain(newSelector);
        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from destination chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to destination chain.");
        assertEq(target, targetTeller, "Target should be set to destinationTeller.");
        assertEq(gasLimit, messageGasLimit, "Gas limit should be set to messageGasLimit.");

        sourceTeller.setChainGasLimit(newSelector, 90_000);
        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from destination chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to destination chain.");
        assertEq(target, targetTeller, "Target should be set to destinationTeller.");
        assertEq(gasLimit, 90_000, "Gas limit should be set to 90_000.");

        address newTargetTeller = vm.addr(2);
        uint64 newMessageGasLimit = 80_000;
        sourceTeller.allowMessagesToChain(newSelector, newTargetTeller, newMessageGasLimit);
        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should not allow messages to new chain.");
        assertEq(target, newTargetTeller, "Target should be set to newTargetTeller.");
        assertEq(gasLimit, newMessageGasLimit, "Gas limit should be set to newMessageGasLimit.");

        address anotherNewTargetTeller = vm.addr(3);
        sourceTeller.allowMessagesFromChain(newSelector, anotherNewTargetTeller);
        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, true, "Should allow messages from new chain.");
        assertEq(allowMessagesTo, true, "Should allow messages to new chain.");
        assertEq(target, anotherNewTargetTeller, "Target should be set to anotherNewTargetTeller.");
        assertEq(gasLimit, newMessageGasLimit, "Gas limit should be set to newMessageGasLimit.");

        sourceTeller.removeChain(newSelector);
        (allowMessagesFrom, allowMessagesTo, target, gasLimit) = sourceTeller.selectorToChains(newSelector);
        assertEq(allowMessagesFrom, false, "Should not allow messages from new chain.");
        assertEq(allowMessagesTo, false, "Should not allow messages to new chain.");
        assertEq(target, address(0), "Target should be set to 0.");
        assertEq(gasLimit, 0, "Gas limit should be set to 0.");
    }

    function testReverts() external {
        // Adding a chain with a zero message gas limit should revert.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(ChainlinkCCIPTeller.ChainlinkCCIPTeller__ZeroMessageGasLimit.selector))
        );
        sourceTeller.addChain(DESTINATION_SELECTOR, true, true, address(destinationTeller), 0);

        // Allowing messages to a chain with a zero message gas limit should revert.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(ChainlinkCCIPTeller.ChainlinkCCIPTeller__ZeroMessageGasLimit.selector))
        );
        sourceTeller.allowMessagesToChain(DESTINATION_SELECTOR, address(destinationTeller), 0);

        // Changing the gas limit to zero should revert.
        vm.expectRevert(
            bytes(abi.encodeWithSelector(ChainlinkCCIPTeller.ChainlinkCCIPTeller__ZeroMessageGasLimit.selector))
        );
        sourceTeller.setChainGasLimit(DESTINATION_SELECTOR, 0);

        // But you can add a chain with a non-zero message gas limit, if messages to are not supported.
        uint64 newChainSelector = 3;
        sourceTeller.addChain(newChainSelector, true, false, address(destinationTeller), 0);

        // If teller is paused bridging is not allowed.
        sourceTeller.pause();
        vm.expectRevert(
            bytes(abi.encodeWithSelector(TellerWithMultiAssetSupport.TellerWithMultiAssetSupport__Paused.selector))
        );
        sourceTeller.bridge(0, address(0), hex"", LINK, 0);

        sourceTeller.unpause();

        // Trying to send messages to a chain that is not supported should revert.
        uint256 expectedFee = 1e18;
        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ChainlinkCCIPTeller.ChainlinkCCIPTeller__MessagesNotAllowedTo.selector, DESTINATION_SELECTOR
                )
            )
        );
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_SELECTOR), LINK, expectedFee);

        // setup chains.
        sourceTeller.addChain(DESTINATION_SELECTOR, true, true, address(destinationTeller), 100_000);
        destinationTeller.addChain(SOURCE_SELECTOR, true, true, address(sourceTeller), 100_000);

        // If the max fee is exceeded the transaction should revert.
        uint256 newFee = 1.01e18;
        router.setFee(LINK, newFee);

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ChainlinkCCIPTeller.ChainlinkCCIPTeller__FeeExceedsMax.selector,
                    DESTINATION_SELECTOR,
                    newFee,
                    expectedFee
                )
            )
        );
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_SELECTOR), LINK, expectedFee);

        router.setFee(LINK, expectedFee);

        // If user forgets approval call reverts too.
        vm.expectRevert(bytes("TRANSFER_FROM_FAILED"));
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_SELECTOR), LINK, expectedFee);

        // Call now succeeds.
        LINK.safeApprove(address(sourceTeller), expectedFee);
        sourceTeller.bridge(1e18, address(this), abi.encode(DESTINATION_SELECTOR), LINK, expectedFee);

        Client.Any2EVMMessage memory m = router.getLastMessage();

        // Send message to destination.
        vm.startPrank(address(router));

        // If source chain selector is wrong messages revert.
        m.sourceChainSelector = 7;
        vm.expectRevert(
            bytes(abi.encodeWithSelector(ChainlinkCCIPTeller.ChainlinkCCIPTeller__MessagesNotAllowedFrom.selector, 7))
        );
        destinationTeller.ccipReceive(m);

        m.sourceChainSelector = SOURCE_SELECTOR;

        // If messages come from the wrong sender they should revert.
        m.sender = abi.encode(vm.addr(1));

        vm.expectRevert(
            bytes(
                abi.encodeWithSelector(
                    ChainlinkCCIPTeller.ChainlinkCCIPTeller__MessagesNotAllowedFromSender.selector,
                    SOURCE_SELECTOR,
                    vm.addr(1)
                )
            )
        );
        destinationTeller.ccipReceive(m);

        m.sender = abi.encode(address(sourceTeller));
        vm.stopPrank();

        // Even if destination teller is paused messages still go through.
        destinationTeller.pause();

        vm.prank(address(router));
        destinationTeller.ccipReceive(m);
    }

    // ========================================= HELPER FUNCTIONS =========================================

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
