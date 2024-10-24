// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {MainnetAddresses} from "test/resources/MainnetAddresses.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Deployer} from "src/helper/Deployer.sol";
import {ContractNames} from "resources/ContractNames.sol";
import {GenericRateProvider} from "src/helper/GenericRateProvider.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";
import {AccountantWithRateProviders} from "src/base/Roles/AccountantWithRateProviders.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {BoringOnChainQueue} from "src/base/Roles/BoringQueue/BoringOnChainQueue.sol";
import {BoringSolver} from "src/base/Roles/BoringQueue/BoringSolver.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";

import "forge-std/Script.sol";
import "forge-std/StdJson.sol";

/**
 *  source .env && forge script script/DeployBoringQueues.s.sol:DeployBoringQueuesScript --with-gas-price 3000000000 --broadcast --etherscan-api-key $ETHERSCAN_KEY --verify
 * @dev Optionally can change `--with-gas-price` to something more reasonable
 */
contract DeployBoringQueuesScript is Script, ContractNames, MerkleTreeHelper {
    using AddressToBytes32Lib for address;

    uint256 public privateKey;

    address public devOwner = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b;
    address public canSolve = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address public admin = 0x41DFc53B13932a2690C9790527C1967d8579a6ae;
    address public superAdmin = 0xf8553c8552f906C19286F21711721E206EE4909E;
    address public globalOwner = 0xf8553c8552f906C19286F21711721E206EE4909E;

    // Contracts to deploy
    Deployer public deployer;

    // Roles
    uint8 public constant CAN_SOLVE_ROLE = 31;
    uint8 public constant ONLY_QUEUE_ROLE = 32;
    uint8 public constant ADMIN_ROLE = 9;
    uint8 public constant SUPER_ADMIN_ROLE = 8;

    function setUp() external {
        privateKey = vm.envUint("ETHERFI_LIQUID_DEPLOYER");
        vm.createSelectFork("mainnet");
        setSourceChainName(mainnet);
        deployer = Deployer(getAddress(sourceChain, "boringDeployerContract"));
    }

    function run() external {
        // bytes memory creationCode;
        // bytes memory constructorArgs;

        vm.startBroadcast(privateKey);

        // creationCode = type(RolesAuthority).creationCode;
        // constructorArgs = abi.encode(devOwner, Authority(address(0)));
        // RolesAuthority rolesAuthority = RolesAuthority(
        //     deployer.deployContract(BoringOnChainQueuesRolesAuthorityName, creationCode, constructorArgs, 0)
        // );
        RolesAuthority rolesAuthority = RolesAuthority(0x7e30B3B30cE72Bc2028D7D0F5B78c36E697CEa67);

        address[] memory assets = new address[](3);
        //============================== LiquidEth ===============================
        // assets[0] = getAddress(sourceChain, "EETH");
        // assets[1] = getAddress(sourceChain, "WEETH");
        // assets[2] = getAddress(sourceChain, "WSTETH");
        // BoringOnChainQueue.WithdrawAsset[] memory assetsToSetup = new BoringOnChainQueue.WithdrawAsset[](3);
        // assetsToSetup[0] = BoringOnChainQueue.WithdrawAsset({
        //     allowWithdraws: true, // not used in script.
        //     secondsToMaturity: 7 days,
        //     minimumSecondsToDeadline: 3 days,
        //     minDiscount: 1,
        //     maxDiscount: 10,
        //     minimumShares: 0.0001e18
        // });
        // assetsToSetup[1] = BoringOnChainQueue.WithdrawAsset({
        //     allowWithdraws: true, // not used in script.
        //     secondsToMaturity: 7 days,
        //     minimumSecondsToDeadline: 3 days,
        //     minDiscount: 1,
        //     maxDiscount: 10,
        //     minimumShares: 0.0001e18
        // });
        // assetsToSetup[2] = BoringOnChainQueue.WithdrawAsset({
        //     allowWithdraws: true, // not used in script.
        //     secondsToMaturity: 7 days,
        //     minimumSecondsToDeadline: 3 days,
        //     minDiscount: 1,
        //     maxDiscount: 10,
        //     minimumShares: 0.0001e18
        // });

        // _deployContracts(
        //     SymbioticLRTVaultName,
        //     SymbioticLRTVaultAccountantName,
        //     SymbioticLRTVaultQueueName,
        //     SymbioticLRTVaultQueueSolverName,
        //     rolesAuthority,
        //     assets,
        //     assetsToSetup
        // );

        //============================== SkyFall ===============================
        assets[0] = getAddress(sourceChain, "EETH");
        assets[1] = getAddress(sourceChain, "WEETH");
        assets[2] = getAddress(sourceChain, "WETH");
        BoringOnChainQueue.WithdrawAsset[] memory assetsToSetup = new BoringOnChainQueue.WithdrawAsset[](3);
        assetsToSetup[0] = BoringOnChainQueue.WithdrawAsset({
            allowWithdraws: true, // not used in script.
            secondsToMaturity: 300,
            minimumSecondsToDeadline: 3 days,
            minDiscount: 1,
            maxDiscount: 10,
            minimumShares: 0.0001e18
        });
        assetsToSetup[1] = BoringOnChainQueue.WithdrawAsset({
            allowWithdraws: true, // not used in script.
            secondsToMaturity: 300,
            minimumSecondsToDeadline: 3 days,
            minDiscount: 1,
            maxDiscount: 10,
            minimumShares: 0.0001e18
        });
        assetsToSetup[2] = BoringOnChainQueue.WithdrawAsset({
            allowWithdraws: true, // not used in script.
            secondsToMaturity: 300,
            minimumSecondsToDeadline: 3 days,
            minDiscount: 1,
            maxDiscount: 10,
            minimumShares: 0.0001e18
        });

        _deployContracts(
            SkyFallVaultName,
            SkyFallVaultAccountantName,
            SkyFallVaultBoringQueueName,
            SkyFallVaultBoringSolverName,
            rolesAuthority,
            assets,
            assetsToSetup
        );

        rolesAuthority.setUserRole(canSolve, CAN_SOLVE_ROLE, true);
        // rolesAuthority.setUserRole(admin, ADMIN_ROLE, true);
        // rolesAuthority.setUserRole(superAdmin, SUPER_ADMIN_ROLE, true);
        // rolesAuthority.transferOwnership(globalOwner);

        vm.stopBroadcast();
    }

    function _deployContracts(
        string memory boringVaultName,
        string memory accountantName,
        string memory queueName,
        string memory solverName,
        RolesAuthority rolesAuthority,
        address[] memory assets,
        BoringOnChainQueue.WithdrawAsset[] memory assetsToSetup
    ) internal {
        bytes memory creationCode;
        bytes memory constructorArgs;

        address boringVault = deployer.getAddress(boringVaultName);
        address accountant = deployer.getAddress(accountantName);

        creationCode = type(BoringOnChainQueue).creationCode;
        constructorArgs = abi.encode(devOwner, address(rolesAuthority), payable(boringVault), accountant);
        BoringOnChainQueue queue =
            BoringOnChainQueue(deployer.deployContract(queueName, creationCode, constructorArgs, 0));

        creationCode = type(BoringSolver).creationCode;
        constructorArgs = abi.encode(devOwner, address(rolesAuthority), address(queue));
        address solver = deployer.deployContract(solverName, creationCode, constructorArgs, 0);

        // Setup withdraw assets.
        for (uint256 i; i < assets.length; ++i) {
            queue.updateWithdrawAsset(
                assets[i],
                assetsToSetup[i].secondsToMaturity,
                assetsToSetup[i].minimumSecondsToDeadline,
                assetsToSetup[i].minDiscount,
                assetsToSetup[i].maxDiscount,
                assetsToSetup[i].minimumShares
            );
        }

        // Setup RolesAuthority.

        // Public functions.
        rolesAuthority.setPublicCapability(address(queue), BoringOnChainQueue.requestOnChainWithdraw.selector, true);
        rolesAuthority.setPublicCapability(
            address(queue), BoringOnChainQueue.requestOnChainWithdrawWithPermit.selector, true
        );
        rolesAuthority.setPublicCapability(address(queue), BoringOnChainQueue.cancelOnChainWithdraw.selector, true);
        rolesAuthority.setPublicCapability(address(queue), BoringOnChainQueue.replaceOnChainWithdraw.selector, true);
        /// @notice By default the self solve functions are not made public.

        // CAN_SOLVE_ROLE
        rolesAuthority.setRoleCapability(
            CAN_SOLVE_ROLE, solver, BoringOnChainQueue.solveOnChainWithdraws.selector, true
        );
        rolesAuthority.setRoleCapability(CAN_SOLVE_ROLE, solver, BoringSolver.boringRedeemSolve.selector, true);
        rolesAuthority.setRoleCapability(CAN_SOLVE_ROLE, solver, BoringSolver.boringRedeemMintSolve.selector, true);

        // ONLY_QUEUE_ROLE
        rolesAuthority.setRoleCapability(ONLY_QUEUE_ROLE, solver, BoringSolver.boringSolve.selector, true);

        // ADMIN_ROLE
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            ADMIN_ROLE, address(queue), BoringOnChainQueue.cancelUserWithdraws.selector, true
        );
        rolesAuthority.setRoleCapability(ADMIN_ROLE, address(queue), BoringOnChainQueue.pause.selector, true);

        // SUPER_ADMIN_ROLE
        rolesAuthority.setRoleCapability(
            SUPER_ADMIN_ROLE, address(queue), BoringOnChainQueue.updateWithdrawAsset.selector, true
        );
        rolesAuthority.setRoleCapability(SUPER_ADMIN_ROLE, address(queue), BoringOnChainQueue.pause.selector, true);
        rolesAuthority.setRoleCapability(SUPER_ADMIN_ROLE, address(queue), BoringOnChainQueue.unpause.selector, true);
        rolesAuthority.setRoleCapability(
            SUPER_ADMIN_ROLE, address(queue), BoringOnChainQueue.stopWithdrawsInAsset.selector, true
        );
        rolesAuthority.setRoleCapability(
            SUPER_ADMIN_ROLE, address(queue), BoringOnChainQueue.rescueTokens.selector, true
        );
        rolesAuthority.setRoleCapability(SUPER_ADMIN_ROLE, solver, BoringOnChainQueue.rescueTokens.selector, true);

        // Give Queue the OnlyQueue role.
        rolesAuthority.setUserRole(address(queue), ONLY_QUEUE_ROLE, true);
        rolesAuthority.setUserRole(solver, CAN_SOLVE_ROLE, true);

        // Transfer ownership.
        queue.transferOwnership(globalOwner);
        BoringSolver(solver).transferOwnership(globalOwner);
    }
}
