// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";

/**
 *  source .env && forge script script/CreateTestMerkleRoot.s.sol:CreateTestMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateTestMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xc79cC44DC8A91330872D7815aE9CFB04405952ea;
    address public rawDataDecoderAndSanitizer = 0xdADc9DE5d8C9E2a34875A2CEa0cd415751E1791b;
    address public managerAddress = 0x048a5002E57166a78Dd060B3B36DEd2f404D0a17;
    address public accountantAddress = 0xc6f89cc0551c944CEae872997A4060DC95622D8F;

    address public itbKilnOperatorPositionManager = 0xc31BDE60f00bf1172a59B8EB699c417548Bce0C2;
    address public itbP2POperatorPositionManager = 0x3034dA3ff55466612847a490B6a8380cc6E22306;
    address public itbDecoderAndSanitizer = address(65);

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
            "Accept ownership of the ITB Curve sDAI/sUSDe contract",
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
            positionManager, false, "deposit(uint256,uint256)", new address[](2), "Deposit", itbDecoderAndSanitizer
        );
        // Start Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "startWithdrawal(uint256)",
            new address[](1),
            "Start Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeWithdrawal(uint256,uint256)",
            new address[](2),
            "Complete Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawal
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawal(uint256)",
            new address[](1),
            "Complete Next Withdrawal",
            itbDecoderAndSanitizer
        );
        // Complete Next Withdrawals
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "completeNextWithdrawals(uint256)",
            new address[](1),
            "Complete Next Withdrawals",
            itbDecoderAndSanitizer
        );
        // Override Withdrawal Indexes
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "overrideWithdrawalIndexes(uint256,uint256)",
            new address[](2),
            "Override Withdrawal Indexes",
            itbDecoderAndSanitizer
        );
        // Assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager, false, "assemble(uint256)", new address[](1), "Assemble", itbDecoderAndSanitizer
        );
        // Disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "disassemble(uint256,uint256)",
            new address[](2),
            "Disassemble",
            itbDecoderAndSanitizer
        );
        // Full Disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            positionManager,
            false,
            "fullDisassemble(uint256)",
            new address[](1),
            "Full Disassemble",
            itbDecoderAndSanitizer
        );
    }

    function generateTestStrategistMerkleRoot() public {
        updateAddresses(boringVault, rawDataDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](64);

        // ========================== ITB Eigen Layer Kiln Position Manager ==========================
        ERC20[] memory tokens = new ERC20[](1);
        tokens[0] = METH;
        _addLeafsForITBEigenLayerPositionManager(
            leafs,
            itbKilnOperatorPositionManager,
            tokens,
            strategyManager,
            delegationManager,
            mETHStrategy,
            address(METH),
            0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5
        );

        // ========================== ITB Eigen Layer P2P Position Manager ==========================
        _addLeafsForITBEigenLayerPositionManager(
            leafs,
            itbKilnOperatorPositionManager,
            tokens,
            strategyManager,
            delegationManager,
            mETHStrategy,
            address(METH),
            0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5 // TODO this looks wrong
        );

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/TestStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
