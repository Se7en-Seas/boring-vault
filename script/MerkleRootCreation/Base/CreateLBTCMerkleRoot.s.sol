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
 *  source .env && forge script script/MerkleRootCreation/Base/CreateLBTCMerkleRoot.s.sol:CreateLBTCMerkleRootScript --rpc-url $BASE_RPC_URL
 */
contract CreateLBTCMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    address public boringVault = 0x5401b8620E5FB570064CA9114fd1e135fd77D57c;
    address public managerAddress = 0xcf38e37872748E3b66741A42560672A6cef75e9B;
    address public accountantAddress = 0x28634D0c5edC67CF2450E74deA49B90a4FF93dCE;
    address public rawDataDecoderAndSanitizer = address(0); //waiting on crispy

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        /// NOTE Only have 1 function run at a time, otherwise the merkle root created will be wrong.
        generateAdminStrategistMerkleRoot();
    }

    function generateAdminStrategistMerkleRoot() public {
        setSourceChainName(base);
        setAddress(false, base, "boringVault", boringVault);
        setAddress(false, base, "managerAddress", managerAddress);
        setAddress(false, base, "accountantAddress", accountantAddress);
        setAddress(false, base, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](32);

        // ========================== UniswapV3 ==========================
        address[] memory token0 = new address[](5);
        token0[0] = getAddress(sourceChain, "cbBTC");
        token0[1] = getAddress(sourceChain, "LBTC");
        token0[2] = getAddress(sourceChain, "LBTC"); 
        token1[3] = getAddress(sourceChain, "WBTC"); 
        token1[4] = getAddress(sourceChain, "WBTC"); 
        token1[5] = getAddress(sourceChain, "WBTC"); 

        address[] memory token1 = new address[](5);
        token1[0] = getAddress(sourceChain, "WETH");
        token1[1] = getAddress(sourceChain, "WETH");
        token1[2] = getAddress(sourceChain, "cbBTC");
        token1[3] = getAddress(sourceChain, "WETH"); 
        token1[4] = getAddress(sourceChain, "cbBTC"); 
        token1[5] = getAddress(sourceChain, "LBTC"); 

        _addUniswapV3Leafs(leafs, token0, token1);

        // ========================== 1inch ==========================
        address[] memory assets = new address[](3);
        SwapKind[] memory kind = new SwapKind[](3);
        assets[0] = getAddress(sourceChain, "cbBTC");
        kind[0] = SwapKind.BuyAndSell;
        assets[1] = getAddress(sourceChain, "LBTC");
        kind[1] = SwapKind.BuyAndSell;
        assets[2] = getAddress(sourceChain, "WBTC");
        kind[2] = SwapKind.BuyAndSell;
        assets[3] = getAddress(sourceChain, "AERO"); 
        kind[3] = SwapKind.Sell; 
        //assets[3] = getAddress(sourceChain, "PENDLE"); 
        //kind[3] = SwapKind.Sell; 

        _addLeafsFor1InchGeneralSwapping(leafs, assets, kind);

        // ========================== Pendle ==========================
        bool allowOrderLimitFills = true; 
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_LBTC_market_"), allowLimitOrderFills);

        // ========================== Morpho ==========================
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "gauntletWBTCcore"))); 

        // ========================= Aerodrome ========================
        ERC20[] memory token0 = new ERC20[](1); 
        token0[0] = getERC20(sourceChain, "LBTC"); 
        ERC20[] memory token1 = new ERC20[](1); 
        token1[0] = getERC20(sourceChain, "cbBTC"); 

        address[] memory gauges = new address[](1);
        //TODO explicity setting this to 0 as there is no gauge as of yet
        gauges[0] = address(0); 

        _addVelodromeV2Leafs(leafs, token0, token1, getAddress(sourceChain, "aerodromeRouter"), gauges);       

        
        // ========================== Lombard ========================
        _addLombardBTCLeafs(leafs, getERC20(sourceChain, "cbBTC"), getERC20(sourceChain, "LBTC"));    

        string memory filePath = "./leafs/Base/LombardBTCStrategistLeafs.json";

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }
}
