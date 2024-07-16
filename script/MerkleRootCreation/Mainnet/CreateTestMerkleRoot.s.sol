// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateTestMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL --sender 0x2322ba43eFF1542b6A7bAeD35e66099Ea0d12Bd1
 */
contract CreateTestMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xf2b27554d618488f28023467d3F9656c472ea22e;
    address public managerAddress = 0x4180D80018055158cf608A7A7Eb5582C7a0135E8;
    address public accountantAddress = 0xE4100F1Cf42C7CD6E5Cac69002eeD2F1c6d68704;
    address public rawDataDecoderAndSanitizer = address(0);

    address public itbKilnOperatorPositionManager = 0xc31BDE60f00bf1172a59B8EB699c417548Bce0C2;
    address public itbP2POperatorPositionManager = 0x3034dA3ff55466612847a490B6a8380cc6E22306;
    address public itbKarakPositionManager = 0x4d320976e27DA78D7ab3bCe0aA490df179a7414b;
    address public itbDecoderAndSanitizer = 0xF87F3Cf3b1bC0673e037c41b275B4300e1eCF739;

    RolesAuthority public rolesAuthority = RolesAuthority(0xec8CE1a4eD2611c02A42B5B66dd968CdB20a20B9);

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateTestStrategistMerkleRoot();
    }

    function _addLeafsForITBEigenLayerPositionManager(
        ManageLeaf[] memory leafs,
        address positionManager,
        ERC20[] memory tokens,
        address _strategyManager,
        address _delegationManager,
        address liquidStaking,
        address underlying,
        address delegateTo
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ITB Contract: ", vm.toString(positionManager)),
            itbDecoderAndSanitizer
        );
        // Transfer all tokens to the ITB contract.
        for (uint256 i; i < tokens.length; i++) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokens[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokens[i].symbol(), " to ITB Contract: ", vm.toString(positionManager)),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = positionManager;
        }
        // Approval strategy manager to spend all tokens.
        for (uint256 i; i < tokens.length; i++) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                positionManager,
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                string.concat("Approve Strategy Manager to spend ", tokens[i].symbol()),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokens[i]);
            leafs[leafIndex].argumentAddresses[1] = _strategyManager;
        }
        // Withdraw all tokens
        for (uint256 i; i < tokens.length; i++) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                positionManager,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokens[i].symbol(), " from ITB Contract: ", vm.toString(positionManager)),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokens[i]);

            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                positionManager,
                false,
                "withdrawAll(address)",
                new address[](1),
                string.concat(
                    "Withdraw all ", tokens[i].symbol(), " from the ITB Contract: ", vm.toString(positionManager)
                ),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokens[i]);
        }
        // Update strategy manager.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updateStrategyManager(address)",
            new address[](1),
            "Update the strategy manager",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _strategyManager;
        // Update Delegation Manager.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updateDelegationManager(address)",
            new address[](1),
            "Update the delegation manager",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = _delegationManager;
        // Update position config.
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "updatePositionConfig(address,address,address)",
            new address[](3),
            "Update the position config",
            itbDecoderAndSanitizer
        );
        leafs[leafIndex].argumentAddresses[0] = liquidStaking;
        leafs[leafIndex].argumentAddresses[1] = underlying;
        leafs[leafIndex].argumentAddresses[2] = delegateTo;
        // Delegate
        leafIndex++;
        leafs[leafIndex] =
            ManageLeaf(positionManager, false, "delegate()", new address[](0), "Delegate", itbDecoderAndSanitizer);
        // Deposit
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "deposit(uint256,uint256)", new address[](0), "Deposit", itbDecoderAndSanitizer
        );
        // Start Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "startWithdrawal(uint256)",
            new address[](0),
            "Start Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](0),
            "Complete Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](0),
            "Complete Next Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawals
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](0),
            "Complete Next Withdrawals",
            itbDecoderAndSanitizer
        );
        // Override Withdrawal Indexes
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](0),
            "Override Withdrawal Indexes",
            itbDecoderAndSanitizer
        );
        // Assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "assemble(uint256)", new address[](0), "Assemble", itbDecoderAndSanitizer
        );
        // Disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](0),
            "Disassemble",
            itbDecoderAndSanitizer
        );
        // Full Disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](0),
            "Full Disassemble",
            itbDecoderAndSanitizer
        );
    }

    function generateTestStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        leafIndex = 0;

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // TODO Currently there is no leafs for fee claiming.

        // ========================== ITB Eigen Layer Kiln Position Manager ==========================
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = getERC20(sourceChain, "METH");
        _addLeafsForITBEigenLayerPositionManager(
            leafs,
            itbKilnOperatorPositionManager,
            tokens,
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "METH"),
            0x1f8C8b1d78d01bCc42ebdd34Fae60181bD697662
        );

        // ========================== ITB Eigen Layer P2P Position Manager ==========================
        _addLeafsForITBEigenLayerPositionManager(
            leafs,
            itbP2POperatorPositionManager,
            tokens,
            getAddress(sourceChain, "strategyManager"),
            getAddress(sourceChain, "delegationManager"),
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "METH"),
            0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5
        );

        // ========================== ITB Karak Position Manager ==========================
        _addLeafsForITBEigenLayerPositionManager(
            leafs,
            itbKarakPositionManager,
            tokens,
            0x7C22725d1E0871f0043397c9761AD99A86ffD498,
            address(0),
            getAddress(sourceChain, "mETHStrategy"),
            getAddress(sourceChain, "METH"),
            address(0)
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        // vm.startBroadcast();
        // rolesAuthority.setUserRole(dev1Address, 7, true);
        // rolesAuthority.setUserRole(dev1Address, 8, true);
        // ManagerWithMerkleVerification(managerAddress).setManageRoot(dev1Address, manageTree[manageTree.length - 1][0]);

        // ManageLeaf[] memory manageLeafs = new ManageLeaf[](12);
        // manageLeafs[0] = leafs[1]; // Accept ownership of Kiln Position Manager
        // manageLeafs[1] = leafs[2]; // Transfer METH to Kiln Position Manager
        // manageLeafs[2] = leafs[3]; // Approve Strategy Manager to spend METH
        // manageLeafs[3] = leafs[10]; // Deposit mETH
        // manageLeafs[4] = leafs[19]; // Accept ownership of P2P Position Manager
        // manageLeafs[5] = leafs[20]; // Transfer METH to P2P Position Manager
        // manageLeafs[6] = leafs[21]; // Approve Strategy Manager to spend METH
        // manageLeafs[7] = leafs[28]; // Deposit mETH
        // manageLeafs[8] = leafs[37]; // Accept ownership of Karak Position Manager
        // manageLeafs[9] = leafs[38]; // Transfer METH to Karak Position Manager
        // manageLeafs[10] = leafs[39]; // Approve KMETH to spend METH
        // manageLeafs[11] = leafs[46]; // Deposit mETH

        // bytes32[][] memory manageProofs = _getProofsUsingTree(manageLeafs, manageTree);

        // address[] memory targets = new address[](12);
        // targets[0] = itbKilnOperatorPositionManager;
        // targets[1] = getAddress(sourceChain, "METH");
        // targets[2] = itbKilnOperatorPositionManager;
        // targets[3] = itbKilnOperatorPositionManager;
        // targets[4] = itbP2POperatorPositionManager;
        // targets[5] = getAddress(sourceChain, "METH");
        // targets[6] = itbP2POperatorPositionManager;
        // targets[7] = itbP2POperatorPositionManager;
        // targets[8] = itbKarakPositionManager;
        // targets[9] = getAddress(sourceChain, "METH");
        // targets[10] = itbKarakPositionManager;
        // targets[11] = itbKarakPositionManager;

        // bytes[] memory targetData = new bytes[](12);
        // targetData[0] = abi.encodeWithSignature("acceptOwnership()");
        // targetData[1] = abi.encodeWithSignature("transfer(address,uint256)", itbKilnOperatorPositionManager, 0.003e18);
        // targetData[2] = abi.encodeWithSignature(
        //     "approveToken(address,address,uint256)", getAddress(sourceChain, "METH"), strategyManager, type(uint256).max
        // );
        // targetData[3] = abi.encodeWithSignature("deposit(uint256,uint256)", 0.003e18, 0);
        // targetData[4] = abi.encodeWithSignature("acceptOwnership()");
        // targetData[5] = abi.encodeWithSignature("transfer(address,uint256)", itbP2POperatorPositionManager, 0.003e18);
        // targetData[6] = abi.encodeWithSignature(
        //     "approveToken(address,address,uint256)", getAddress(sourceChain, "METH"), strategyManager, type(uint256).max
        // );
        // targetData[7] = abi.encodeWithSignature("deposit(uint256,uint256)", 0.003e18, 0);
        // targetData[8] = abi.encodeWithSignature("acceptOwnership()");
        // targetData[9] = abi.encodeWithSignature("transfer(address,uint256)", itbKarakPositionManager, 0.003e18);
        // targetData[10] = abi.encodeWithSignature(
        //     "approveToken(address,address,uint256)",
        //     getAddress(sourceChain, "METH"),
        //     0x7C22725d1E0871f0043397c9761AD99A86ffD498,
        //     type(uint256).max
        // );
        // targetData[11] = abi.encodeWithSignature("deposit(uint256,uint256)", 0.003e18, 0);

        // address[] memory decodersAndSanitizers = new address[](12);
        // for (uint256 i; i < 12; i++) {
        //     decodersAndSanitizers[i] = itbDecoderAndSanitizer;
        // }

        // ManagerWithMerkleVerification(managerAddress).manageVaultWithMerkleVerification(
        //     manageProofs, decodersAndSanitizers, targets, targetData, new uint256[](12)
        // );

        // vm.stopBroadcast();

        string memory filePath = "./leafs/TestStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
