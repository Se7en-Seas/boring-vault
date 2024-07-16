// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseMerkleRootGenerator} from "resources/BaseMerkleRootGenerator.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {RolesAuthority, Authority} from "@solmate/auth/authorities/RolesAuthority.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/CreateKarakVaultMerkleRoot.s.sol:CreateKarakVaultMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateKarakVaultMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x7223442cad8e9cA474fC40109ab981608F8c4273;
    address public managerAddress = 0x91A2482EA778F3C9AAE1d3768D9e558D6794b972;
    address public accountantAddress = 0x126af21dc55C300B7D0bBfC4F3898F558aE8156b;
    address public rawDataDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbDecoderAndSanitizer = 0xcfa57ea1b1E138cf89050253CcF5d0836566C06D;

    address public itbKmETHPositionManager = 0x280f4eE00dD5A96D328ec91B182b2c0F9d0eB815;
    address public itbKweETHPositionManager = 0x276E81Fb6A0b445F923Fe113a934a5B22e62a54C;
    address public itbKwstETHPositionManager = 0xFdc479a18d06e2721d17024b549f3f6173a68805;
    address public itbKrETHPositionManager = 0xD0F54aDE213836b89c4B23672FEa229E5e93E32B;
    address public itbKcbETHPositionManager = 0x7De645f12394531a614c1e83B5e944150adB4Ac3;
    address public itbKwBETHPositionManager = 0x89572fc9410F7e9a99Ce2bE6483642658821bB06;
    address public itbKswETHPositionManager = 0x2F43bC3eFcEDd87CeDe894Ad4155da0A1385D7Ee;
    address public itbKETHxPositionManager = 0x6fCbdFF6CaBef0cDf1492Dc95FDb34702009358b;
    address public itbKsfrxETHPositionManager = 0x2166064650f7E0E9B6cade910Fa135FC26FED40D;
    address public itbKrswETHPositionManager = 0x94181838802D67C2e71EF3710b03819deD6E7734;
    address public itbKrsETHPositionManager = 0xCeba81baFc7958ea51731869942326ffddB3554C;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateKarakVaultStrategistMerkleRoot();
    }

    function generateKarakVaultStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", itbDecoderAndSanitizer);

        leafIndex = 0;

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== ITB Karak Position Managers ==========================
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKmETHPositionManager,
            getAddress(sourceChain, "kmETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKweETHPositionManager,
            getAddress(sourceChain, "kweETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKwstETHPositionManager,
            getAddress(sourceChain, "kwstETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKrETHPositionManager,
            getAddress(sourceChain, "krETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKcbETHPositionManager,
            getAddress(sourceChain, "kcbETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKwBETHPositionManager,
            getAddress(sourceChain, "kwBETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKswETHPositionManager,
            getAddress(sourceChain, "kswETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKETHxPositionManager,
            getAddress(sourceChain, "kETHx"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKsfrxETHPositionManager,
            getAddress(sourceChain, "ksfrxETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKrswETHPositionManager,
            getAddress(sourceChain, "krswETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );
        _addLeafsForITBKarakPositionManager(
            leafs,
            itbDecoderAndSanitizer,
            itbKrsETHPositionManager,
            getAddress(sourceChain, "krsETH"),
            getAddress(sourceChain, "vaultSupervisor")
        );

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        _addNativeLeafs(leafs);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](56);
        token0[0] = getAddress(sourceChain, "WETH");
        token0[1] = getAddress(sourceChain, "WETH");
        token0[2] = getAddress(sourceChain, "WETH");
        token0[3] = getAddress(sourceChain, "WETH");
        token0[4] = getAddress(sourceChain, "WETH");
        token0[5] = getAddress(sourceChain, "WETH");
        token0[6] = getAddress(sourceChain, "WETH");
        token0[7] = getAddress(sourceChain, "WETH");
        token0[8] = getAddress(sourceChain, "WETH");
        token0[9] = getAddress(sourceChain, "WETH");
        token0[10] = getAddress(sourceChain, "WEETH");
        token0[11] = getAddress(sourceChain, "WEETH");
        token0[12] = getAddress(sourceChain, "WEETH");
        token0[13] = getAddress(sourceChain, "WEETH");
        token0[14] = getAddress(sourceChain, "WEETH");
        token0[15] = getAddress(sourceChain, "WEETH");
        token0[16] = getAddress(sourceChain, "WEETH");
        token0[17] = getAddress(sourceChain, "WEETH");
        token0[18] = getAddress(sourceChain, "WEETH");
        token0[19] = getAddress(sourceChain, "WSTETH");
        token0[20] = getAddress(sourceChain, "WSTETH");
        token0[21] = getAddress(sourceChain, "WSTETH");
        token0[22] = getAddress(sourceChain, "WSTETH");
        token0[23] = getAddress(sourceChain, "WSTETH");
        token0[24] = getAddress(sourceChain, "WSTETH");
        token0[25] = getAddress(sourceChain, "WSTETH");
        token0[26] = getAddress(sourceChain, "WSTETH");
        token0[27] = getAddress(sourceChain, "RETH");
        token0[28] = getAddress(sourceChain, "RETH");
        token0[29] = getAddress(sourceChain, "RETH");
        token0[30] = getAddress(sourceChain, "RETH");
        token0[31] = getAddress(sourceChain, "RETH");
        token0[32] = getAddress(sourceChain, "RETH");
        token0[33] = getAddress(sourceChain, "RETH");
        token0[34] = getAddress(sourceChain, "cbETH");
        token0[35] = getAddress(sourceChain, "cbETH");
        token0[36] = getAddress(sourceChain, "cbETH");
        token0[37] = getAddress(sourceChain, "cbETH");
        token0[38] = getAddress(sourceChain, "cbETH");
        token0[39] = getAddress(sourceChain, "cbETH");
        token0[40] = getAddress(sourceChain, "WBETH");
        token0[41] = getAddress(sourceChain, "WBETH");
        token0[42] = getAddress(sourceChain, "WBETH");
        token0[43] = getAddress(sourceChain, "WBETH");
        token0[44] = getAddress(sourceChain, "WBETH");
        token0[45] = getAddress(sourceChain, "METH");
        token0[46] = getAddress(sourceChain, "METH");
        token0[47] = getAddress(sourceChain, "METH");
        token0[48] = getAddress(sourceChain, "METH");
        token0[49] = getAddress(sourceChain, "SWETH");
        token0[50] = getAddress(sourceChain, "SWETH");
        token0[51] = getAddress(sourceChain, "SWETH");
        token0[52] = getAddress(sourceChain, "ETHX");
        token0[53] = getAddress(sourceChain, "ETHX");
        token0[54] = getAddress(sourceChain, "RSWETH");
        token0[55] = getAddress(sourceChain, "WETH");

        address[] memory token1 = new address[](56);
        token1[0] = getAddress(sourceChain, "WEETH");
        token1[1] = getAddress(sourceChain, "WSTETH");
        token1[2] = getAddress(sourceChain, "RETH");
        token1[3] = getAddress(sourceChain, "cbETH");
        token1[4] = getAddress(sourceChain, "WBETH");
        token1[5] = getAddress(sourceChain, "METH");
        token1[6] = getAddress(sourceChain, "SWETH");
        token1[7] = getAddress(sourceChain, "ETHX");
        token1[8] = getAddress(sourceChain, "RSWETH");
        token1[9] = getAddress(sourceChain, "SFRXETH");
        token1[10] = getAddress(sourceChain, "WSTETH");
        token1[11] = getAddress(sourceChain, "RETH");
        token1[12] = getAddress(sourceChain, "cbETH");
        token1[13] = getAddress(sourceChain, "WBETH");
        token1[14] = getAddress(sourceChain, "METH");
        token1[15] = getAddress(sourceChain, "SWETH");
        token1[16] = getAddress(sourceChain, "ETHX");
        token1[17] = getAddress(sourceChain, "RSWETH");
        token1[18] = getAddress(sourceChain, "SFRXETH");
        token1[19] = getAddress(sourceChain, "RETH");
        token1[20] = getAddress(sourceChain, "cbETH");
        token1[21] = getAddress(sourceChain, "WBETH");
        token1[22] = getAddress(sourceChain, "METH");
        token1[23] = getAddress(sourceChain, "SWETH");
        token1[24] = getAddress(sourceChain, "ETHX");
        token1[25] = getAddress(sourceChain, "RSWETH");
        token1[26] = getAddress(sourceChain, "SFRXETH");
        token1[27] = getAddress(sourceChain, "cbETH");
        token1[28] = getAddress(sourceChain, "WBETH");
        token1[29] = getAddress(sourceChain, "METH");
        token1[30] = getAddress(sourceChain, "SWETH");
        token1[31] = getAddress(sourceChain, "ETHX");
        token1[32] = getAddress(sourceChain, "RSWETH");
        token1[33] = getAddress(sourceChain, "SFRXETH");
        token1[34] = getAddress(sourceChain, "WBETH");
        token1[35] = getAddress(sourceChain, "METH");
        token1[36] = getAddress(sourceChain, "SWETH");
        token1[37] = getAddress(sourceChain, "ETHX");
        token1[38] = getAddress(sourceChain, "RSWETH");
        token1[39] = getAddress(sourceChain, "SFRXETH");
        token1[40] = getAddress(sourceChain, "METH");
        token1[41] = getAddress(sourceChain, "SWETH");
        token1[42] = getAddress(sourceChain, "ETHX");
        token1[43] = getAddress(sourceChain, "RSWETH");
        token1[44] = getAddress(sourceChain, "SFRXETH");
        token1[45] = getAddress(sourceChain, "SWETH");
        token1[46] = getAddress(sourceChain, "ETHX");
        token1[47] = getAddress(sourceChain, "RSWETH");
        token1[48] = getAddress(sourceChain, "SFRXETH");
        token1[49] = getAddress(sourceChain, "ETHX");
        token1[50] = getAddress(sourceChain, "RSWETH");
        token1[51] = getAddress(sourceChain, "SFRXETH");
        token1[52] = getAddress(sourceChain, "RSWETH");
        token1[53] = getAddress(sourceChain, "SFRXETH");
        token1[54] = getAddress(sourceChain, "SFRXETH");
        token1[55] = getAddress(sourceChain, "RSETH");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](13);
        SwapKind[] memory kind = new SwapKind[](13);
        assets[0] = getAddress(sourceChain, "WETH");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "WEETH");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WSTETH");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "RETH");
        kind[3] = SwapKind.BuyAndSell;
        assets[4] = getAddress(sourceChain, "cbETH");
        kind[4] = SwapKind.BuyAndSell;
        assets[5] = getAddress(sourceChain, "WBETH");
        kind[5] = SwapKind.BuyAndSell;
        assets[6] = getAddress(sourceChain, "METH");
        kind[6] = SwapKind.BuyAndSell;
        assets[7] = getAddress(sourceChain, "SWETH");
        kind[7] = SwapKind.BuyAndSell;
        assets[8] = getAddress(sourceChain, "ETHX");
        kind[8] = SwapKind.BuyAndSell;
        assets[9] = getAddress(sourceChain, "RSWETH");
        kind[9] = SwapKind.BuyAndSell;
        assets[10] = getAddress(sourceChain, "SFRXETH");
        kind[10] = SwapKind.BuyAndSell;
        assets[11] = getAddress(sourceChain, "INST");
        kind[11] = SwapKind.Sell;
        assets[12] = getAddress(sourceChain, "RSETH");
        kind[12] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/KarakVaultStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
