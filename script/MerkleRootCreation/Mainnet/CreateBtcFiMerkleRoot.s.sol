// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {ManagerWithMerkleVerification} from "src/base/Roles/ManagerWithMerkleVerification.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateBtcFiMerkleRoot.s.sol:CreateBtcFiMerkleRootScript --rpc-url $MAINNET_RPC_URL
 */
contract CreateBtcFiMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0xFE0C961A49E1aEe2AE2d842fE40157365C6d978f;
    address public managerAddress = 0xaE4b4cfBB7A0B90e9455761ed6D93d6Dc1759710;
    address public accountantAddress = 0xf1ecf4802C2b5Cf9c830A4AF297842Daa6D0f986;
    address public rawDataDecoderAndSanitizer = 0xc4149959d8eA6F118A0755029C9a71E1FcDF6477;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](256);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](6);
        token0[0] = getAddress(sourceChain, "WBTC");
        token0[1] = getAddress(sourceChain, "WBTC");
        token0[2] = getAddress(sourceChain, "WBTC");
        token0[3] = getAddress(sourceChain, "pumpBTC");
        token0[4] = getAddress(sourceChain, "pumpBTC");
        token0[5] = getAddress(sourceChain, "fBTC");

        address[] memory token1 = new address[](6);
        token1[0] = getAddress(sourceChain, "fBTC");
        token1[1] = getAddress(sourceChain, "pumpBTC");
        token1[2] = getAddress(sourceChain, "cbBTC");
        token1[3] = getAddress(sourceChain, "fBTC");
        token1[4] = getAddress(sourceChain, "cbBTC");
        token1[5] = getAddress(sourceChain, "cbBTC");

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](4);
        SwapKind[] memory kind = new SwapKind[](4);
        assets[0] = getAddress(sourceChain, "WBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "pumpBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "fBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "cbBTC");
        kind[3] = SwapKind.BuyAndSell;
        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_pumpBTC_market_03_26_25"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_corn_pumpBTC_market_12_25_24"), true);

        // ========================== Corn ==========================
        ERC20[] memory cornTokens = new ERC20[](4);
        cornTokens[0] = ERC20(getAddress(sourceChain, "WBTC"));
        cornTokens[1] = ERC20(getAddress(sourceChain, "pumpBTC"));
        cornTokens[2] = ERC20(getAddress(sourceChain, "fBTC"));
        cornTokens[3] = ERC20(getAddress(sourceChain, "cbBTC"));
        _addLeafsForCornStaking(leafs, cornTokens);

        // ========================== Pump ==========================
        _addLeafsForPumpStaking(leafs, getAddress(sourceChain, "pumpStaking"), getERC20(sourceChain, "WBTC"));
        _addLeafsForPumpStaking(leafs, getAddress(sourceChain, "pumpStaking"), getERC20(sourceChain, "fBTC"));

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        string memory filePath = "./leafs/Mainnet/BtcFiStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
