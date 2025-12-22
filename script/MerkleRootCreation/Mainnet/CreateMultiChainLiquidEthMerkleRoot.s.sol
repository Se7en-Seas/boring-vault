// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {Strings} from "lib/openzeppelin-contracts/contracts/utils/Strings.sol";
import {ERC4626} from "@solmate/tokens/ERC4626.sol";
import {MerkleTreeHelper} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import "forge-std/Script.sol";

/**
 *  source .env && forge script script/MerkleRootCreation/Mainnet/CreateMultiChainLiquidEthMerkleRoot.s.sol --rpc-url $MAINNET_RPC_URL
 */
contract CreateMultiChainLiquidEthMerkleRootScript is Script, MerkleTreeHelper {
    using FixedPointMathLib for uint256;

    struct AaveAssets {
        ERC20[] supplyAssets;
        ERC20[] claimAssets;
        ERC20[] borrowAssets;
    }

    struct UniswapV3Tokens {
        address[] token0;
        address[] token1;
    }

    struct SwapAssets {
        address[] assets;
        SwapKind[] kinds;
    }

    struct BridgeAssets {
        ERC20[] bridgeAssets;
        ERC20[] ccipBridgeAssets;
        ERC20[] ccipBridgeFeeAssets;
    }

    struct CollateralConfig {
        ERC20[] collateralAssets;
        ERC20[] feeAssets;
        ERC20[] claimTokens;
    }

    address public boringVault = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C;
    address public rawDataDecoderAndSanitizer = 0xB1B5dAe58E10c98f57Fb93d6F5849958a17fd0Ab;
    address public managerAddress = 0x227975088C28DBBb4b421c6d96781a53578f19a8;
    address public accountantAddress = 0x0d05D94a5F1E76C18fbeB7A13d17C8a314088198;
    address public pancakeSwapDataDecoderAndSanitizer = 0x4dE66AA174b99481dAAe12F2Cdd5D76Dc14Eb3BC;
    address public itbDecoderAndSanitizer = 0xEEb53299Cb894968109dfa420D69f0C97c835211;
    address public itbAaveDecoderAndSanitizer = 0x7fA5dbDB1A76d2990Ea0f3c74e520E3fcE94748B;
    address public itbReserveProtocolPositionManager = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
    address public itbAaveLidoPositionManager = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
    address public itbAaveLidoPositionManager2 = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;

    function setUp() external {}

    /**
     * @notice Uncomment which script you want to run.
     */
    function run() external {
        generateLiquidEthStrategistMerkleRoot();
    }

    function generateLiquidEthStrategistMerkleRoot() public {
        setSourceChainName(mainnet);
        setAddress(false, mainnet, "boringVault", boringVault);
        setAddress(false, mainnet, "managerAddress", managerAddress);
        setAddress(false, mainnet, "accountantAddress", accountantAddress);
        setAddress(false, mainnet, "rawDataDecoderAndSanitizer", rawDataDecoderAndSanitizer);

        ManageLeaf[] memory leafs = new ManageLeaf[](1024);

        // ========================== Aave V3 ==========================
        _addAaveV3LeafsWithStruct(leafs);

        // ========================== SparkLend ==========================
        _addSparkLendLeafsWithStruct(leafs);

        // ========================== Aave V3 Lido ==========================
        _addAaveV3LidoLeafsWithStruct(leafs);

        // ========================== Lido ==========================
        _addLidoLeafs(leafs);

        // ========================== EtherFi ==========================
        /**
         * stake, unstake, wrap, unwrap
         */
        _addEtherFiLeafs(leafs);

        // ========================== Native ==========================
        /**
         * wrap, unwrap
         */
        _addNativeLeafs(leafs);

        // ========================== Gearbox ==========================
        _addGearboxLeafs(leafs, ERC4626(getAddress(sourceChain, "dWETHV3")), getAddress(sourceChain, "sdWETHV3"));

        // ========================== MorphoBlue ==========================
        /**
         * weETH/wETH  86.00 LLTV market 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115
         */
        _addMorphoBlueSupplyLeafs(leafs, 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115);

        // ========================== Pendle ==========================
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarket"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleZircuitWeETHMarketAugust"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHMarketJuly"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_weETHs_market_08_28_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHkSeptember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendle_weETHs_market_12_25_24"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleKarakWeETHMarketDecember"), true);
        _addPendleMarketLeafs(leafs, getAddress(sourceChain, "pendleWeETHkDecember"), true);

        // ========================== UniswapV3 ==========================
        _addUniswapV3LeafsWithStruct(leafs);

        // ========================== Fee Claiming ==========================
        /**
         * Claim fees in USDC, DAI, USDT and USDE
         */
        _addFeeClaimingLeafsWithStruct(leafs);

        // ========================== 1inch ==========================
        _add1InchSwappingLeafsWithStruct(leafs);

        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_01"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "rETH_wETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wstETH_rETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "PENDLE_wETH_30"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "wETH_weETH_05"));
        _addLeafsFor1InchUniswapV3Swapping(leafs, getAddress(sourceChain, "GEAR_wETH_100"));

        // ========================== Curve Swapping ==========================
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "weETH_wETH_NG_Pool"));
        _addLeafsForCurveSwapping(leafs, getAddress(sourceChain, "tETH_wstETH_curve_pool"));

        // ========================== Swell ==========================
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "SFRXETH"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleEethPt"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleEethPtDecember"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleEethPtSeptember"), getAddress(sourceChain, "swellSimpleStaking")
        );
        _addSwellSimpleStakingLeafs(
            leafs, getAddress(sourceChain, "pendleZircuitEethPt"), getAddress(sourceChain, "swellSimpleStaking")
        );

        // ========================== Zircuit ==========================
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WEETH"), getAddress(sourceChain, "zircuitSimpleStaking"));
        _addZircuitLeafs(leafs, getAddress(sourceChain, "WSTETH"), getAddress(sourceChain, "zircuitSimpleStaking"));

        // ========================== Balancer ==========================
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rETH_weETH_id"), getAddress(sourceChain, "rETH_weETH_gauge"));
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rETH_wETH_id"), getAddress(sourceChain, "rETH_wETH_gauge"));
        _addBalancerLeafs(
            leafs, getBytes32(sourceChain, "wstETH_wETH_Id"), getAddress(sourceChain, "wstETH_wETH_Gauge")
        );
        _addBalancerLeafs(leafs, getBytes32(sourceChain, "rsETH_wETH_id"), getAddress(sourceChain, "rsETH_wETH_gauge"));

        // ========================== Aura ==========================
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weeth"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_reth_weth"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_wstETH_wETH"));
        _addAuraLeafs(leafs, getAddress(sourceChain, "aura_rsETH_wETH"));

        // ========================== Flashloans ==========================
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WETH"));
        _addBalancerFlashloanLeafs(leafs, getAddress(sourceChain, "WEETH"));

        // ========================== Fluid fToken ==========================
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWETH"));
        _addFluidFTokenLeafs(leafs, getAddress(sourceChain, "fWSTETH"));

        // ========================== FrxEth ==========================
        /**
         * deposit, withdraw
         */
        _addERC4626Leafs(leafs, ERC4626(getAddress(sourceChain, "SFRXETH")));

        // ========================== Curve ==========================
        _addCurveLeafs(
            leafs, getAddress(sourceChain, "weETH_wETH_ng"), 2, getAddress(sourceChain, "weETH_wETH_ng_gauge")
        );

        // ========================== Convex ==========================
        _addConvexLeafs(
            leafs, getERC20(sourceChain, "weETH_wETH_NG_Pool"), getAddress(sourceChain, "weETH_wETH_NG_Convex_Reward")
        );

        // ========================== BoringVaults ==========================
        {
            ERC20[] memory tellerAssets = new ERC20[](11);
            tellerAssets[0] = getERC20(sourceChain, "WETH");
            tellerAssets[1] = getERC20(sourceChain, "EETH");
            tellerAssets[2] = getERC20(sourceChain, "WEETH");
            tellerAssets[3] = getERC20(sourceChain, "WSTETH");
            tellerAssets[4] = getERC20(sourceChain, "CBETH");
            tellerAssets[5] = getERC20(sourceChain, "WBETH");
            tellerAssets[6] = getERC20(sourceChain, "RETH");
            tellerAssets[7] = getERC20(sourceChain, "METH");
            tellerAssets[8] = getERC20(sourceChain, "SWETH");
            tellerAssets[9] = getERC20(sourceChain, "SFRXETH");
            tellerAssets[10] = getERC20(sourceChain, "ETHX");
            address superSymbioticTeller = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861;
            _addTellerLeafs(leafs, superSymbioticTeller, tellerAssets);

            tellerAssets = new ERC20[](13);
            tellerAssets[0] = getERC20(sourceChain, "WETH");
            tellerAssets[1] = getERC20(sourceChain, "EETH");
            tellerAssets[2] = getERC20(sourceChain, "WEETH");
            tellerAssets[3] = getERC20(sourceChain, "WSTETH");
            tellerAssets[4] = getERC20(sourceChain, "CBETH");
            tellerAssets[5] = getERC20(sourceChain, "WBETH");
            tellerAssets[6] = getERC20(sourceChain, "RETH");
            tellerAssets[7] = getERC20(sourceChain, "METH");
            tellerAssets[8] = getERC20(sourceChain, "SWETH");
            tellerAssets[9] = getERC20(sourceChain, "SFRXETH");
            tellerAssets[10] = getERC20(sourceChain, "ETHX");
            tellerAssets[11] = getERC20(sourceChain, "RSWETH");
            tellerAssets[12] = getERC20(sourceChain, "RSETH");
            address kingKarakTeller = 0x929B44db23740E65dF3A81eA4aAB716af1b88474;
            _addTellerLeafs(leafs, kingKarakTeller, tellerAssets);
        }

        // ========================== ITB Reserve ==========================
        ERC20[] memory tokensUsed = new ERC20[](3);
        tokensUsed[0] = getERC20(sourceChain, "SFRXETH");
        tokensUsed[1] = getERC20(sourceChain, "WSTETH");
        tokensUsed[2] = getERC20(sourceChain, "RETH");
        _addLeafsForItbReserve(
            leafs, itbReserveProtocolPositionManager, tokensUsed, "ETHPlus ITB Reserve Protocol Position Manager"
        );

        // ========================== ITB Lido Aave V3 wETH ==========================
        itbDecoderAndSanitizer = itbAaveDecoderAndSanitizer;
        _addItbAaveV3LeafsWithStruct(leafs);

        // ========================== Native Bridge Leafs ==========================
        _addNativeBridgeLeafsWithStruct(leafs);

        // ========================== CCIP Bridge Leafs ==========================
        _addCcipBridgeLeafsWithStruct(leafs);

        // ========================== Standard Bridge ==========================
        {
            ERC20[] memory localTokens = new ERC20[](2);
            localTokens[0] = getERC20(sourceChain, "RETH");
            localTokens[1] = getERC20(sourceChain, "CBETH");
            ERC20[] memory remoteTokens = new ERC20[](2);
            remoteTokens[0] = getERC20(optimism, "RETH");
            remoteTokens[1] = getERC20(optimism, "CBETH");
            _addStandardBridgeLeafs(
                leafs,
                optimism,
                getAddress(optimism, "crossDomainMessenger"),
                getAddress(sourceChain, "optimismResolvedDelegate"),
                getAddress(sourceChain, "optimismStandardBridge"),
                getAddress(sourceChain, "optimismPortal"),
                localTokens,
                remoteTokens
            );

            remoteTokens[0] = getERC20(base, "RETH");
            remoteTokens[1] = getERC20(base, "CBETH");

            _addStandardBridgeLeafs(
                leafs,
                base,
                getAddress(base, "crossDomainMessenger"),
                getAddress(sourceChain, "baseResolvedDelegate"),
                getAddress(sourceChain, "baseStandardBridge"),
                getAddress(sourceChain, "basePortal"),
                localTokens,
                remoteTokens
            );
        }

        // ========================== LayerZero ==========================
        _addLayerZeroLeafs(
            leafs,
            getERC20(sourceChain, "WEETH"),
            getAddress(sourceChain, "EtherFiOFTAdapter"),
            layerZeroOptimismEndpointId
        );
        _addLayerZeroLeafs(
            leafs, getERC20(sourceChain, "WEETH"), getAddress(sourceChain, "EtherFiOFTAdapter"), layerZeroBaseEndpointId
        );

        // ========================== Merkl ==========================
        {
            ERC20[] memory tokensToClaim = new ERC20[](1);
            tokensToClaim[0] = getERC20(sourceChain, "UNI");
            _addMerklLeafs(
                leafs,
                getAddress(sourceChain, "merklDistributor"),
                getAddress(sourceChain, "dev1Address"),
                tokensToClaim
            );
        }

        // ========================== Karak ==========================
        _addKarakLeafs(leafs, getAddress(sourceChain, "vaultSupervisor"), getAddress(sourceChain, "kweETH"));

        // ========================== Treehouse ==========================
        {
            ERC20[] memory routerTokensIn = new ERC20[](1);
            routerTokensIn[0] = getERC20(sourceChain, "WSTETH");
            _addTreehouseLeafs(
                leafs,
                routerTokensIn,
                getAddress(sourceChain, "TreehouseRouter"),
                getAddress(sourceChain, "TreehouseRedemption"),
                getERC20(sourceChain, "tETH"),
                getAddress(sourceChain, "tETH_wstETH_curve_pool"),
                2,
                address(0)
            );
        }

        // ========================== PancakeSwapV3 ==========================
        setAddress(true, sourceChain, "rawDataDecoderAndSanitizer", pancakeSwapDataDecoderAndSanitizer);
        _addPancakeSwapV3LeafsWithStruct(leafs);

        // ========================== Reclamation ==========================
        {
            address reclamationDecoder = 0xd7335170816912F9D06e23d23479589ed63b3c33;
            address target = 0x778aC5d0EE062502fADaa2d300a51dE0869f7995;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
            target = 0xC4F5Ee078a1C4DA280330546C29840d45ab32753;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
            target = 0x572F323Aa330B467C356c5a30Bf9A20480F4fD52;
            _addReclamationLeafs(leafs, target, reclamationDecoder);
        }

        _verifyDecoderImplementsLeafsFunctionSelectors(leafs);

        bytes32[][] memory manageTree = _generateMerkleTree(leafs);

        string memory filePath = "./leafs/MainnetMultiChainLiquidEthStrategistLeafs.json";

        _generateLeafs(filePath, leafs, manageTree[manageTree.length - 1][0], manageTree);
    }

    function _addLeafsForITBPositionManager(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        // acceptOwnership
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "acceptOwnership()",
            new address[](0),
            string.concat("Accept ownership of the ", itbContractName, " contract"),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Transfer
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "transfer(address,uint256)",
                new address[](1),
                string.concat("Transfer ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = itbPositionManager;
            // Withdraw
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdraw(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // WithdrawAll
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawAll(address)",
                new address[](1),
                string.concat("Withdraw all ", tokensUsed[i].symbol(), " from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }
    }

    function _addLeafsForItbAaveV3(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);
        for (uint256 i; i < tokensUsed.length; ++i) {
            // Deposit
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "deposit(address,uint256)",
                new address[](1),
                string.concat("Deposit ", tokensUsed[i].symbol(), " to the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            // Withdraw Supply
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                itbPositionManager,
                false,
                "withdrawSupply(address,uint256)",
                new address[](1),
                string.concat("Withdraw ", tokensUsed[i].symbol(), " supply from the ", itbContractName, " contract"),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
        }

        // Approve Lido v3 Pool to spend tokensUsed.
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafIndex++;
            leafs[leafIndex] = ManageLeaf(
                address(tokensUsed[i]),
                false,
                "approveToken(address,address,uint256)",
                new address[](2),
                string.concat(
                    itbContractName, ": Approve ", tokensUsed[i].symbol(), " to be spent by the Lido v3 Pool"
                ),
                itbDecoderAndSanitizer
            );
            leafs[leafIndex].argumentAddresses[0] = address(tokensUsed[i]);
            leafs[leafIndex].argumentAddresses[1] = getAddress(sourceChain, "v3LidoPool");
        }
    }

    function _addLeafsForItbReserve(
        ManageLeaf[] memory leafs,
        address itbPositionManager,
        ERC20[] memory tokensUsed,
        string memory itbContractName
    ) internal {
        _addLeafsForITBPositionManager(leafs, itbPositionManager, tokensUsed, itbContractName);

        // mint
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "mint(uint256)",
            new address[](0),
            string.concat("Mint ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeem
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeem(uint256,uint256[])",
            new address[](0),
            string.concat("Redeem ", itbContractName),
            itbDecoderAndSanitizer
        );

        // redeemCustom
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "redeemCustom(uint256,uint48[],uint192[],address[],uint256[])",
            new address[](tokensUsed.length),
            string.concat("Redeem custom ", itbContractName),
            itbDecoderAndSanitizer
        );
        for (uint256 i; i < tokensUsed.length; ++i) {
            leafs[leafIndex].argumentAddresses[i] = address(tokensUsed[i]);
        }

        // assemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "assemble(uint256,uint256)",
            new address[](0),
            string.concat("Assemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // disassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "disassemble(uint256,uint256[])",
            new address[](0),
            string.concat("Disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );

        // fullDisassemble
        leafIndex++;
        leafs[leafIndex] = ManageLeaf(
            itbPositionManager,
            false,
            "fullDisassemble(uint256[])",
            new address[](0),
            string.concat("Full disassemble ", itbContractName),
            itbDecoderAndSanitizer
        );
    }

    function _addAaveV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory aaveAssets = AaveAssets({
            supplyAssets: new ERC20[](4),
            claimAssets: new ERC20[](4),
            borrowAssets: new ERC20[](4)
        });

        aaveAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.supplyAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.supplyAssets[3] = getERC20(sourceChain, "RETH");

        aaveAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.claimAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.claimAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.claimAssets[3] = getERC20(sourceChain, "RETH");

        aaveAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        aaveAssets.borrowAssets[1] = getERC20(sourceChain, "WEETH");
        aaveAssets.borrowAssets[2] = getERC20(sourceChain, "WSTETH");
        aaveAssets.borrowAssets[3] = getERC20(sourceChain, "RETH");

        _addAaveV3Leafs(leafs, aaveAssets.supplyAssets, aaveAssets.borrowAssets, aaveAssets.claimAssets);
    }

    function _addUniswapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory uniswapTokens = UniswapV3Tokens({
            token0: new address[](9),
            token1: new address[](9)
        });

        uniswapTokens.token0[0] = getAddress(sourceChain, "WETH");
        uniswapTokens.token0[1] = getAddress(sourceChain, "WETH");
        uniswapTokens.token0[2] = getAddress(sourceChain, "WETH");
        uniswapTokens.token0[3] = getAddress(sourceChain, "WEETH");
        uniswapTokens.token0[4] = getAddress(sourceChain, "WEETH");
        uniswapTokens.token0[5] = getAddress(sourceChain, "WSTETH");
        uniswapTokens.token0[6] = getAddress(sourceChain, "WETH");
        uniswapTokens.token0[7] = getAddress(sourceChain, "WETH");
        uniswapTokens.token0[8] = getAddress(sourceChain, "WETH");

        uniswapTokens.token1[0] = getAddress(sourceChain, "WEETH");
        uniswapTokens.token1[1] = getAddress(sourceChain, "WSTETH");
        uniswapTokens.token1[2] = getAddress(sourceChain, "RETH");
        uniswapTokens.token1[3] = getAddress(sourceChain, "WSTETH");
        uniswapTokens.token1[4] = getAddress(sourceChain, "RETH");
        uniswapTokens.token1[5] = getAddress(sourceChain, "RETH");
        uniswapTokens.token1[6] = getAddress(sourceChain, "SFRXETH");
        uniswapTokens.token1[7] = getAddress(sourceChain, "CBETH");
        uniswapTokens.token1[8] = getAddress(sourceChain, "RSETH");

        _addUniswapV3Leafs(leafs, uniswapTokens.token0, uniswapTokens.token1);
    }

    function _add1InchSwappingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        SwapAssets memory swapAssets = SwapAssets({
            assets: new address[](16),
            kinds: new SwapKind[](16)
        });

        swapAssets.assets[0] = getAddress(sourceChain, "WETH");
        swapAssets.kinds[0] = SwapKind.BuyAndSell;
        swapAssets.assets[1] = getAddress(sourceChain, "WEETH");
        swapAssets.kinds[1] = SwapKind.BuyAndSell;
        swapAssets.assets[2] = getAddress(sourceChain, "WSTETH");
        swapAssets.kinds[2] = SwapKind.BuyAndSell;
        swapAssets.assets[3] = getAddress(sourceChain, "RETH");
        swapAssets.kinds[3] = SwapKind.BuyAndSell;
        swapAssets.assets[4] = getAddress(sourceChain, "GEAR");
        swapAssets.kinds[4] = SwapKind.Sell;
        swapAssets.assets[5] = getAddress(sourceChain, "CRV");
        swapAssets.kinds[5] = SwapKind.Sell;
        swapAssets.assets[6] = getAddress(sourceChain, "CVX");
        swapAssets.kinds[6] = SwapKind.Sell;
        swapAssets.assets[7] = getAddress(sourceChain, "AURA");
        swapAssets.kinds[7] = SwapKind.Sell;
        swapAssets.assets[8] = getAddress(sourceChain, "BAL");
        swapAssets.kinds[8] = SwapKind.Sell;
        swapAssets.assets[9] = getAddress(sourceChain, "PENDLE");
        swapAssets.kinds[9] = SwapKind.Sell;
        swapAssets.assets[10] = getAddress(sourceChain, "SFRXETH");
        swapAssets.kinds[10] = SwapKind.BuyAndSell;
        swapAssets.assets[11] = getAddress(sourceChain, "INST");
        swapAssets.kinds[11] = SwapKind.Sell;
        swapAssets.assets[12] = getAddress(sourceChain, "RSR");
        swapAssets.kinds[12] = SwapKind.Sell;
        swapAssets.assets[13] = getAddress(sourceChain, "CBETH");
        swapAssets.kinds[13] = SwapKind.BuyAndSell;
        swapAssets.assets[14] = getAddress(sourceChain, "RSETH");
        swapAssets.kinds[14] = SwapKind.BuyAndSell;
        swapAssets.assets[15] = getAddress(sourceChain, "CAKE");
        swapAssets.kinds[15] = SwapKind.Sell;

        _addLeafsFor1InchGeneralSwapping(leafs, swapAssets.assets, swapAssets.kinds);
    }

    function _addNativeBridgeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        BridgeAssets memory bridgeAssets = BridgeAssets({
            bridgeAssets: new ERC20[](5),
            ccipBridgeAssets: new ERC20[](1),
            ccipBridgeFeeAssets: new ERC20[](2)
        });

        bridgeAssets.bridgeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.bridgeAssets[1] = getERC20(sourceChain, "WEETH");
        bridgeAssets.bridgeAssets[2] = getERC20(sourceChain, "WSTETH");
        bridgeAssets.bridgeAssets[3] = getERC20(sourceChain, "RETH");
        bridgeAssets.bridgeAssets[4] = getERC20(sourceChain, "CBETH");

        _addArbitrumNativeBridgeLeafs(leafs, bridgeAssets.bridgeAssets);
    }

    function _addCcipBridgeLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        BridgeAssets memory bridgeAssets = BridgeAssets({
            bridgeAssets: new ERC20[](1),
            ccipBridgeAssets: new ERC20[](1),
            ccipBridgeFeeAssets: new ERC20[](2)
        });

        bridgeAssets.ccipBridgeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.ccipBridgeFeeAssets[0] = getERC20(sourceChain, "WETH");
        bridgeAssets.ccipBridgeFeeAssets[1] = getERC20(sourceChain, "LINK");

        _addCcipBridgeLeafs(leafs, ccipArbitrumChainSelector, bridgeAssets.ccipBridgeAssets, bridgeAssets.ccipBridgeFeeAssets);
    }

    function _addFeeClaimingLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        CollateralConfig memory collateralConfig = CollateralConfig({
            collateralAssets: new ERC20[](0),
            feeAssets: new ERC20[](3),
            claimTokens: new ERC20[](0)
        });

        collateralConfig.feeAssets[0] = getERC20(sourceChain, "WETH");
        collateralConfig.feeAssets[1] = getERC20(sourceChain, "WEETH");
        collateralConfig.feeAssets[2] = getERC20(sourceChain, "EETH");

        _addLeafsForFeeClaiming(leafs, collateralConfig.feeAssets);
    }

    function _addPancakeSwapV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        UniswapV3Tokens memory pancakeTokens = UniswapV3Tokens({
            token0: new address[](8),
            token1: new address[](8)
        });

        pancakeTokens.token0[0] = getAddress(sourceChain, "WETH");
        pancakeTokens.token0[1] = getAddress(sourceChain, "WETH");
        pancakeTokens.token0[2] = getAddress(sourceChain, "WETH");
        pancakeTokens.token0[3] = getAddress(sourceChain, "WEETH");
        pancakeTokens.token0[4] = getAddress(sourceChain, "WEETH");
        pancakeTokens.token0[5] = getAddress(sourceChain, "WSTETH");
        pancakeTokens.token0[6] = getAddress(sourceChain, "WETH");
        pancakeTokens.token0[7] = getAddress(sourceChain, "WETH");

        pancakeTokens.token1[0] = getAddress(sourceChain, "WEETH");
        pancakeTokens.token1[1] = getAddress(sourceChain, "WSTETH");
        pancakeTokens.token1[2] = getAddress(sourceChain, "RETH");
        pancakeTokens.token1[3] = getAddress(sourceChain, "WSTETH");
        pancakeTokens.token1[4] = getAddress(sourceChain, "RETH");
        pancakeTokens.token1[5] = getAddress(sourceChain, "RETH");
        pancakeTokens.token1[6] = getAddress(sourceChain, "SFRXETH");
        pancakeTokens.token1[7] = getAddress(sourceChain, "CBETH");

        _addPancakeSwapV3Leafs(leafs, pancakeTokens.token0, pancakeTokens.token1);
    }

    function _addSparkLendLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory sparkAssets = AaveAssets({
            supplyAssets: new ERC20[](4),
            claimAssets: new ERC20[](4),
            borrowAssets: new ERC20[](3)
        });

        sparkAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.supplyAssets[1] = getERC20(sourceChain, "WEETH");
        sparkAssets.supplyAssets[2] = getERC20(sourceChain, "WSTETH");
        sparkAssets.supplyAssets[3] = getERC20(sourceChain, "RETH");

        sparkAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.claimAssets[1] = getERC20(sourceChain, "WEETH");
        sparkAssets.claimAssets[2] = getERC20(sourceChain, "WSTETH");
        sparkAssets.claimAssets[3] = getERC20(sourceChain, "RETH");

        sparkAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");
        sparkAssets.borrowAssets[1] = getERC20(sourceChain, "WSTETH");
        sparkAssets.borrowAssets[2] = getERC20(sourceChain, "RETH");

        _addSparkLendLeafs(leafs, sparkAssets.supplyAssets, sparkAssets.borrowAssets, sparkAssets.claimAssets);
    }

    function _addAaveV3LidoLeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory lidoAssets = AaveAssets({
            supplyAssets: new ERC20[](2),
            claimAssets: new ERC20[](2),
            borrowAssets: new ERC20[](1)
        });

        lidoAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");
        lidoAssets.supplyAssets[1] = getERC20(sourceChain, "WSTETH");

        lidoAssets.claimAssets[0] = getERC20(sourceChain, "WETH");
        lidoAssets.claimAssets[1] = getERC20(sourceChain, "WSTETH");

        lidoAssets.borrowAssets[0] = getERC20(sourceChain, "WETH");

        _addAaveV3LidoLeafs(leafs, lidoAssets.supplyAssets, lidoAssets.borrowAssets, lidoAssets.claimAssets);
    }

    function _addItbAaveV3LeafsWithStruct(ManageLeaf[] memory leafs) internal {
        AaveAssets memory itbAssets = AaveAssets({
            supplyAssets: new ERC20[](1),
            claimAssets: new ERC20[](0),
            borrowAssets: new ERC20[](0)
        });

        itbAssets.supplyAssets[0] = getERC20(sourceChain, "WETH");

        _addLeafsForItbAaveV3(leafs, itbAaveLidoPositionManager, itbAssets.supplyAssets, "ITB Aave V3 WETH");
        _addLeafsForItbAaveV3(leafs, itbAaveLidoPositionManager2, itbAssets.supplyAssets, "ITB Aave V3 WETH 2");
    }
}
