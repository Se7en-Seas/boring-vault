// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";

/**
 *  source .env && forge script script/CreateKarakVaultMerkleRoot.s.sol:CreateKarakVaultMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateKarakVaultMerkleRootScript is BaseMerkleRootGenerator {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x7223442cad8e9cA474fC40109ab981608F8c4273;
    address public managerAddress = 0x91A2482EA778F3C9AAE1d3768D9e558D6794b972;
    address public accountantAddress = 0x126af21dc55C300B7D0bBfC4F3898F558aE8156b;
    address public rawDataDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbKmETHPositionManager = address(420);
    address public itbKweETHPositionManager = address(420);
    address public itbKwstETHPositionManager = address(420);
    address public itbKrETHPositionManager = address(420);
    address public itbKcbETHPositionManager = address(420);
    address public itbKwBETHPositionManager = address(420);
    address public itbKswETHPositionManager = address(420);
    address public itbKETHxPositionManager = address(420);
    address public itbKsfrxETHPositionManager = address(420);

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateKarakVaultStrategistMerkleRoot();
    }

    function generateKarakVaultStrategistMerkleRoot() public {
        updateAddresses(boringVault, itbDecoderAndSanitizer, managerAddress, accountantAddress);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== ITB Karak Position Managers ==========================
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKmETHPositionManager, kmETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKweETHPositionManager, kweETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKwstETHPositionManager, kwstETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKrETHPositionManager, krETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKcbETHPositionManager, kcbETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKwBETHPositionManager, kwBETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKswETHPositionManager, kswETH, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKETHxPositionManager, kETHx, vaultSupervisor
        );
        _addLeafsForITBKarakPositionManager(
            leafs, itbDecoderAndSanitizer, itbKsfrxETHPositionManager, ksfrxETH, vaultSupervisor
        );

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](55);
        token0[0] = address(WETH);
        token0[1] = address(WETH);
        token0[2] = address(WETH);
        token0[3] = address(WETH);
        token0[4] = address(WETH);
        token0[5] = address(WETH);
        token0[6] = address(WETH);
        token0[7] = address(WETH);
        token0[8] = address(WETH);
        token0[9] = address(WETH);
        token0[10] = address(WEETH);
        token0[11] = address(WEETH);
        token0[12] = address(WEETH);
        token0[13] = address(WEETH);
        token0[14] = address(WEETH);
        token0[15] = address(WEETH);
        token0[16] = address(WEETH);
        token0[17] = address(WEETH);
        token0[18] = address(WEETH);
        token0[19] = address(WSTETH);
        token0[20] = address(WSTETH);
        token0[21] = address(WSTETH);
        token0[22] = address(WSTETH);
        token0[23] = address(WSTETH);
        token0[24] = address(WSTETH);
        token0[25] = address(WSTETH);
        token0[26] = address(WSTETH);
        token0[27] = address(RETH);
        token0[28] = address(RETH);
        token0[29] = address(RETH);
        token0[30] = address(RETH);
        token0[31] = address(RETH);
        token0[32] = address(RETH);
        token0[33] = address(RETH);
        token0[34] = address(cbETH);
        token0[35] = address(cbETH);
        token0[36] = address(cbETH);
        token0[37] = address(cbETH);
        token0[38] = address(cbETH);
        token0[39] = address(cbETH);
        token0[40] = address(WBETH);
        token0[41] = address(WBETH);
        token0[42] = address(WBETH);
        token0[43] = address(WBETH);
        token0[44] = address(WBETH);
        token0[45] = address(METH);
        token0[46] = address(METH);
        token0[47] = address(METH);
        token0[48] = address(METH);
        token0[49] = address(SWETH);
        token0[50] = address(SWETH);
        token0[51] = address(SWETH);
        token0[52] = address(ETHX);
        token0[53] = address(ETHX);
        token0[54] = address(UNIETH);

        address[] memory token1 = new address[](55);
        token1[0] = address(WEETH);
        token1[1] = address(WSTETH);
        token1[2] = address(RETH);
        token1[3] = address(cbETH);
        token1[4] = address(WBETH);
        token1[5] = address(METH);
        token1[6] = address(SWETH);
        token1[7] = address(ETHX);
        token1[8] = address(UNIETH);
        token1[9] = address(SFRXETH);
        token1[10] = address(WSTETH);
        token1[11] = address(RETH);
        token1[12] = address(cbETH);
        token1[13] = address(WBETH);
        token1[14] = address(METH);
        token1[15] = address(SWETH);
        token1[16] = address(ETHX);
        token1[17] = address(UNIETH);
        token1[18] = address(SFRXETH);
        token1[19] = address(RETH);
        token1[20] = address(cbETH);
        token1[21] = address(WBETH);
        token1[22] = address(METH);
        token1[23] = address(SWETH);
        token1[24] = address(ETHX);
        token1[25] = address(UNIETH);
        token1[26] = address(SFRXETH);
        token1[27] = address(cbETH);
        token1[28] = address(WBETH);
        token1[29] = address(METH);
        token1[30] = address(SWETH);
        token1[31] = address(ETHX);
        token1[32] = address(UNIETH);
        token1[33] = address(SFRXETH);
        token1[34] = address(WBETH);
        token1[35] = address(METH);
        token1[36] = address(SWETH);
        token1[37] = address(ETHX);
        token1[38] = address(UNIETH);
        token1[39] = address(SFRXETH);
        token1[40] = address(METH);
        token1[41] = address(SWETH);
        token1[42] = address(ETHX);
        token1[43] = address(UNIETH);
        token1[44] = address(SFRXETH);
        token1[45] = address(SWETH);
        token1[46] = address(ETHX);
        token1[47] = address(UNIETH);
        token1[48] = address(SFRXETH);
        token1[49] = address(ETHX);
        token1[50] = address(UNIETH);
        token1[51] = address(SFRXETH);
        token1[52] = address(UNIETH);
        token1[53] = address(SFRXETH);
        token1[54] = address(SFRXETH);

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](12);
        SwapKind[] memory kind = new SwapKind[](12);
        assets[0] = address(WETH);
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = address(WEETH);
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = address(WSTETH);
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = address(RETH);
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = address(cbETH);
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = address(WBETH);
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = address(METH);
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = address(SWETH);
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = address(ETHX);
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = address(UNIETH);
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = address(SFRXETH);
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = address(INST);
        kind[11] = SwapKind.Sell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(address(SFRXETH)));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/KarakVaultStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
