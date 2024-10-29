// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AddressToBytes32Lib} from "src/helper/AddressToBytes32Lib.sol";

contract ChainValues {
    using AddressToBytes32Lib for address;
    using AddressToBytes32Lib for bytes32;

    string public constant mainnet = "mainnet";
    string public constant polygon = "polygon";
    string public constant bsc = "bsc";
    string public constant avalanche = "avalanche";
    string public constant arbitrum = "arbitrum";
    string public constant optimism = "optimism";
    string public constant base = "base";
    string public constant zircuit = "zircuit";
    string public constant mantle = "mantle";
    string public constant linea = "linea";
    string public constant scroll = "scroll";
    string public constant fraxtal = "fraxtal";
    string public constant holesky = "holesky";

    // Bridging constants.
    uint64 public constant ccipArbitrumChainSelector = 4949039107694359620;
    uint64 public constant ccipMainnetChainSelector = 5009297550715157269;
    uint32 public constant layerZeroBaseEndpointId = 30184;
    uint32 public constant layerZeroMainnetEndpointId = 30101;
    uint32 public constant layerZeroOptimismEndpointId = 30111;
    uint32 public constant layerZeroArbitrumEndpointId = 30110;
    uint32 public constant layerZeroLineaEndpointId = 30183;
    uint32 public constant layerZeroScrollEndpointId = 30214;

    error ChainValues__ZeroAddress(string chainName, string valueName);
    error ChainValues__ZeroBytes32(string chainName, string valueName);
    error ChainValues__ValueAlreadySet(string chainName, string valueName);

    mapping(string => mapping(string => bytes32)) public values;

    function getAddress(string memory chainName, string memory valueName) public view returns (address a) {
        a = values[chainName][valueName].toAddress();
        if (a == address(0)) {
            revert ChainValues__ZeroAddress(chainName, valueName);
        }
    }

    function getERC20(string memory chainName, string memory valueName) public view returns (ERC20 erc20) {
        address a = getAddress(chainName, valueName);
        erc20 = ERC20(a);
    }

    function getBytes32(string memory chainName, string memory valueName) public view returns (bytes32 b) {
        b = values[chainName][valueName];
        if (b == bytes32(0)) {
            revert ChainValues__ZeroBytes32(chainName, valueName);
        }
    }

    function setValue(bool overrideOk, string memory chainName, string memory valueName, bytes32 value) public {
        if (!overrideOk && values[chainName][valueName] != bytes32(0)) {
            revert ChainValues__ValueAlreadySet(chainName, valueName);
        }
        values[chainName][valueName] = value;
    }

    function setAddress(bool overrideOk, string memory chainName, string memory valueName, address value) public {
        setValue(overrideOk, chainName, valueName, value.toBytes32());
    }

    constructor() {
        // Add mainnet values
        _addMainnetValues();
        _addBaseValues();
        _addArbitrumValues();
        _addOptimismValues();
        _addMantleValues();
        _addZircuitValues();
        _addLineaValues();
        _addScrollValues();
        _addFraxtalValues();

        // Add testnet values
        _addHoleskyValues();
    }

    function _addMainnetValues() private {
        values[mainnet]["boringDeployerContract"] = 0xFD65ADF7d2f9ea09287543520a703522E0a360C9.toBytes32();
        // Liquid Ecosystem
        values[mainnet]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[mainnet]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[mainnet]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[mainnet]["liquidV1PriceRouter"] = 0x693799805B502264f9365440B93C113D86a4fFF5.toBytes32();
        values[mainnet]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[mainnet]["liquidMultisig"] = 0xCEA8039076E35a825854c5C2f85659430b06ec96.toBytes32();
        values[mainnet]["liquidEth"] = 0xf0bb20865277aBd641a307eCe5Ee04E79073416C.toBytes32();
        values[mainnet]["liquidEthStrategist"] = 0x41DFc53B13932a2690C9790527C1967d8579a6ae.toBytes32();
        values[mainnet]["liquidEthManager"] = 0x227975088C28DBBb4b421c6d96781a53578f19a8.toBytes32();
        values[mainnet]["superSymbiotic"] = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88.toBytes32();
        values[mainnet]["superSymbioticTeller"] = 0x99dE9e5a3eC2750a6983C8732E6e795A35e7B861.toBytes32();
        values[mainnet]["weETHs"] = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88.toBytes32();

        // DeFi Ecosystem
        values[mainnet]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[mainnet]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[mainnet]["uniV2Router"] = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D.toBytes32();

        // ERC20s
        values[mainnet]["USDC"] = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48.toBytes32();
        values[mainnet]["WETH"] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2.toBytes32();
        values[mainnet]["WBTC"] = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599.toBytes32();
        values[mainnet]["USDT"] = 0xdAC17F958D2ee523a2206206994597C13D831ec7.toBytes32();
        values[mainnet]["TUSD"] = 0x0000000000085d4780B73119b644AE5ecd22b376.toBytes32();
        values[mainnet]["DAI"] = 0x6B175474E89094C44Da98b954EedeAC495271d0F.toBytes32();
        values[mainnet]["WSTETH"] = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0.toBytes32();
        values[mainnet]["STETH"] = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84.toBytes32();
        values[mainnet]["FRAX"] = 0x853d955aCEf822Db058eb8505911ED77F175b99e.toBytes32();
        values[mainnet]["BAL"] = 0xba100000625a3754423978a60c9317c58a424e3D.toBytes32();
        values[mainnet]["COMP"] = 0xc00e94Cb662C3520282E6f5717214004A7f26888.toBytes32();
        values[mainnet]["LINK"] = 0x514910771AF9Ca656af840dff83E8264EcF986CA.toBytes32();
        values[mainnet]["rETH"] = 0xae78736Cd615f374D3085123A210448E74Fc6393.toBytes32();
        values[mainnet]["RETH"] = 0xae78736Cd615f374D3085123A210448E74Fc6393.toBytes32();
        values[mainnet]["cbETH"] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704.toBytes32();
        values[mainnet]["RPL"] = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f.toBytes32();
        values[mainnet]["BOND"] = 0x0391D2021f89DC339F60Fff84546EA23E337750f.toBytes32();
        values[mainnet]["SWETH"] = 0xf951E335afb289353dc249e82926178EaC7DEd78.toBytes32();
        values[mainnet]["AURA"] = 0xC0c293ce456fF0ED870ADd98a0828Dd4d2903DBF.toBytes32();
        values[mainnet]["GHO"] = 0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f.toBytes32();
        values[mainnet]["LUSD"] = 0x5f98805A4E8be255a32880FDeC7F6728C6568bA0.toBytes32();
        values[mainnet]["OHM"] = 0x64aa3364F17a4D01c6f1751Fd97C2BD3D7e7f1D5.toBytes32();
        values[mainnet]["MKR"] = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2.toBytes32();
        values[mainnet]["APE"] = 0x4d224452801ACEd8B2F0aebE155379bb5D594381.toBytes32();
        values[mainnet]["UNI"] = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984.toBytes32();
        values[mainnet]["CRV"] = 0xD533a949740bb3306d119CC777fa900bA034cd52.toBytes32();
        values[mainnet]["CVX"] = 0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B.toBytes32();
        values[mainnet]["FRXETH"] = 0x5E8422345238F34275888049021821E8E08CAa1f.toBytes32();
        values[mainnet]["CRVUSD"] = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E.toBytes32();
        values[mainnet]["OETH"] = 0x856c4Efb76C1D1AE02e20CEB03A2A6a08b0b8dC3.toBytes32();
        values[mainnet]["MKUSD"] = 0x4591DBfF62656E7859Afe5e45f6f47D3669fBB28.toBytes32();
        values[mainnet]["YETH"] = 0x1BED97CBC3c24A4fb5C069C6E311a967386131f7.toBytes32();
        values[mainnet]["ETHX"] = 0xA35b1B31Ce002FBF2058D22F30f95D405200A15b.toBytes32();
        values[mainnet]["weETH"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["WEETH"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["EETH"] = 0x35fA164735182de50811E8e2E824cFb9B6118ac2.toBytes32();
        values[mainnet]["EZETH"] = 0xbf5495Efe5DB9ce00f80364C8B423567e58d2110.toBytes32();
        values[mainnet]["RSETH"] = 0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7.toBytes32();
        values[mainnet]["OSETH"] = 0xf1C9acDc66974dFB6dEcB12aA385b9cD01190E38.toBytes32();
        values[mainnet]["RSWETH"] = 0xFAe103DC9cf190eD75350761e95403b7b8aFa6c0.toBytes32();
        values[mainnet]["PENDLE"] = 0x808507121B80c02388fAd14726482e061B8da827.toBytes32();
        values[mainnet]["SUSDE"] = 0x9D39A5DE30e57443BfF2A8307A4256c8797A3497.toBytes32();
        values[mainnet]["USDE"] = 0x4c9EDD5852cd905f086C759E8383e09bff1E68B3.toBytes32();
        values[mainnet]["GEAR"] = 0xBa3335588D9403515223F109EdC4eB7269a9Ab5D.toBytes32();
        values[mainnet]["SDAI"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();
        values[mainnet]["PYUSD"] = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8.toBytes32();
        values[mainnet]["METH"] = 0xd5F7838F5C461fefF7FE49ea5ebaF7728bB0ADfa.toBytes32();
        values[mainnet]["TBTC"] = 0x18084fbA666a33d37592fA2633fD49a74DD93a88.toBytes32();
        values[mainnet]["INST"] = 0x6f40d4A6237C257fff2dB00FA0510DeEECd303eb.toBytes32();
        values[mainnet]["LBTC"] = 0x8236a87084f8B84306f72007F36F2618A5634494.toBytes32();
        values[mainnet]["RSR"] = 0x320623b8E4fF03373931769A31Fc52A4E78B5d70.toBytes32();
        values[mainnet]["SFRXETH"] = 0xac3E018457B222d93114458476f3E3416Abbe38F.toBytes32();
        values[mainnet]["WBETH"] = 0xa2E3356610840701BDf5611a53974510Ae27E2e1.toBytes32();
        values[mainnet]["UNIETH"] = 0xF1376bceF0f78459C0Ed0ba5ddce976F1ddF51F4.toBytes32();
        values[mainnet]["CBETH"] = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704.toBytes32();
        values[mainnet]["USD0"] = 0x73A15FeD60Bf67631dC6cd7Bc5B6e8da8190aCF5.toBytes32();
        values[mainnet]["USD0_plus"] = 0x35D8949372D46B7a3D5A56006AE77B215fc69bC0.toBytes32();
        values[mainnet]["deUSD"] = 0x15700B564Ca08D9439C58cA5053166E8317aa138.toBytes32();
        values[mainnet]["sdeUSD"] = 0x5C5b196aBE0d54485975D1Ec29617D42D9198326.toBytes32();
        values[mainnet]["pumpBTC"] = 0xF469fBD2abcd6B9de8E169d128226C0Fc90a012e.toBytes32();
        values[mainnet]["CAKE"] = 0x152649eA73beAb28c5b49B26eb48f7EAD6d4c898.toBytes32();
        values[mainnet]["cbBTC"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf.toBytes32();
        values[mainnet]["fBTC"] = 0xC96dE26018A54D51c097160568752c4E3BD6C364.toBytes32();
        values[mainnet]["EIGEN"] = 0xec53bF9167f50cDEB3Ae105f56099aaaB9061F83.toBytes32();
        values[mainnet]["wcUSDCv3"] = 0x27F2f159Fe990Ba83D57f39Fd69661764BEbf37a.toBytes32();
        values[mainnet]["eBTC"] = 0x657e8C867D8B37dCC18fA4Caead9C45EB088C642.toBytes32();

        // Rate providers
        values[mainnet]["WEETH_RATE_PROVIDER"] = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee.toBytes32();
        values[mainnet]["ETHX_RATE_PROVIDER"] = 0xAAE054B9b822554dd1D9d1F48f892B4585D3bbf0.toBytes32();
        values[mainnet]["UNIETH_RATE_PROVIDER"] = 0x2c3b8c5e98A6e89AAAF21Deebf5FF9d08c4A9FF7.toBytes32();

        // Chainlink Datafeeds
        values[mainnet]["WETH_USD_FEED"] = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419.toBytes32();
        values[mainnet]["USDC_USD_FEED"] = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6.toBytes32();
        values[mainnet]["WBTC_USD_FEED"] = 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c.toBytes32();
        values[mainnet]["TUSD_USD_FEED"] = 0xec746eCF986E2927Abd291a2A1716c940100f8Ba.toBytes32();
        values[mainnet]["STETH_USD_FEED"] = 0xCfE54B5cD566aB89272946F602D76Ea879CAb4a8.toBytes32();
        values[mainnet]["DAI_USD_FEED"] = 0xAed0c38402a5d19df6E4c03F4E2DceD6e29c1ee9.toBytes32();
        values[mainnet]["USDT_USD_FEED"] = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D.toBytes32();
        values[mainnet]["COMP_USD_FEED"] = 0xdbd020CAeF83eFd542f4De03e3cF0C28A4428bd5.toBytes32();
        values[mainnet]["fastGasFeed"] = 0x169E633A2D1E6c10dD91238Ba11c4A708dfEF37C.toBytes32();
        values[mainnet]["FRAX_USD_FEED"] = 0xB9E1E3A9feFf48998E45Fa90847ed4D467E8BcfD.toBytes32();
        values[mainnet]["RETH_ETH_FEED"] = 0x536218f9E9Eb48863970252233c8F271f554C2d0.toBytes32();
        values[mainnet]["BOND_ETH_FEED"] = 0xdd22A54e05410D8d1007c38b5c7A3eD74b855281.toBytes32();
        values[mainnet]["CBETH_ETH_FEED"] = 0xF017fcB346A1885194689bA23Eff2fE6fA5C483b.toBytes32();
        values[mainnet]["STETH_ETH_FEED"] = 0x86392dC19c0b719886221c78AB11eb8Cf5c52812.toBytes32();
        values[mainnet]["BAL_USD_FEED"] = 0xdF2917806E30300537aEB49A7663062F4d1F2b5F.toBytes32();
        values[mainnet]["GHO_USD_FEED"] = 0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC.toBytes32();
        values[mainnet]["LUSD_USD_FEED"] = 0x3D7aE7E594f2f2091Ad8798313450130d0Aba3a0.toBytes32();
        values[mainnet]["OHM_ETH_FEED"] = 0x9a72298ae3886221820B1c878d12D872087D3a23.toBytes32();
        values[mainnet]["MKR_USD_FEED"] = 0xec1D1B3b0443256cc3860e24a46F108e699484Aa.toBytes32();
        values[mainnet]["UNI_ETH_FEED"] = 0xD6aA3D25116d8dA79Ea0246c4826EB951872e02e.toBytes32();
        values[mainnet]["APE_USD_FEED"] = 0xD10aBbC76679a20055E167BB80A24ac851b37056.toBytes32();
        values[mainnet]["CRV_USD_FEED"] = 0xCd627aA160A6fA45Eb793D19Ef54f5062F20f33f.toBytes32();
        values[mainnet]["CVX_USD_FEED"] = 0xd962fC30A72A84cE50161031391756Bf2876Af5D.toBytes32();
        values[mainnet]["CVX_ETH_FEED"] = 0xC9CbF687f43176B302F03f5e58470b77D07c61c6.toBytes32();
        values[mainnet]["CRVUSD_USD_FEED"] = 0xEEf0C605546958c1f899b6fB336C20671f9cD49F.toBytes32();
        values[mainnet]["LINK_USD_FEED"] = 0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c.toBytes32();

        // Aave V2 Tokens
        values[mainnet]["aV2WETH"] = 0x030bA81f1c18d280636F32af80b9AAd02Cf0854e.toBytes32();
        values[mainnet]["aV2USDC"] = 0xBcca60bB61934080951369a648Fb03DF4F96263C.toBytes32();
        values[mainnet]["dV2USDC"] = 0x619beb58998eD2278e08620f97007e1116D5D25b.toBytes32();
        values[mainnet]["dV2WETH"] = 0xF63B34710400CAd3e044cFfDcAb00a0f32E33eCf.toBytes32();
        values[mainnet]["aV2WBTC"] = 0x9ff58f4fFB29fA2266Ab25e75e2A8b3503311656.toBytes32();
        values[mainnet]["aV2TUSD"] = 0x101cc05f4A51C0319f570d5E146a8C625198e636.toBytes32();
        values[mainnet]["aV2STETH"] = 0x1982b2F5814301d4e9a8b0201555376e62F82428.toBytes32();
        values[mainnet]["aV2DAI"] = 0x028171bCA77440897B824Ca71D1c56caC55b68A3.toBytes32();
        values[mainnet]["dV2DAI"] = 0x6C3c78838c761c6Ac7bE9F59fe808ea2A6E4379d.toBytes32();
        values[mainnet]["aV2USDT"] = 0x3Ed3B47Dd13EC9a98b44e6204A523E766B225811.toBytes32();
        values[mainnet]["dV2USDT"] = 0x531842cEbbdD378f8ee36D171d6cC9C4fcf475Ec.toBytes32();

        // Aave V3 Tokens
        values[mainnet]["aV3WETH"] = 0x4d5F47FA6A74757f35C14fD3a6Ef8E3C9BC514E8.toBytes32();
        values[mainnet]["aV3USDC"] = 0x98C23E9d8f34FEFb1B7BD6a91B7FF122F4e16F5c.toBytes32();
        values[mainnet]["dV3USDC"] = 0x72E95b8931767C79bA4EeE721354d6E99a61D004.toBytes32();
        values[mainnet]["aV3DAI"] = 0x018008bfb33d285247A21d44E50697654f754e63.toBytes32();
        values[mainnet]["dV3DAI"] = 0xcF8d0c70c850859266f5C338b38F9D663181C314.toBytes32();
        values[mainnet]["dV3WETH"] = 0xeA51d7853EEFb32b6ee06b1C12E6dcCA88Be0fFE.toBytes32();
        values[mainnet]["aV3WBTC"] = 0x5Ee5bf7ae06D1Be5997A1A72006FE6C607eC6DE8.toBytes32();
        values[mainnet]["aV3USDT"] = 0x23878914EFE38d27C4D67Ab83ed1b93A74D4086a.toBytes32();
        values[mainnet]["dV3USDT"] = 0x6df1C1E379bC5a00a7b4C6e67A203333772f45A8.toBytes32();
        values[mainnet]["aV3sDAI"] = 0x4C612E3B15b96Ff9A6faED838F8d07d479a8dD4c.toBytes32();
        values[mainnet]["aV3CrvUsd"] = 0xb82fa9f31612989525992FCfBB09AB22Eff5c85A.toBytes32();
        values[mainnet]["dV3CrvUsd"] = 0x028f7886F3e937f8479efaD64f31B3fE1119857a.toBytes32();
        values[mainnet]["aV3WeETH"] = 0xBdfa7b7893081B35Fb54027489e2Bc7A38275129.toBytes32();

        // Balancer V2 Addresses
        values[mainnet]["BB_A_USD"] = 0xfeBb0bbf162E64fb9D0dfe186E517d84C395f016.toBytes32();
        values[mainnet]["BB_A_USD_V3"] = 0xc443C15033FCB6Cf72cC24f1BDA0Db070DdD9786.toBytes32();
        values[mainnet]["vanillaUsdcDaiUsdt"] = 0x79c58f70905F734641735BC61e45c19dD9Ad60bC.toBytes32();
        values[mainnet]["BB_A_WETH"] = 0x60D604890feaa0b5460B28A424407c24fe89374a.toBytes32();
        values[mainnet]["wstETH_bbaWETH"] = 0xE0fCBf4d98F0aD982DB260f86cf28b49845403C5.toBytes32();
        values[mainnet]["new_wstETH_bbaWETH"] = 0x41503C9D499ddbd1dCdf818a1b05e9774203Bf46.toBytes32();
        values[mainnet]["GHO_LUSD_BPT"] = 0x3FA8C89704e5d07565444009e5d9e624B40Be813.toBytes32();
        values[mainnet]["swETH_bbaWETH"] = 0xaE8535c23afeDdA9304B03c68a3563B75fc8f92b.toBytes32();
        values[mainnet]["swETH_wETH"] = 0x02D928E68D8F10C0358566152677Db51E1e2Dc8C.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP"] = 0x41FDbea2E52790c0a1Dc374F07b628741f2E062D.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP_Gauge"] = 0xA00DB7d9c465e95e4AA814A9340B9A161364470a.toBytes32();
        values[mainnet]["deUSD_sdeUSD_ECLP_id"] = 0x41fdbea2e52790c0a1dc374f07b628741f2e062d0002000000000000000006be;
        values[mainnet]["aura_deUSD_sdeUSD_ECLP"] = 0x7405Bf405185391525Ab06fABcdFf51fdc656A46.toBytes32();

        values[mainnet]["rETH_weETH_id"] = 0x05ff47afada98a98982113758878f9a8b9fdda0a000000000000000000000645;
        values[mainnet]["rETH_weETH"] = 0x05ff47AFADa98a98982113758878F9A8B9FddA0a.toBytes32();
        values[mainnet]["rETH_weETH_gauge"] = 0xC859BF9d7B8C557bBd229565124c2C09269F3aEF.toBytes32();
        values[mainnet]["aura_reth_weeth"] = 0x07A319A023859BbD49CC9C38ee891c3EA9283Cc5.toBytes32();

        values[mainnet]["ezETH_wETH"] = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E.toBytes32();
        values[mainnet]["ezETH_wETH_gauge"] = 0xa8B309a75f0D64ED632d45A003c68A30e59A1D8b.toBytes32();
        values[mainnet]["aura_ezETH_wETH"] = 0x95eC73Baa0eCF8159b4EE897D973E41f51978E50.toBytes32();

        values[mainnet]["rsETH_ETHx"] = 0x7761b6E0Daa04E70637D81f1Da7d186C205C2aDE.toBytes32();
        values[mainnet]["rsETH_ETHx_gauge"] = 0x0BcDb6d9b27Bd62d3De605393902C7d1a2c71Aab.toBytes32();
        values[mainnet]["aura_rsETH_ETHx"] = 0xf618102462Ff3cf7edbA4c067316F1C3AbdbA193.toBytes32();

        values[mainnet]["rETH_wETH_id"] = 0x1e19cf2d73a72ef1332c882f20534b6519be0276000200000000000000000112;
        values[mainnet]["rETH_wETH"] = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276.toBytes32();
        values[mainnet]["rETH_wETH_gauge"] = 0x79eF6103A513951a3b25743DB509E267685726B7.toBytes32();
        values[mainnet]["aura_reth_weth"] = 0xDd1fE5AD401D4777cE89959b7fa587e569Bf125D.toBytes32();

        values[mainnet]["rsETH_wETH_id"] = 0x58aadfb1afac0ad7fca1148f3cde6aedf5236b6d00000000000000000000067f;
        values[mainnet]["rsETH_wETH"] = 0x58AAdFB1Afac0ad7fca1148f3cdE6aEDF5236B6D.toBytes32();
        values[mainnet]["rsETH_wETH_gauge"] = 0xdf04E3a7ab9857a16FB97174e0f1001aa44380AF.toBytes32();
        values[mainnet]["aura_rsETH_wETH"] = 0xB5FdB4f75C26798A62302ee4959E4281667557E0.toBytes32();

        values[mainnet]["ezETH_weETH_rswETH"] = 0x848a5564158d84b8A8fb68ab5D004Fae11619A54.toBytes32();
        values[mainnet]["ezETH_weETH_rswETH_gauge"] = 0x253ED65fff980AEE7E94a0dC57BE304426048b35.toBytes32();
        values[mainnet]["aura_ezETH_weETH_rswETH"] = 0xce98eb8b2Fb98049b3F2dB0A212Ba7ca3Efd63b0.toBytes32();

        values[mainnet]["BAL_wETH"] = 0x5c6Ee304399DBdB9C8Ef030aB642B10820DB8F56.toBytes32();
        values[mainnet]["PENDLE_wETH"] = 0xFD1Cf6FD41F229Ca86ada0584c63C49C3d66BbC9.toBytes32();
        values[mainnet]["wETH_AURA"] = 0xCfCA23cA9CA720B6E98E3Eb9B6aa0fFC4a5C08B9.toBytes32();

        // values[mainnet]["ezETH_wETH"] = 0x596192bB6e41802428Ac943D2f1476C1Af25CC0E.toBytes32();
        // values[mainnet]["ezETH_wETH_gauge"] = 0xa8B309a75f0D64ED632d45A003c68A30e59A1D8b.toBytes32();
        // values[mainnet]["aura_ezETH_wETH"] = 0x95eC73Baa0eCF8159b4EE897D973E41f51978E50.toBytes32();

        // Linear Pools.
        values[mainnet]["bb_a_dai"] = 0x6667c6fa9f2b3Fc1Cc8D85320b62703d938E4385.toBytes32();
        values[mainnet]["bb_a_usdt"] = 0xA1697F9Af0875B63DdC472d6EeBADa8C1fAB8568.toBytes32();
        values[mainnet]["bb_a_usdc"] = 0xcbFA4532D8B2ade2C261D3DD5ef2A2284f792692.toBytes32();

        values[mainnet]["BB_A_USD_GAUGE"] = 0x0052688295413b32626D226a205b95cDB337DE86.toBytes32(); // query subgraph for gauges wrt to poolId: https://docs.balancer.fi/reference/vebal-and-gauges/gauges.html#query-gauge-by-l2-sidechain-pool:~:text=%23-,Query%20Pending%20Tokens%20for%20a%20Given%20Pool,-The%20process%20differs
        values[mainnet]["BB_A_USD_GAUGE_ADDRESS"] = 0x0052688295413b32626D226a205b95cDB337DE86.toBytes32();
        values[mainnet]["wstETH_bbaWETH_GAUGE_ADDRESS"] = 0x5f838591A5A8048F0E4C4c7fCca8fD9A25BF0590.toBytes32();

        // Mainnet Balancer Specific Addresses
        values[mainnet]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[mainnet]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[mainnet]["relayer"] = 0xfeA793Aa415061C483D2390414275AD314B3F621.toBytes32();
        values[mainnet]["minter"] = 0x239e55F427D44C3cc793f49bFB507ebe76638a2b.toBytes32();
        values[mainnet]["USDC_DAI_USDT_BPT"] = 0x79c58f70905F734641735BC61e45c19dD9Ad60bC.toBytes32();
        values[mainnet]["rETH_wETH_BPT"] = 0x1E19CF2D73a72Ef1332C882F20534B6519Be0276.toBytes32();
        values[mainnet]["wstETH_wETH_BPT"] = 0x32296969Ef14EB0c6d29669C550D4a0449130230.toBytes32();
        values[mainnet]["wstETH_cbETH_BPT"] = 0x9c6d47Ff73e0F5E51BE5FD53236e3F595C5793F2.toBytes32();
        values[mainnet]["bb_a_USD_BPT"] = 0xfeBb0bbf162E64fb9D0dfe186E517d84C395f016.toBytes32();
        values[mainnet]["bb_a_USDC_BPT"] = 0xcbFA4532D8B2ade2C261D3DD5ef2A2284f792692.toBytes32();
        values[mainnet]["bb_a_DAI_BPT"] = 0x6667c6fa9f2b3Fc1Cc8D85320b62703d938E4385.toBytes32();
        values[mainnet]["bb_a_USDT_BPT"] = 0xA1697F9Af0875B63DdC472d6EeBADa8C1fAB8568.toBytes32();
        values[mainnet]["aura_rETH_wETH_BPT"] = 0xDd1fE5AD401D4777cE89959b7fa587e569Bf125D.toBytes32();
        values[mainnet]["GHO_bb_a_USD_BPT"] = 0xc2B021133D1b0cF07dba696fd5DD89338428225B.toBytes32();

        values[mainnet]["wstETH_wETH_BPT"] = 0x93d199263632a4EF4Bb438F1feB99e57b4b5f0BD.toBytes32();
        values[mainnet]["wstETH_wETH_Id"] = 0x93d199263632a4ef4bb438f1feb99e57b4b5f0bd0000000000000000000005c2;
        values[mainnet]["wstETH_wETH_Gauge"] = 0x5C0F23A5c1be65Fa710d385814a7Fd1Bda480b1C.toBytes32();
        values[mainnet]["aura_wstETH_wETH"] = 0x2a14dB8D09dB0542f6A371c0cB308A768227D67D.toBytes32();

        // Rate Providers
        values[mainnet]["cbethRateProvider"] = 0x7311E4BB8a72e7B300c5B8BDE4de6CdaA822a5b1.toBytes32();
        values[mainnet]["rethRateProvider"] = 0x1a8F81c256aee9C640e14bB0453ce247ea0DFE6F.toBytes32();
        values[mainnet]["sDaiRateProvider"] = 0xc7177B6E18c1Abd725F5b75792e5F7A3bA5DBC2c.toBytes32();
        values[mainnet]["rsETHRateProvider"] = 0x746df66bc1Bb361b9E8E2a794C299c3427976e6C.toBytes32();

        // Compound V2
        // Cvalues[mainnet]["cDAI"] = C0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643.toBytes32();
        // Cvalues[mainnet]["cUSDC"] = C0x39AA39c021dfbaE8faC545936693aC917d5E7563.toBytes32();
        // Cvalues[mainnet]["cTUSD"] = C0x12392F67bdf24faE0AF363c24aC620a2f67DAd86.toBytes32();

        // Chainlink Automation Registry
        values[mainnet]["automationRegistry"] = 0x02777053d6764996e594c3E88AF1D58D5363a2e6.toBytes32();
        values[mainnet]["automationRegistryV2"] = 0x6593c7De001fC8542bB1703532EE1E5aA0D458fD.toBytes32();
        values[mainnet]["automationRegistrarV2"] = 0x6B0B234fB2f380309D47A7E9391E29E9a179395a.toBytes32();

        // FraxLend Pairs
        values[mainnet]["FXS_FRAX_PAIR"] = 0xDbe88DBAc39263c47629ebbA02b3eF4cf0752A72.toBytes32();
        values[mainnet]["FPI_FRAX_PAIR"] = 0x74F82Bd9D0390A4180DaaEc92D64cf0708751759.toBytes32();
        values[mainnet]["SFRXETH_FRAX_PAIR"] = 0x78bB3aEC3d855431bd9289fD98dA13F9ebB7ef15.toBytes32();
        values[mainnet]["CRV_FRAX_PAIR"] = 0x3835a58CA93Cdb5f912519ad366826aC9a752510.toBytes32(); // FraxlendV1
        values[mainnet]["WBTC_FRAX_PAIR"] = 0x32467a5fc2d72D21E8DCe990906547A2b012f382.toBytes32(); // FraxlendV1
        values[mainnet]["WETH_FRAX_PAIR"] = 0x794F6B13FBd7EB7ef10d1ED205c9a416910207Ff.toBytes32(); // FraxlendV1
        values[mainnet]["CVX_FRAX_PAIR"] = 0xa1D100a5bf6BFd2736837c97248853D989a9ED84.toBytes32(); // FraxlendV1
        values[mainnet]["MKR_FRAX_PAIR"] = 0x82Ec28636B77661a95f021090F6bE0C8d379DD5D.toBytes32(); // FraxlendV2
        values[mainnet]["APE_FRAX_PAIR"] = 0x3a25B9aB8c07FfEFEe614531C75905E810d8A239.toBytes32(); // FraxlendV2
        values[mainnet]["UNI_FRAX_PAIR"] = 0xc6CadA314389430d396C7b0C70c6281e99ca7fe8.toBytes32(); // FraxlendV2

        /// From Crispy's curve tests

        // Curve Pools and Tokens
        values[mainnet]["TriCryptoPool"] = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46.toBytes32();
        values[mainnet]["CRV_3_CRYPTO"] = 0xc4AD29ba4B3c580e6D59105FFf484999997675Ff.toBytes32();
        values[mainnet]["daiUsdcUsdtPool"] = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7.toBytes32();
        values[mainnet]["CRV_DAI_USDC_USDT"] = 0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490.toBytes32();
        values[mainnet]["frax3CrvPool"] = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B.toBytes32();
        values[mainnet]["CRV_FRAX_3CRV"] = 0xd632f22692FaC7611d2AA1C0D552930D43CAEd3B.toBytes32();
        values[mainnet]["wethCrvPool"] = 0x8301AE4fc9c624d1D396cbDAa1ed877821D7C511.toBytes32();
        values[mainnet]["CRV_WETH_CRV"] = 0xEd4064f376cB8d68F770FB1Ff088a3d0F3FF5c4d.toBytes32();
        values[mainnet]["aave3Pool"] = 0xDeBF20617708857ebe4F679508E7b7863a8A8EeE.toBytes32();
        values[mainnet]["CRV_AAVE_3CRV"] = 0xFd2a8fA60Abd58Efe3EeE34dd494cD491dC14900.toBytes32();
        values[mainnet]["stETHWethNg"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthFrxEthCurvePool"] = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577.toBytes32();
        values[mainnet]["triCrypto2"] = 0xD51a44d3FaE010294C616388b506AcdA1bfAAE46.toBytes32();
        values[mainnet]["weETH_wETH_ng"] = 0xDB74dfDD3BB46bE8Ce6C33dC9D82777BCFc3dEd5.toBytes32();
        values[mainnet]["weETH_wETH_ng_gauge"] = 0x053df3e4D0CeD9a3Bf0494F97E83CE1f13BdC0E2.toBytes32();
        values[mainnet]["USD0_USD0++_CurvePool"] = 0x1d08E7adC263CfC70b1BaBe6dC5Bb339c16Eec52.toBytes32();
        values[mainnet]["USD0_USD0++_CurveGauge"] = 0x5C00817B67b40f3b347bD4275B4BBA4840c8127a.toBytes32();

        values[mainnet]["UsdcCrvUsdPool"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["UsdcCrvUsdToken"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["UsdcCrvUsdGauge"] = 0x95f00391cB5EebCd190EB58728B4CE23DbFa6ac1.toBytes32();
        values[mainnet]["WethRethPool"] = 0x0f3159811670c117c372428D4E69AC32325e4D0F.toBytes32();
        values[mainnet]["WethRethToken"] = 0x6c38cE8984a890F5e46e6dF6117C26b3F1EcfC9C.toBytes32();
        values[mainnet]["WethRethGauge"] = 0x9d4D981d8a9066f5db8532A5816543dE8819d4A8.toBytes32();
        values[mainnet]["UsdtCrvUsdPool"] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4.toBytes32();
        values[mainnet]["UsdtCrvUsdToken"] = 0x390f3595bCa2Df7d23783dFd126427CCeb997BF4.toBytes32();
        values[mainnet]["UsdtCrvUsdGauge"] = 0x4e6bB6B7447B7B2Aa268C16AB87F4Bb48BF57939.toBytes32();
        values[mainnet]["EthStethPool"] = 0xDC24316b9AE028F1497c275EB9192a3Ea0f67022.toBytes32();
        values[mainnet]["EthStethToken"] = 0x06325440D014e39736583c165C2963BA99fAf14E.toBytes32();
        values[mainnet]["EthStethGauge"] = 0x182B723a58739a9c974cFDB385ceaDb237453c28.toBytes32();
        values[mainnet]["FraxUsdcPool"] = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2.toBytes32();
        values[mainnet]["FraxUsdcToken"] = 0x3175Df0976dFA876431C2E9eE6Bc45b65d3473CC.toBytes32();
        values[mainnet]["FraxUsdcGauge"] = 0xCFc25170633581Bf896CB6CDeE170e3E3Aa59503.toBytes32();
        values[mainnet]["WethFrxethPool"] = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc.toBytes32();
        values[mainnet]["WethFrxethToken"] = 0x9c3B46C0Ceb5B9e304FCd6D88Fc50f7DD24B31Bc.toBytes32();
        values[mainnet]["WethFrxethGauge"] = 0x4E21418095d32d15c6e2B96A9910772613A50d50.toBytes32();
        values[mainnet]["EthFrxethPool"] = 0xa1F8A6807c402E4A15ef4EBa36528A3FED24E577.toBytes32();
        values[mainnet]["EthFrxethToken"] = 0xf43211935C781D5ca1a41d2041F397B8A7366C7A.toBytes32();
        values[mainnet]["EthFrxethGauge"] = 0x2932a86df44Fe8D2A706d8e9c5d51c24883423F5.toBytes32();
        values[mainnet]["StethFrxethPool"] = 0x4d9f9D15101EEC665F77210cB999639f760F831E.toBytes32();
        values[mainnet]["StethFrxethToken"] = 0x4d9f9D15101EEC665F77210cB999639f760F831E.toBytes32();
        values[mainnet]["StethFrxethGauge"] = 0x821529Bb07c83803C9CC7763e5974386e9eFEdC7.toBytes32();
        values[mainnet]["WethCvxPool"] = 0xB576491F1E6e5E62f1d8F26062Ee822B40B0E0d4.toBytes32();
        values[mainnet]["WethCvxToken"] = 0x3A283D9c08E8b55966afb64C515f5143cf907611.toBytes32();
        values[mainnet]["WethCvxGauge"] = 0x7E1444BA99dcdFfE8fBdb42C02F0005D14f13BE1.toBytes32();
        values[mainnet]["EthStethNgPool"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthStethNgToken"] = 0x21E27a5E5513D6e65C4f830167390997aA84843a.toBytes32();
        values[mainnet]["EthStethNgGauge"] = 0x79F21BC30632cd40d2aF8134B469a0EB4C9574AA.toBytes32();
        values[mainnet]["EthOethPool"] = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7.toBytes32();
        values[mainnet]["EthOethToken"] = 0x94B17476A93b3262d87B9a326965D1E91f9c13E7.toBytes32();
        values[mainnet]["EthOethGauge"] = 0xd03BE91b1932715709e18021734fcB91BB431715.toBytes32();
        values[mainnet]["FraxCrvUsdPool"] = 0x0CD6f267b2086bea681E922E19D40512511BE538.toBytes32();
        values[mainnet]["FraxCrvUsdToken"] = 0x0CD6f267b2086bea681E922E19D40512511BE538.toBytes32();
        values[mainnet]["FraxCrvUsdGauge"] = 0x96424E6b5eaafe0c3B36CA82068d574D44BE4e3c.toBytes32();
        values[mainnet]["mkUsdFraxUsdcPool"] = 0x0CFe5C777A7438C9Dd8Add53ed671cEc7A5FAeE5.toBytes32();
        values[mainnet]["mkUsdFraxUsdcToken"] = 0x0CFe5C777A7438C9Dd8Add53ed671cEc7A5FAeE5.toBytes32();
        values[mainnet]["mkUsdFraxUsdcGauge"] = 0xF184d80915Ba7d835D941BA70cDdf93DE36517ee.toBytes32();
        values[mainnet]["WethYethPool"] = 0x69ACcb968B19a53790f43e57558F5E443A91aF22.toBytes32();
        values[mainnet]["WethYethToken"] = 0x69ACcb968B19a53790f43e57558F5E443A91aF22.toBytes32();
        values[mainnet]["WethYethGauge"] = 0x138cC21D15b7A06F929Fc6CFC88d2b830796F4f1.toBytes32();
        values[mainnet]["EthEthxPool"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthxToken"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthxGauge"] = 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E.toBytes32();
        values[mainnet]["CrvUsdSdaiPool"] = 0x1539c2461d7432cc114b0903f1824079BfCA2C92.toBytes32();
        values[mainnet]["CrvUsdSdaiToken"] = 0x1539c2461d7432cc114b0903f1824079BfCA2C92.toBytes32();
        values[mainnet]["CrvUsdSdaiGauge"] = 0x2B5a5e182768a18C70EDd265240578a72Ca475ae.toBytes32();
        values[mainnet]["CrvUsdSfraxPool"] = 0xfEF79304C80A694dFd9e603D624567D470e1a0e7.toBytes32();
        values[mainnet]["CrvUsdSfraxToken"] = 0xfEF79304C80A694dFd9e603D624567D470e1a0e7.toBytes32();
        values[mainnet]["CrvUsdSfraxGauge"] = 0x62B8DA8f1546a092500c457452fC2d45fa1777c4.toBytes32();
        values[mainnet]["LusdCrvUsdPool"] = 0x9978c6B08d28d3B74437c917c5dD7C026df9d55C.toBytes32();
        values[mainnet]["LusdCrvUsdToken"] = 0x9978c6B08d28d3B74437c917c5dD7C026df9d55C.toBytes32();
        values[mainnet]["LusdCrvUsdGauge"] = 0x66F65323bdE835B109A92045Aa7c655559dbf863.toBytes32();
        values[mainnet]["WstethEthXPool"] = 0x14756A5eD229265F86990e749285bDD39Fe0334F.toBytes32();
        values[mainnet]["WstethEthXToken"] = 0xfffAE954601cFF1195a8E20342db7EE66d56436B.toBytes32();
        values[mainnet]["WstethEthXGauge"] = 0xc1394d6c89cf8F553da8c8256674C778ccFf3E80.toBytes32();
        values[mainnet]["EthEthXPool"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthXToken"] = 0x59Ab5a5b5d617E478a2479B0cAD80DA7e2831492.toBytes32();
        values[mainnet]["EthEthXGauge"] = 0x7671299eA7B4bbE4f3fD305A994e6443b4be680E.toBytes32();
        values[mainnet]["weETH_wETH_Curve_LP"] = 0x13947303F63b363876868D070F14dc865C36463b.toBytes32();
        values[mainnet]["weETH_wETH_Curve_Gauge"] = 0x1CAC1a0Ed47E2e0A313c712b2dcF85994021a365.toBytes32();
        values[mainnet]["weETH_wETH_Convex_Reward"] = 0x2D159E01A5cEe7498F84Be68276a5266b3cb3774.toBytes32();

        values[mainnet]["weETH_wETH_Pool"] = 0x13947303F63b363876868D070F14dc865C36463b.toBytes32();
        values[mainnet]["weETH_wETH_NG_Pool"] = 0xDB74dfDD3BB46bE8Ce6C33dC9D82777BCFc3dEd5.toBytes32();
        values[mainnet]["weETH_wETH_NG_Convex_Reward"] = 0x5411CC583f0b51104fA523eEF9FC77A29DF80F58.toBytes32();

        values[mainnet]["pyUsd_Usdc_Curve_Pool"] = 0x383E6b4437b59fff47B619CBA855CA29342A8559.toBytes32();
        values[mainnet]["pyUsd_Usdc_Convex_Id"] = address(270).toBytes32();
        values[mainnet]["frax_Usdc_Curve_Pool"] = 0xDcEF968d416a41Cdac0ED8702fAC8128A64241A2.toBytes32();
        values[mainnet]["frax_Usdc_Convex_Id"] = address(100).toBytes32();
        values[mainnet]["usdc_CrvUsd_Curve_Pool"] = 0x4DEcE678ceceb27446b35C672dC7d61F30bAD69E.toBytes32();
        values[mainnet]["usdc_CrvUsd_Convex_Id"] = address(182).toBytes32();
        values[mainnet]["sDai_sUsde_Curve_Pool"] = 0x167478921b907422F8E88B43C4Af2B8BEa278d3A.toBytes32();
        values[mainnet]["sDai_sUsde_Curve_Gauge"] = 0x330Cfd12e0E97B0aDF46158D2A81E8Bd2985c6cB.toBytes32();

        values[mainnet]["ezETH_wETH_Curve_Pool"] = 0x85dE3ADd465a219EE25E04d22c39aB027cF5C12E.toBytes32();
        values[mainnet]["weETH_rswETH_Curve_Pool"] = 0x278cfB6f06B1EFc09d34fC7127d6060C61d629Db.toBytes32();
        values[mainnet]["rswETH_wETH_Curve_Pool"] = 0xeE04382c4cA6c450213923fE0f0daB19b0ff3939.toBytes32();
        values[mainnet]["USDe_USDC_Curve_Pool"] = 0x02950460E2b9529D0E00284A5fA2d7bDF3fA4d72.toBytes32();
        values[mainnet]["USDe_DAI_Curve_Pool"] = 0xF36a4BA50C603204c3FC6d2dA8b78A7b69CBC67d.toBytes32();
        values[mainnet]["sDAI_sUSDe_Curve_Pool"] = 0x167478921b907422F8E88B43C4Af2B8BEa278d3A.toBytes32();
        values[mainnet]["deUSD_USDC_Curve_Pool"] = 0x5F6c431AC417f0f430B84A666a563FAbe681Da94.toBytes32();
        values[mainnet]["deUSD_USDT_Curve_Pool"] = 0x7C4e143B23D72E6938E06291f705B5ae3D5c7c7C.toBytes32();
        values[mainnet]["deUSD_DAI_Curve_Pool"] = 0xb478Bf40dD622086E0d0889eeBbAdCb63806ADde.toBytes32();
        values[mainnet]["deUSD_FRAX_Curve_Pool"] = 0x88DFb9370fE350aA51ADE31C32549d4d3A24fAf2.toBytes32();
        values[mainnet]["deUSD_FRAX_Curve_Gauge"] = 0x7C634909DDbfd5C6EEd7Ccf3611e8C4f3643635d.toBytes32();
        values[mainnet]["eBTC_LBTC_WBTC_Curve_Pool"] = 0xabaf76590478F2fE0b396996f55F0b61101e9502.toBytes32();
        values[mainnet]["eBTC_LBTC_WBTC_Curve_Gauge"] = 0x8D666daED20B502e5Cf692B101028fc0058a5d4E.toBytes32();

        values[mainnet]["lBTC_wBTC_Curve_Pool"] = 0x2f3bC4c27A4437AeCA13dE0e37cdf1028f3706F0.toBytes32();

        values[mainnet]["WethMkUsdPool"] = 0xc89570207c5BA1B0E3cD372172cCaEFB173DB270.toBytes32();

        // Convex-Curve Platform Specifics
        values[mainnet]["convexCurveMainnetBooster"] = 0xF403C135812408BFbE8713b5A23a04b3D48AAE31.toBytes32();

        values[mainnet]["ethFrxethBaseRewardPool"] = 0xbD5445402B0a287cbC77cb67B2a52e2FC635dce4.toBytes32();
        values[mainnet]["ethStethNgBaseRewardPool"] = 0x6B27D7BC63F1999D14fF9bA900069ee516669ee8.toBytes32();
        values[mainnet]["fraxCrvUsdBaseRewardPool"] = 0x3CfB4B26dc96B124D15A6f360503d028cF2a3c00.toBytes32();
        values[mainnet]["mkUsdFraxUsdcBaseRewardPool"] = 0x35FbE5520E70768DCD6E3215Ed54E14CBccA10D2.toBytes32();
        values[mainnet]["wethYethBaseRewardPool"] = 0xB0867ADE998641Ab1Ff04cF5cA5e5773fA92AaE3.toBytes32();
        values[mainnet]["ethEthxBaseRewardPool"] = 0x399e111c7209a741B06F8F86Ef0Fdd88fC198D20.toBytes32();
        values[mainnet]["crvUsdSFraxBaseRewardPool"] = 0x73eA73C3a191bd05F3266eB2414609dC5Fe777a2.toBytes32();
        values[mainnet]["usdtCrvUsdBaseRewardPool"] = 0xD1DdB0a0815fD28932fBb194C84003683AF8a824.toBytes32();
        values[mainnet]["lusdCrvUsdBaseRewardPool"] = 0x633D3B227696B3FacF628a197f982eF68d26c7b5.toBytes32();
        values[mainnet]["wstethEthxBaseRewardPool"] = 0x85b118e0Fa5706d99b270be43d782FBE429aD409.toBytes32();

        // Uniswap V3
        values[mainnet]["WSTETH_WETH_100"] = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa.toBytes32();
        values[mainnet]["WSTETH_WETH_500"] = 0xD340B57AAcDD10F96FC1CF10e15921936F41E29c.toBytes32();
        values[mainnet]["DAI_USDC_100"] = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168.toBytes32();
        values[mainnet]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();

        // Redstone
        values[mainnet]["swEthAdapter"] = 0x68ba9602B2AeE30847412109D2eE89063bf08Ec2.toBytes32();
        values[mainnet]["swEthDataFeedId"] = 0x5357455448000000000000000000000000000000000000000000000000000000;
        values[mainnet]["swEthEthDataFeedId"] = 0x53574554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["ethXEthAdapter"] = 0xc799194cAa24E2874Efa89b4Bf5c92a530B047FF.toBytes32();
        values[mainnet]["ethXEthDataFeedId"] = 0x455448782f455448000000000000000000000000000000000000000000000000;

        values[mainnet]["ethXAdapter"] = 0xF3eB387Ac1317fBc7E2EFD82214eE1E148f0Fe00.toBytes32();
        values[mainnet]["ethXUsdDataFeedId"] = 0x4554487800000000000000000000000000000000000000000000000000000000;

        values[mainnet]["weEthEthAdapter"] = 0x8751F736E94F6CD167e8C5B97E245680FbD9CC36.toBytes32();
        values[mainnet]["weEthDataFeedId"] = 0x77654554482f4554480000000000000000000000000000000000000000000000;
        values[mainnet]["weethAdapter"] = 0xdDb6F90fFb4d3257dd666b69178e5B3c5Bf41136.toBytes32();
        values[mainnet]["weethUsdDataFeedId"] = 0x7765455448000000000000000000000000000000000000000000000000000000;

        values[mainnet]["osEthEthAdapter"] = 0x66ac817f997Efd114EDFcccdce99F3268557B32C.toBytes32();
        values[mainnet]["osEthEthDataFeedId"] = 0x6f734554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["rsEthEthAdapter"] = 0xA736eAe8805dDeFFba40cAB8c99bCB309dEaBd9B.toBytes32();
        values[mainnet]["rsEthEthDataFeedId"] = 0x72734554482f4554480000000000000000000000000000000000000000000000;

        values[mainnet]["ezEthEthAdapter"] = 0xF4a3e183F59D2599ee3DF213ff78b1B3b1923696.toBytes32();
        values[mainnet]["ezEthEthDataFeedId"] = 0x657a4554482f4554480000000000000000000000000000000000000000000000;

        // Maker
        values[mainnet]["dsrManager"] = 0x373238337Bfe1146fb49989fc222523f83081dDb.toBytes32();

        // Maker
        values[mainnet]["savingsDaiAddress"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();
        values[mainnet]["sDAI"] = 0x83F20F44975D03b1b09e64809B757c47f942BEeA.toBytes32();

        // Frax
        values[mainnet]["sFRAX"] = 0xA663B02CF0a4b149d2aD41910CB81e23e1c41c32.toBytes32();

        // Lido
        values[mainnet]["unstETH"] = 0x889edC2eDab5f40e902b864aD4d7AdE8E412F9B1.toBytes32();

        // Stader
        values[mainnet]["stakePoolManagerAddress"] = 0xcf5EA1b38380f6aF39068375516Daf40Ed70D299.toBytes32();
        values[mainnet]["userWithdrawManagerAddress"] = 0x9F0491B32DBce587c50c4C43AB303b06478193A7.toBytes32();
        values[mainnet]["staderConfig"] = 0x4ABEF2263d5A5ED582FC9A9789a41D85b68d69DB.toBytes32();

        // Etherfi
        values[mainnet]["EETH_LIQUIDITY_POOL"] = 0x308861A430be4cce5502d0A12724771Fc6DaF216.toBytes32();
        values[mainnet]["withdrawalRequestNft"] = 0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c.toBytes32();

        // Renzo
        values[mainnet]["restakeManager"] = 0x74a09653A083691711cF8215a6ab074BB4e99ef5.toBytes32();

        // Kelp DAO
        values[mainnet]["lrtDepositPool"] = 0x036676389e48133B63a802f8635AD39E752D375D.toBytes32();
        // Compound V3
        values[mainnet]["cUSDCV3"] = 0xc3d688B66703497DAA19211EEdff47f25384cdc3.toBytes32();
        values[mainnet]["cUSDTV3"] = 0x3Afdc9BCA9213A35503b077a6072F3D0d5AB0840.toBytes32();
        values[mainnet]["cWETHV3"] = 0xA17581A9E3356d9A858b789D68B4d866e593aE94.toBytes32();
        values[mainnet]["cometRewards"] = 0x1B0e765F6224C21223AeA2af16c1C46E38885a40.toBytes32();
        // Morpho Blue
        values[mainnet]["morphoBlue"] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb.toBytes32();
        values[mainnet]["ezEthOracle"] = 0x61025e2B0122ac8bE4e37365A4003d87ad888Cc3.toBytes32();
        values[mainnet]["ezEthIrm"] = 0x870aC11D48B15DB9a138Cf899d20F13F79Ba00BC.toBytes32();
        values[mainnet]["weETH_wETH_86_market"] = 0x698fe98247a40c5771537b5786b2f3f9d78eb487b4ce4d75533cd0e94d88a115;
        values[mainnet]["LBTC_WBTC_945"] = 0xf6a056627a51e511ec7f48332421432ea6971fc148d8f3c451e14ea108026549;

        // MetaMorpho
        values[mainnet]["usualBoostedUSDC"] = 0xd63070114470f685b75B74D60EEc7c1113d33a3D.toBytes32();
        values[mainnet]["gauntletWBTCcore"] = 0x443df5eEE3196e9b2Dd77CaBd3eA76C3dee8f9b2.toBytes32();
        values[mainnet]["Re7WBTC"] = 0xE0C98605f279e4D7946d25B75869c69802823763.toBytes32();
        values[mainnet]["MCwBTC"] = 0x1c530D6de70c05A81bF1670157b9d928e9699089.toBytes32();
        values[mainnet]["Re7cbBTC"] = 0xA02F5E93f783baF150Aa1F8b341Ae90fe0a772f7.toBytes32();
        values[mainnet]["gauntletCbBTCcore"] = 0xF587f2e8AfF7D76618d3B6B4626621860FbD54e3.toBytes32();
        values[mainnet]["MCcbBTC"] = 0x98cF0B67Da0F16E1F8f1a1D23ad8Dc64c0c70E0b.toBytes32();

        values[mainnet]["uniswapV3PositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();

        // 1Inch
        values[mainnet]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[mainnet]["oneInchExecutor"] = 0x3451B6b219478037a1AC572706627FC2BDa1e812.toBytes32();
        values[mainnet]["wETHweETH5bps"] = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3.toBytes32();

        // Gearbox
        values[mainnet]["dWETHV3"] = 0xda0002859B2d05F66a753d8241fCDE8623f26F4f.toBytes32();
        values[mainnet]["sdWETHV3"] = 0x0418fEB7d0B25C411EB77cD654305d29FcbFf685.toBytes32();
        values[mainnet]["dUSDCV3"] = 0xda00000035fef4082F78dEF6A8903bee419FbF8E.toBytes32();
        values[mainnet]["sdUSDCV3"] = 0x9ef444a6d7F4A5adcd68FD5329aA5240C90E14d2.toBytes32();
        values[mainnet]["dDAIV3"] = 0xe7146F53dBcae9D6Fa3555FE502648deb0B2F823.toBytes32();
        values[mainnet]["sdDAIV3"] = 0xC853E4DA38d9Bd1d01675355b8c8f3BBC1451973.toBytes32();
        values[mainnet]["dUSDTV3"] = 0x05A811275fE9b4DE503B3311F51edF6A856D936e.toBytes32();
        values[mainnet]["sdUSDTV3"] = 0x16adAb68bDEcE3089D4f1626Bb5AEDD0d02471aD.toBytes32();
        values[mainnet]["dWBTCV3"] = 0xda00010eDA646913F273E10E7A5d1F659242757d.toBytes32();
        values[mainnet]["sdWBTCV3"] = 0xA8cE662E45E825DAF178DA2c8d5Fae97696A788A.toBytes32();

        // Pendle
        values[mainnet]["pendleMarketFactory"] = 0x1A6fCc85557BC4fB7B534ed835a03EF056552D52.toBytes32();
        values[mainnet]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[mainnet]["pendleOracle"] = 0x66a1096C6366b2529274dF4f5D8247827fe4CEA8.toBytes32();
        values[mainnet]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();

        values[mainnet]["pendleWeETHMarket"] = 0xF32e58F92e60f4b0A37A69b95d642A471365EAe8.toBytes32();
        values[mainnet]["pendleWeethSy"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPt"] = 0xc69Ad9baB1dEE23F4605a82b3354F8E40d1E5966.toBytes32();
        values[mainnet]["pendleEethYt"] = 0xfb35Fd0095dD1096b1Ca49AD44d8C5812A201677.toBytes32();

        values[mainnet]["pendleZircuitWeETHMarket"] = 0xe26D7f9409581f606242300fbFE63f56789F2169.toBytes32();
        values[mainnet]["pendleZircuitWeethSy"] = 0xD7DF7E085214743530afF339aFC420c7c720BFa7.toBytes32();
        values[mainnet]["pendleZircuitEethPt"] = 0x4AE5411F3863CdB640309e84CEDf4B08B8b33FfF.toBytes32();
        values[mainnet]["pendleZircuitEethYt"] = 0x7C2D26182adeEf96976035986cF56474feC03bDa.toBytes32();

        values[mainnet]["pendleUSDeMarket"] = 0x19588F29f9402Bb508007FeADd415c875Ee3f19F.toBytes32();
        values[mainnet]["pendleUSDeSy"] = 0x42862F48eAdE25661558AFE0A630b132038553D0.toBytes32();
        values[mainnet]["pendleUSDePt"] = 0xa0021EF8970104c2d008F38D92f115ad56a9B8e1.toBytes32();
        values[mainnet]["pendleUSDeYt"] = 0x1e3d13932C31d7355fCb3FEc680b0cD159dC1A07.toBytes32();

        values[mainnet]["pendleZircuitUSDeMarket"] = 0x90c98ab215498B72Abfec04c651e2e496bA364C0.toBytes32();
        values[mainnet]["pendleZircuitUSDeSy"] = 0x293C6937D8D82e05B01335F7B33FBA0c8e256E30.toBytes32();
        values[mainnet]["pendleZircuitUSDePt"] = 0x3d4F535539A33FEAd4D76D7b3B7A9cB5B21C73f1.toBytes32();
        values[mainnet]["pendleZircuitUSDeYt"] = 0x40357b9f22B4DfF0Bf56A90661b8eC106C259d29.toBytes32();

        values[mainnet]["pendleSUSDeMarketSeptember"] = 0xd1D7D99764f8a52Aff007b7831cc02748b2013b5.toBytes32();
        values[mainnet]["pendleSUSDeMarketJuly"] = 0x107a2e3cD2BB9a32B9eE2E4d51143149F8367eBa.toBytes32();
        values[mainnet]["pendleKarakSUSDeMarket"] = 0xB1f587B354a4a363f5332e88effbbC2E4961250A.toBytes32();
        values[mainnet]["pendleKarakUSDeMarket"] = 0x1BCBDB8c8652345A5ACF04e6E74f70086c68FEfC.toBytes32();

        values[mainnet]["pendleWeETHMarketSeptember"] = 0xC8eDd52D0502Aa8b4D5C77361D4B3D300e8fC81c.toBytes32();
        values[mainnet]["pendleWeethSySeptember"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPtSeptember"] = 0x1c085195437738d73d75DC64bC5A3E098b7f93b1.toBytes32();
        values[mainnet]["pendleEethYtSeptember"] = 0xA54Df645A042D24121a737dAA89a57EbF8E0b71c.toBytes32();

        values[mainnet]["pendleWeETHMarketDecember"] = 0x7d372819240D14fB477f17b964f95F33BeB4c704.toBytes32();
        values[mainnet]["pendleWeethSyDecember"] = 0xAC0047886a985071476a1186bE89222659970d65.toBytes32();
        values[mainnet]["pendleEethPtDecember"] = 0x6ee2b5E19ECBa773a352E5B21415Dc419A700d1d.toBytes32();
        values[mainnet]["pendleEethYtDecember"] = 0x129e6B5DBC0Ecc12F9e486C5BC9cDF1a6A80bc6A.toBytes32();

        values[mainnet]["pendleUSDeZircuitMarketAugust"] = 0xF148a0B15712f5BfeefAdb4E6eF9739239F88b07.toBytes32();
        values[mainnet]["pendleKarakWeETHMarketSeptember"] = 0x18bAFcaBf2d5898956AE6AC31543d9657a604165.toBytes32();
        values[mainnet]["pendleKarakWeETHMarketDecember"] = 0xFF694CC3f74E080637008B3792a9D7760cB456Ca.toBytes32();

        values[mainnet]["pendleSwethMarket"] = 0x0e1C5509B503358eA1Dac119C1D413e28Cc4b303.toBytes32();

        values[mainnet]["pendleZircuitWeETHMarketAugust"] = 0x6c269DFc142259c52773430b3c78503CC994a93E.toBytes32();
        values[mainnet]["pendleWeETHMarketJuly"] = 0xe1F19CBDa26b6418B0C8E1EE978a533184496066.toBytes32();
        values[mainnet]["pendleWeETHkSeptember"] = 0x905A5a4792A0C27a2AdB2777f98C577D320079EF.toBytes32();
        values[mainnet]["pendleWeETHkDecember"] = 0x792b9eDe7a18C26b814f87Eb5E0c8D26AD189780.toBytes32();

        values[mainnet]["pendle_sUSDe_08_23_24"] = 0xbBf399db59A845066aAFce9AE55e68c505FA97B7.toBytes32();
        values[mainnet]["pendle_sUSDe_12_25_24"] = 0xa0ab94DeBB3cC9A7eA77f3205ba4AB23276feD08.toBytes32();
        values[mainnet]["pendle_USDe_08_23_24"] = 0x3d1E7312dE9b8fC246ddEd971EE7547B0a80592A.toBytes32();
        values[mainnet]["pendle_USDe_12_25_24"] = 0x8a49f2AC2730ba15AB7EA832EdaC7f6BA22289f8.toBytes32();
        values[mainnet]["pendle_sUSDe_03_26_25"] = 0xcDd26Eb5EB2Ce0f203a84553853667aE69Ca29Ce.toBytes32();
        values[mainnet]["pendle_sUSDe_karak_01_29_25"] = 0xDbE4D359D4E48087586Ec04b93809bA647343548.toBytes32();
        values[mainnet]["pendle_USDe_karak_01_29_25"] = 0x6C06bBFa3B63eD344ceb3312Df795eDC8d29BDD5.toBytes32();
        values[mainnet]["pendle_USDe_03_26_25"] = 0xB451A36c8B6b2EAc77AD0737BA732818143A0E25.toBytes32();

        values[mainnet]["pendle_weETHs_market_08_28_24"] = 0xcAa8ABB72A75C623BECe1f4D5c218F425d47A0D0.toBytes32();
        values[mainnet]["pendle_weETHs_sy_08_28_24"] = 0x9e8f10574ACc2c62C6e5d19500CEd39163Da37A9.toBytes32();
        values[mainnet]["pendle_weETHs_pt_08_28_24"] = 0xda6530EfaFD63A42d7b9a0a5a60A03839CDb813A.toBytes32();
        values[mainnet]["pendle_weETHs_yt_08_28_24"] = 0x28cE264D0938C1051687FEbDCeFacc2242BA9E0E.toBytes32();

        values[mainnet]["pendle_weETHs_market_12_25_24"] = 0x40789E8536C668c6A249aF61c81b9dfaC3EB8F32.toBytes32();
        values[mainnet]["pendleUSD0PlusMarketOctober"] = 0x00b321D89A8C36B3929f20B7955080baeD706D1B.toBytes32();
        values[mainnet]["pendle_USD0Plus_market_03_26_2025"] = 0xaFDC922d0059147486cC1F0f32e3A2354b0d35CC.toBytes32();

        values[mainnet]["pendle_eBTC_market_12_26_24"] = 0x36d3ca43ae7939645C306E26603ce16e39A89192.toBytes32();
        values[mainnet]["pendle_LBTC_corn_market_12_26_24"] = 0xCaE62858DB831272A03768f5844cbe1B40bB381f.toBytes32();
        values[mainnet]["pendle_LBTC_market_03_26_25"] = 0x70B70Ac0445C3eF04E314DFdA6caafd825428221.toBytes32();

        values[mainnet]["pendle_pumpBTC_market_03_26_25"] = 0x8098B48a1c4e4080b30A43a7eBc0c87b52F17222.toBytes32();
        values[mainnet]["pendle_corn_pumpBTC_market_12_25_24"] = 0xf8208fB52BA80075aF09840A683143C22DC5B4dd.toBytes32();

        // Aave V3
        values[mainnet]["v3Pool"] = 0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2.toBytes32();

        // Aave V3 Lido
        values[mainnet]["v3LidoPool"] = 0x4e033931ad43597d96D6bcc25c280717730B58B1.toBytes32();

        // SparkLend
        values[mainnet]["sparkLendPool"] = 0xC13e21B648A5Ee794902342038FF3aDAB66BE987.toBytes32();

        // Uniswap V3 Pools
        values[mainnet]["wETH_weETH_05"] = 0x7A415B19932c0105c82FDB6b720bb01B0CC2CAe3.toBytes32();
        values[mainnet]["wstETH_wETH_01"] = 0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa.toBytes32();
        values[mainnet]["rETH_wETH_01"] = 0x553e9C493678d8606d6a5ba284643dB2110Df823.toBytes32();
        values[mainnet]["rETH_wETH_05"] = 0xa4e0faA58465A2D369aa21B3e42d43374c6F9613.toBytes32();
        values[mainnet]["wstETH_rETH_05"] = 0x18319135E02Aa6E02D412C98cCb16af3a0a9CB57.toBytes32();
        values[mainnet]["wETH_rswETH_05"] = 0xC410573Af188f56062Ee744cC3D6F2843f5bC13b.toBytes32();
        values[mainnet]["wETH_rswETH_30"] = 0xE62627326d7794E20bB7261B24985294de1579FE.toBytes32();
        values[mainnet]["ezETH_wETH_01"] = 0xBE80225f09645f172B079394312220637C440A63.toBytes32();
        values[mainnet]["PENDLE_wETH_30"] = 0x57aF956d3E2cCa3B86f3D8C6772C03ddca3eAacB.toBytes32();
        values[mainnet]["USDe_USDT_01"] = 0x435664008F38B0650fBC1C9fc971D0A3Bc2f1e47.toBytes32();
        values[mainnet]["USDe_USDC_01"] = 0xE6D7EbB9f1a9519dc06D557e03C522d53520e76A.toBytes32();
        values[mainnet]["USDe_DAI_01"] = 0x5B3a0f1acBE8594a079FaFeB1c84DEA9372A5Aad.toBytes32();
        values[mainnet]["sUSDe_USDT_05"] = 0x867B321132B18B5BF3775c0D9040D1872979422E.toBytes32();
        values[mainnet]["GEAR_wETH_100"] = 0xaEf52f72583E6c4478B220Da82321a6a023eEE50.toBytes32();
        values[mainnet]["GEAR_USDT_30"] = 0x349eE001D80f896F24571616932f54cBD66B18C9.toBytes32();
        values[mainnet]["DAI_USDC_01"] = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168.toBytes32();
        values[mainnet]["DAI_USDC_05"] = 0x6c6Bc977E13Df9b0de53b251522280BB72383700.toBytes32();
        values[mainnet]["USDC_USDT_01"] = 0x3416cF6C708Da44DB2624D63ea0AAef7113527C6.toBytes32();
        values[mainnet]["USDC_USDT_05"] = 0x7858E59e0C01EA06Df3aF3D20aC7B0003275D4Bf.toBytes32();
        values[mainnet]["USDC_wETH_05"] = 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640.toBytes32();
        values[mainnet]["FRAX_USDC_05"] = 0xc63B0708E2F7e69CB8A1df0e1389A98C35A76D52.toBytes32();
        values[mainnet]["FRAX_USDC_01"] = 0x9A834b70C07C81a9fcD6F22E842BF002fBfFbe4D.toBytes32();
        values[mainnet]["DAI_FRAX_05"] = 0x97e7d56A0408570bA1a7852De36350f7713906ec.toBytes32();
        values[mainnet]["FRAX_USDT_05"] = 0xc2A856c3afF2110c1171B8f942256d40E980C726.toBytes32();
        values[mainnet]["PYUSD_USDC_01"] = 0x13394005C1012e708fCe1EB974F1130fDc73a5Ce.toBytes32();

        // EigenLayer
        values[mainnet]["strategyManager"] = 0x858646372CC42E1A627fcE94aa7A7033e7CF075A.toBytes32();
        values[mainnet]["delegationManager"] = 0x39053D51B77DC0d36036Fc1fCc8Cb819df8Ef37A.toBytes32();
        values[mainnet]["mETHStrategy"] = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2.toBytes32();
        values[mainnet]["USDeStrategy"] = 0x298aFB19A105D59E74658C4C334Ff360BadE6dd2.toBytes32();
        values[mainnet]["testOperator"] = 0xDbEd88D83176316fc46797B43aDeE927Dc2ff2F5.toBytes32();
        values[mainnet]["eigenStrategy"] = 0xaCB55C530Acdb2849e6d4f36992Cd8c9D50ED8F7.toBytes32();
        values[mainnet]["eEigenOperator"] = 0xDcAE4FAf7C7d0f4A78abe147244c6e9d60cFD202.toBytes32();

        // Swell
        values[mainnet]["swellSimpleStaking"] = 0x38D43a6Cb8DA0E855A42fB6b0733A0498531d774.toBytes32();
        values[mainnet]["swEXIT"] = 0x48C11b86807627AF70a34662D4865cF854251663.toBytes32();
        values[mainnet]["accessControlManager"] = 0x625087d72c762254a72CB22cC2ECa40da6b95EAC.toBytes32();
        values[mainnet]["depositManager"] = 0xb3D9cf8E163bbc840195a97E81F8A34E295B8f39.toBytes32();

        // Frax
        values[mainnet]["frxETHMinter"] = 0xbAFA44EFE7901E04E39Dad13167D089C559c1138.toBytes32();
        values[mainnet]["frxETHRedemptionTicket"] = 0x82bA8da44Cd5261762e629dd5c605b17715727bd.toBytes32();

        // Zircuit
        values[mainnet]["zircuitSimpleStaking"] = 0xF047ab4c75cebf0eB9ed34Ae2c186f3611aEAfa6.toBytes32();

        // Mantle
        values[mainnet]["mantleLspStaking"] = 0xe3cBd06D7dadB3F4e6557bAb7EdD924CD1489E8f.toBytes32();

        // Fluid
        values[mainnet]["fUSDT"] = 0x5C20B550819128074FD538Edf79791733ccEdd18.toBytes32();
        values[mainnet]["fUSDTStakingRewards"] = 0x490681095ed277B45377d28cA15Ac41d64583048.toBytes32();
        values[mainnet]["fUSDC"] = 0x9Fb7b4477576Fe5B32be4C1843aFB1e55F251B33.toBytes32();
        values[mainnet]["fWETH"] = 0x90551c1795392094FE6D29B758EcCD233cFAa260.toBytes32();
        values[mainnet]["fWSTETH"] = 0x2411802D8BEA09be0aF8fD8D08314a63e706b29C.toBytes32();

        // Symbiotic
        values[mainnet]["wstETHDefaultCollateral"] = 0xC329400492c6ff2438472D4651Ad17389fCb843a.toBytes32();
        values[mainnet]["cbETHDefaultCollateral"] = 0xB26ff591F44b04E78de18f43B46f8b70C6676984.toBytes32();
        values[mainnet]["wBETHDefaultCollateral"] = 0x422F5acCC812C396600010f224b320a743695f85.toBytes32();
        values[mainnet]["rETHDefaultCollateral"] = 0x03Bf48b8A1B37FBeAd1EcAbcF15B98B924ffA5AC.toBytes32();
        values[mainnet]["mETHDefaultCollateral"] = 0x475D3Eb031d250070B63Fa145F0fCFC5D97c304a.toBytes32();
        values[mainnet]["swETHDefaultCollateral"] = 0x38B86004842D3FA4596f0b7A0b53DE90745Ab654.toBytes32();
        values[mainnet]["sfrxETHDefaultCollateral"] = 0x5198CB44D7B2E993ebDDa9cAd3b9a0eAa32769D2.toBytes32();
        values[mainnet]["ETHxDefaultCollateral"] = 0xBdea8e677F9f7C294A4556005c640Ee505bE6925.toBytes32();
        values[mainnet]["uniETHDefaultCollateral"] = 0x1C57ea879dd3e8C9fefa8224fdD1fa20dd54211E.toBytes32();
        values[mainnet]["sUSDeDefaultCollateral"] = 0x19d0D8e6294B7a04a2733FE433444704B791939A.toBytes32();
        values[mainnet]["wBTCDefaultCollateral"] = 0x971e5b5D4baa5607863f3748FeBf287C7bf82618.toBytes32();
        values[mainnet]["tBTCDefaultCollateral"] = 0x0C969ceC0729487d264716e55F232B404299032c.toBytes32();
        values[mainnet]["ethfiDefaultCollateral"] = 0x21DbBA985eEA6ba7F27534a72CCB292eBA1D2c7c.toBytes32();
        values[mainnet]["LBTCDefaultCollateral"] = 0x9C0823D3A1172F9DdF672d438dec79c39a64f448.toBytes32();

        // Karak
        values[mainnet]["vaultSupervisor"] = 0x54e44DbB92dBA848ACe27F44c0CB4268981eF1CC.toBytes32();
        values[mainnet]["delegationSupervisor"] = 0xAfa904152E04aBFf56701223118Be2832A4449E0.toBytes32();

        values[mainnet]["kmETH"] = 0x7C22725d1E0871f0043397c9761AD99A86ffD498.toBytes32();
        values[mainnet]["kweETH"] = 0x2DABcea55a12d73191AeCe59F508b191Fb68AdaC.toBytes32();
        values[mainnet]["kwstETH"] = 0xa3726beDFD1a8AA696b9B4581277240028c4314b.toBytes32();
        values[mainnet]["krETH"] = 0x8E475A4F7820A4b6c0FF229f74fB4762f0813C47.toBytes32();
        values[mainnet]["kcbETH"] = 0xbD32b8aA6ff34BEDc447e503195Fb2524c72658f.toBytes32();
        values[mainnet]["kwBETH"] = 0x04BB50329A1B7D943E7fD2368288b674c8180d5E.toBytes32();
        values[mainnet]["kswETH"] = 0xc585DF3a8C9ca0c614D023A812624bE36161502B.toBytes32();
        values[mainnet]["kETHx"] = 0x989Ab830C6e2BdF3f28214fF54C9B7415C349a3F.toBytes32();
        values[mainnet]["ksfrxETH"] = 0x1751e1e4d2c9Fa99479C0c5574136F0dbD8f3EB8.toBytes32();
        values[mainnet]["krswETH"] = 0x1B4d88f5f38988BEA334C79f48aa69BEEeFE2e1e.toBytes32();
        values[mainnet]["krsETH"] = 0x9a23e79a8E6D77F940F2C30eb3d9282Af2E4036c.toBytes32();
        values[mainnet]["kETHFI"] = 0xB26bD8D1FD5415eED4C99f9fB6A278A42E7d1BA8.toBytes32();
        values[mainnet]["ksUSDe"] = 0xDe5Bff0755F192C333B126A449FF944Ee2B69681.toBytes32();
        values[mainnet]["kUSDe"] = 0xBE3cA34D0E877A1Fc889BD5231D65477779AFf4e.toBytes32();
        values[mainnet]["kWBTC"] = 0x126d4dBf752AaF61f3eAaDa24Ab0dB84FEcf6891.toBytes32();
        values[mainnet]["kFBTC"] = 0x40328669Bc9e3780dFa0141dBC87450a4af6EA11.toBytes32();
        values[mainnet]["kLBTC"] = 0x468c34703F6c648CCf39DBaB11305D17C70ba011.toBytes32();

        // CCIP token transfers.
        values[mainnet]["ccipRouter"] = 0x80226fc0Ee2b096224EeAc085Bb9a8cba1146f7D.toBytes32();

        // PancakeSwap V3
        values[mainnet]["pancakeSwapV3NonFungiblePositionManager"] =
            0x46A15B0b27311cedF172AB29E4f4766fbE7F4364.toBytes32();
        values[mainnet]["pancakeSwapV3MasterChefV3"] = 0x556B9306565093C855AEA9AE92A594704c2Cd59e.toBytes32();
        values[mainnet]["pancakeSwapV3Router"] = 0x13f4EA83D0bd40E75C8222255bc855a974568Dd4.toBytes32();
        // Arbitrum Bridge
        values[mainnet]["arbitrumDelayedInbox"] = 0x4Dbd4fc535Ac27206064B68FfCf827b0A60BAB3f.toBytes32();
        values[mainnet]["arbitrumOutbox"] = 0x0B9857ae2D4A3DBe74ffE1d7DF045bb7F96E4840.toBytes32();
        values[mainnet]["arbitrumL1GatewayRouter"] = 0x72Ce9c846789fdB6fC1f34aC4AD25Dd9ef7031ef.toBytes32();
        values[mainnet]["arbitrumL1ERC20Gateway"] = 0xa3A7B6F88361F48403514059F1F16C8E78d60EeC.toBytes32();
        values[mainnet]["arbitrumWethGateway"] = 0xd92023E9d9911199a6711321D1277285e6d4e2db.toBytes32();

        // Base Standard Bridge.
        values[mainnet]["baseStandardBridge"] = 0x3154Cf16ccdb4C6d922629664174b904d80F2C35.toBytes32();
        values[mainnet]["basePortal"] = 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e.toBytes32();
        values[mainnet]["baseResolvedDelegate"] = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa.toBytes32();

        // Optimism Standard Bridge.
        values[mainnet]["optimismStandardBridge"] = 0x99C9fc46f92E8a1c0deC1b1747d010903E884bE1.toBytes32();
        values[mainnet]["optimismPortal"] = 0xbEb5Fc579115071764c7423A4f12eDde41f106Ed.toBytes32();
        values[mainnet]["optimismResolvedDelegate"] = 0x25ace71c97B33Cc4729CF772ae268934F7ab5fA1.toBytes32();

        // Mantle Standard Bridge.
        values[mainnet]["mantleStandardBridge"] = 0x95fC37A27a2f68e3A647CDc081F0A89bb47c3012.toBytes32();
        values[mainnet]["mantlePortal"] = 0xc54cb22944F2bE476E02dECfCD7e3E7d3e15A8Fb.toBytes32();
        values[mainnet]["mantleResolvedDelegate"] = 0x676A795fe6E43C17c668de16730c3F690FEB7120.toBytes32(); // TODO update this.

        // Zircuit Standard Bridge.
        values[mainnet]["zircuitStandardBridge"] = 0x386B76D9cA5F5Fb150B6BFB35CF5379B22B26dd8.toBytes32();
        values[mainnet]["zircuitPortal"] = 0x17bfAfA932d2e23Bd9B909Fd5B4D2e2a27043fb1.toBytes32();
        values[mainnet]["zircuitResolvedDelegate"] = 0x2a721cBE81a128be0F01040e3353c3805A5EA091.toBytes32();

        // Fraxtal Standard Bridge.
        values[mainnet]["fraxtalStandardBridge"] = 0x34C0bD5877A5Ee7099D0f5688D65F4bB9158BDE2.toBytes32();
        values[mainnet]["fraxtalPortal"] = 0x36cb65c1967A0Fb0EEE11569C51C2f2aA1Ca6f6D.toBytes32();
        values[mainnet]["fraxtalResolvedDelegate"] = 0x2a721cBE81a128be0F01040e3353c3805A5EA091.toBytes32(); // TODO update this

        // Lido Base Standard Bridge.
        values[mainnet]["lidoBaseStandardBridge"] = 0x9de443AdC5A411E83F1878Ef24C3F52C61571e72.toBytes32();
        values[mainnet]["lidoBasePortal"] = 0x49048044D57e1C92A77f79988d21Fa8fAF74E97e.toBytes32();
        values[mainnet]["lidoBaseResolvedDelegate"] = 0x866E82a600A1414e583f7F13623F1aC5d58b0Afa.toBytes32();

        // Layer Zero.
        values[mainnet]["EtherFiOFTAdapter"] = 0xFE7fe01F8B9A76803aF3750144C2715D9bcf7D0D.toBytes32();

        // Merkl
        values[mainnet]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Pump Staking
        values[mainnet]["pumpStaking"] = 0x1fCca65fb6Ae3b2758b9b2B394CB227eAE404e1E.toBytes32();

        // Linea Bridging
        values[mainnet]["tokenBridge"] = 0x051F1D88f0aF5763fB888eC4378b4D8B29ea3319.toBytes32(); // approve, bridge token
        values[mainnet]["lineaMessageService"] = 0xd19d4B5d358258f05D7B411E21A1460D11B0876F.toBytes32(); // claim message, sendMessage

        // Scroll Bridging
        values[mainnet]["scrollGatewayRouter"] = 0xF8B1378579659D8F7EE5f3C929c2f3E332E41Fd6.toBytes32(); // approve, depositERC20
        values[mainnet]["scrollMessenger"] = 0x6774Bcbd5ceCeF1336b5300fb5186a12DDD8b367.toBytes32(); // sendMessage
        values[mainnet]["scrollCustomERC20Gateway"] = 0x67260A8B73C5B77B55c1805218A42A7A6F98F515.toBytes32(); // sendMessage

        // Syrup
        values[mainnet]["syrupRouter"] = 0x134cCaaA4F1e4552eC8aEcb9E4A2360dDcF8df76.toBytes32();

        // Satlayer
        values[mainnet]["satlayerPool"] = 0x42a856dbEBB97AbC1269EAB32f3bb40C15102819.toBytes32();

        // corn
        values[mainnet]["cornSilo"] = 0x8bc93498b861fd98277c3b51d240e7E56E48F23c.toBytes32();

        // Treehouse
        values[mainnet]["TreehouseRedemption"] = 0x0618DBdb3Be798346e6D9C08c3c84658f94aD09F.toBytes32();
        values[mainnet]["TreehouseRouter"] = 0xeFA3fa8e85D2b3CfdB250CdeA156c2c6C90628F5.toBytes32();
        values[mainnet]["tETH"] = 0xD11c452fc99cF405034ee446803b6F6c1F6d5ED8.toBytes32();
        values[mainnet]["tETH_wstETH_curve_pool"] = 0xA10d15538E09479186b4D3278BA5c979110dDdB1.toBytes32();
    }

    function _addBaseValues() private {
        // Liquid Ecosystem
        values[base]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[base]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[base]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[base]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();

        // DeFi Ecosystem
        values[base]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[base]["uniswapV3NonFungiblePositionManager"] = 0x03a520b32C04BF3bEEf7BEb72E919cf822Ed34f1.toBytes32();

        values[base]["USDC"] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913.toBytes32();
        values[base]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[base]["WEETH"] = 0x04C0599Ae5A44757c0af6F9eC3b93da8976c150A.toBytes32();
        values[base]["WSTETH"] = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452.toBytes32();
        values[base]["AERO"] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631.toBytes32();
        values[base]["CBETH"] = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22.toBytes32();
        values[base]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[base]["BAL"] = 0x4158734D47Fc9692176B5085E0F52ee0Da5d47F1.toBytes32();
        values[base]["CRV"] = 0x8Ee73c484A26e0A5df2Ee2a4960B789967dd0415.toBytes32();
        values[base]["LINK"] = 0x88Fb150BDc53A65fe94Dea0c9BA0a6dAf8C6e196.toBytes32();
        values[base]["UNI"] = 0xc3De830EA07524a0761646a6a4e4be0e114a3C83.toBytes32();
        values[base]["RETH"] = 0xB6fe221Fe9EeF5aBa221c348bA20A1Bf5e73624c.toBytes32();
        values[base]["BSDETH"] = 0xCb327b99fF831bF8223cCEd12B1338FF3aA322Ff.toBytes32();
        values[base]["SFRXETH"] = 0x1f55a02A049033E3419a8E2975cF3F572F4e6E9A.toBytes32();
        values[base]["cbBTC"] = 0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf.toBytes32();
        values[base]["tBTC"] = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b.toBytes32();
        values[base]["dlcBTC"] = 0x12418783e860997eb99e8aCf682DF952F721cF62.toBytes32();

        // Balancer vault
        values[base]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[base]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();

        // Standard Bridge.
        values[base]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[base]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Lido Standard Bridge.
        values[base]["l2ERC20TokenBridge"] = 0xac9D11cD4D7eF6e54F14643a393F68Ca014287AB.toBytes32();

        values[base]["weETH_ETH_ExchangeRate"] = 0x35e9D7001819Ea3B39Da906aE6b06A62cfe2c181.toBytes32();

        // Aave V3
        values[base]["v3Pool"] = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5.toBytes32();

        // Merkl
        values[base]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Aerodrome
        values[base]["aerodromeRouter"] = 0xcF77a3Ba9A5CA399B7c97c74d54e5b1Beb874E43.toBytes32();
        values[base]["aerodromeNonFungiblePositionManager"] = 0x827922686190790b37229fd06084350E74485b72.toBytes32();
        values[base]["aerodrome_Weth_Wsteth_v3_1_gauge"] = 0x2A1f7bf46bd975b5004b61c6040597E1B6117040.toBytes32();
        values[base]["aerodrome_Weth_Bsdeth_v3_1_gauge"] = 0x0b537aC41400433F09d97Cd370C1ea9CE78D8a74.toBytes32();
        values[base]["aerodrome_Cbeth_Weth_v3_1_gauge"] = 0xF5550F8F0331B8CAA165046667f4E6628E9E3Aac.toBytes32();
        values[base]["aerodrome_Weth_Wsteth_v2_30_gauge"] = 0xDf7c8F17Ab7D47702A4a4b6D951d2A4c90F99bf4.toBytes32();
        values[base]["aerodrome_Weth_Weeth_v2_30_gauge"] = 0xf8d47b641eD9DF1c924C0F7A6deEEA2803b9CfeF.toBytes32();
        values[base]["aerodrome_Weth_Reth_v2_05_gauge"] = 0xAa3D51d36BfE7C5C63299AF71bc19988BdBa0A06.toBytes32();
        values[base]["aerodrome_Sfrxeth_Wsteth_v2_30_gauge"] = 0xCe7Cb6260fCBf17485cd2439B89FdDf8B0Eb39cC.toBytes32();

        // MorphoBlue
        values[base]["morphoBlue"] = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb.toBytes32();
        values[base]["weETH_wETH_915"] = 0x78d11c03944e0dc298398f0545dc8195ad201a18b0388cb8058b1bcb89440971;
        values[base]["wstETH_wETH_945"] = 0x3a4048c64ba1b375330d376b1ce40e4047d03b47ab4d48af484edec9fec801ba;
        values[base]["cbETH_wETH_965"] = 0x6600aae6c56d242fa6ba68bd527aff1a146e77813074413186828fd3f1cdca91;
        values[base]["cbETH_wETH_945"] = 0x84662b4f95b85d6b082b68d32cf71bb565b3f22f216a65509cc2ede7dccdfe8c;

        values[base]["uniV3Router"] = 0x2626664c2603336E57B271c5C0b26F421741e481.toBytes32();

        values[base]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[base]["oneInchExecutor"] = 0xE37e799D5077682FA0a244D46E5649F71457BD09.toBytes32();

        // Compound V3
        values[base]["cWETHV3"] = 0x46e6b214b524310239732D51387075E0e70970bf.toBytes32();
        values[base]["cometRewards"] = 0x123964802e6ABabBE1Bc9547D72Ef1B69B00A6b1.toBytes32();

        // Instadapp Fluid
        values[base]["fWETH"] = 0x9272D6153133175175Bc276512B2336BE3931CE9.toBytes32();
        values[base]["fWSTETH"] = 0x896E39f0E9af61ECA9dD2938E14543506ef2c2b5.toBytes32();
    }

    function _addArbitrumValues() private {
        // Liquid Ecosystem
        values[arbitrum]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[arbitrum]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[arbitrum]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[arbitrum]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();

        // DeFi Ecosystem
        values[arbitrum]["ETH"] = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE.toBytes32();
        values[arbitrum]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[arbitrum]["uniV2Router"] = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D.toBytes32();
        values[arbitrum]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();
        values[arbitrum]["ccipRouter"] = 0x141fa059441E0ca23ce184B6A78bafD2A517DdE8.toBytes32();
        values[arbitrum]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();

        values[arbitrum]["USDC"] = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831.toBytes32();
        values[arbitrum]["USDCe"] = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8.toBytes32();
        values[arbitrum]["WETH"] = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1.toBytes32();
        values[arbitrum]["WBTC"] = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f.toBytes32();
        values[arbitrum]["USDT"] = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9.toBytes32();
        values[arbitrum]["DAI"] = 0xDA10009cBd5D07dd0CeCc66161FC93D7c9000da1.toBytes32();
        values[arbitrum]["WSTETH"] = 0x5979D7b546E38E414F7E9822514be443A4800529.toBytes32();
        values[arbitrum]["FRAX"] = 0x17FC002b466eEc40DaE837Fc4bE5c67993ddBd6F.toBytes32();
        values[arbitrum]["BAL"] = 0x040d1EdC9569d4Bab2D15287Dc5A4F10F56a56B8.toBytes32();
        values[arbitrum]["COMP"] = 0x354A6dA3fcde098F8389cad84b0182725c6C91dE.toBytes32();
        values[arbitrum]["LINK"] = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4.toBytes32();
        values[arbitrum]["rETH"] = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8.toBytes32();
        values[arbitrum]["RETH"] = 0xEC70Dcb4A1EFa46b8F2D97C310C9c4790ba5ffA8.toBytes32();
        values[arbitrum]["cbETH"] = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f.toBytes32();
        values[arbitrum]["LUSD"] = 0x93b346b6BC2548dA6A1E7d98E9a421B42541425b.toBytes32();
        values[arbitrum]["UNI"] = 0xFa7F8980b0f1E64A2062791cc3b0871572f1F7f0.toBytes32();
        values[arbitrum]["CRV"] = 0x11cDb42B0EB46D95f990BeDD4695A6e3fA034978.toBytes32();
        values[arbitrum]["FRXETH"] = 0x178412e79c25968a32e89b11f63B33F733770c2A.toBytes32();
        values[arbitrum]["SFRXETH"] = 0x95aB45875cFFdba1E5f451B950bC2E42c0053f39.toBytes32();
        values[arbitrum]["ARB"] = 0x912CE59144191C1204E64559FE8253a0e49E6548.toBytes32();
        values[arbitrum]["WEETH"] = 0x35751007a407ca6FEFfE80b3cB397736D2cf4dbe.toBytes32();
        values[arbitrum]["USDE"] = 0x5d3a1Ff2b6BAb83b63cd9AD0787074081a52ef34.toBytes32();
        values[arbitrum]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[arbitrum]["PENDLE"] = 0x0c880f6761F1af8d9Aa9C466984b80DAb9a8c9e8.toBytes32();
        values[arbitrum]["RSR"] = 0xCa5Ca9083702c56b481D1eec86F1776FDbd2e594.toBytes32();
        values[arbitrum]["CBETH"] = 0x1DEBd73E752bEaF79865Fd6446b0c970EaE7732f.toBytes32();
        values[arbitrum]["OSETH"] = 0xf7d4e7273E5015C96728A6b02f31C505eE184603.toBytes32();
        values[arbitrum]["RSETH"] = 0x4186BFC76E2E237523CBC30FD220FE055156b41F.toBytes32();
        values[arbitrum]["GRAIL"] = 0x3d9907F9a368ad0a51Be60f7Da3b97cf940982D8.toBytes32();

        // Aave V3
        values[arbitrum]["v3Pool"] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD.toBytes32();

        // 1Inch
        values[arbitrum]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[arbitrum]["oneInchExecutor"] = 0xE37e799D5077682FA0a244D46E5649F71457BD09.toBytes32();

        values[arbitrum]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        // TODO This Balancer on L2s use a different minting logic so minter is not used
        // but the merkle tree should be refactored for L2s
        values[arbitrum]["minter"] = address(1).toBytes32();

        // Arbitrum native bridging.
        values[arbitrum]["arbitrumL2GatewayRouter"] = 0x5288c571Fd7aD117beA99bF60FE0846C4E84F933.toBytes32();
        values[arbitrum]["arbitrumSys"] = 0x0000000000000000000000000000000000000064.toBytes32();
        values[arbitrum]["arbitrumRetryableTx"] = 0x000000000000000000000000000000000000006E.toBytes32();
        values[arbitrum]["arbitrumL2Sender"] = 0x09e9222E96E7B4AE2a407B98d48e330053351EEe.toBytes32();

        // Pendle
        values[arbitrum]["pendleMarketFactory"] = 0x2FCb47B58350cD377f94d3821e7373Df60bD9Ced.toBytes32();
        values[arbitrum]["pendleRouter"] = 0x888888888889758F76e7103c6CbF23ABbF58F946.toBytes32();
        values[arbitrum]["pendleLimitOrderRouter"] = 0x000000000000c9B3E2C3Ec88B1B4c0cD853f4321.toBytes32();
        values[arbitrum]["pendleWeETHMarketSeptember"] = 0xf9F9779d8fF604732EBA9AD345E6A27EF5c2a9d6.toBytes32();
        values[arbitrum]["pendle_weETH_market_12_25_24"] = 0x6b92feB89ED16AA971B096e247Fe234dB4Aaa262.toBytes32();

        // Gearbox
        values[arbitrum]["dWETHV3"] = 0x04419d3509f13054f60d253E0c79491d9E683399.toBytes32();
        values[arbitrum]["sdWETHV3"] = 0xf3b7994e4dA53E04155057Fd61dc501599d57877.toBytes32();
        values[arbitrum]["dUSDCV3"] = 0x890A69EF363C9c7BdD5E36eb95Ceb569F63ACbF6.toBytes32();
        values[arbitrum]["sdUSDCV3"] = 0xD0181a36B0566a8645B7eECFf2148adE7Ecf2BE9.toBytes32();
        values[arbitrum]["dUSDCeV3"] = 0xa76c604145D7394DEc36C49Af494C144Ff327861.toBytes32();
        values[arbitrum]["sdUSDCeV3"] = 0x608F9e2E8933Ce6b39A8CddBc34a1e3E8D21cE75.toBytes32();

        // Uniswap V3 pools
        values[arbitrum]["wstETH_wETH_01"] = 0x35218a1cbaC5Bbc3E57fd9Bd38219D37571b3537.toBytes32();
        values[arbitrum]["wstETH_wETH_05"] = 0xb93F8a075509e71325c1c2fc8FA6a75f2d536A13.toBytes32();
        values[arbitrum]["PENDLE_wETH_30"] = 0xdbaeB7f0DFe3a0AAFD798CCECB5b22E708f7852c.toBytes32();
        values[arbitrum]["wETH_weETH_30"] = 0xA169d1aB5c948555954D38700a6cDAA7A4E0c3A0.toBytes32();
        values[arbitrum]["wETH_weETH_05"] = 0xd90660A0b8Ad757e7C1d660CE633776a0862b087.toBytes32();
        values[arbitrum]["wETH_weETH_01"] = 0x14353445c8329Df76e6f15e9EAD18fA2D45A8BB6.toBytes32();

        // Chainlink feeds
        values[arbitrum]["weETH_ETH_ExchangeRate"] = 0x20bAe7e1De9c596f5F7615aeaa1342Ba99294e12.toBytes32();

        // Fluid fTokens
        values[arbitrum]["fUSDC"] = 0x1A996cb54bb95462040408C06122D45D6Cdb6096.toBytes32();
        values[arbitrum]["fUSDT"] = 0x4A03F37e7d3fC243e3f99341d36f4b829BEe5E03.toBytes32();
        values[arbitrum]["fWETH"] = 0x45Df0656F8aDf017590009d2f1898eeca4F0a205.toBytes32();
        values[arbitrum]["fWSTETH"] = 0x66C25Cd75EBdAA7E04816F643d8E46cecd3183c9.toBytes32();

        // Merkl
        values[arbitrum]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Vault Craft
        values[arbitrum]["compoundV3Weth"] = 0xC4bBbbAF12B1bE472E6E7B1A76d2756d5C763F95.toBytes32();
        values[arbitrum]["compoundV3WethGauge"] = 0x5E6A9859Dc1b393a82a5874F9cBA22E92d9fbBd2.toBytes32();

        // Camelot
        values[arbitrum]["camelotRouterV2"] = 0xc873fEcbd354f5A56E00E710B90EF4201db2448d.toBytes32();
        values[arbitrum]["camelotRouterV3"] = 0x1F721E2E82F6676FCE4eA07A5958cF098D339e18.toBytes32();
        values[arbitrum]["camelotNonFungiblePositionManager"] = 0x00c7f3082833e796A5b3e4Bd59f6642FF44DCD15.toBytes32();

        // Compound V3
        values[arbitrum]["cWETHV3"] = 0x6f7D514bbD4aFf3BcD1140B7344b32f063dEe486.toBytes32();
        values[arbitrum]["cometRewards"] = 0x88730d254A2f7e6AC8388c3198aFd694bA9f7fae.toBytes32();

        // Balancer
        values[arbitrum]["rsETH_wETH_BPT"] = 0x90e6CB5249f5e1572afBF8A96D8A1ca6aCFFd739.toBytes32();
        values[arbitrum]["rsETH_wETH_Id"] = 0x90e6cb5249f5e1572afbf8a96d8a1ca6acffd73900000000000000000000055c;
        values[arbitrum]["rsETH_wETH_Gauge"] = 0x59907f88C360D576Aa38dba84F26578367F96b6C.toBytes32();
        values[arbitrum]["aura_rsETH_wETH"] = 0x90cedFDb5284a274720f1dB339eEe9798f4fa29d.toBytes32();
        values[arbitrum]["wstETH_sfrxETH_BPT"] = 0xc2598280bFeA1Fe18dFcaBD21C7165c40c6859d3.toBytes32();
        values[arbitrum]["wstETH_sfrxETH_Id"] = 0xc2598280bfea1fe18dfcabd21c7165c40c6859d30000000000000000000004f3;
        values[arbitrum]["wstETH_sfrxETH_Gauge"] = 0x06eaf7bAabEac962301eE21296e711B3052F2c0d.toBytes32();
        values[arbitrum]["aura_wstETH_sfrxETH"] = 0x83D37cbA332ffd53A4336Ee06f3c301B8929E684.toBytes32();
        values[arbitrum]["wstETH_wETH_Gyro_BPT"] = 0x7967FA58B9501600D96bD843173b9334983EE6E6.toBytes32();
        values[arbitrum]["wstETH_wETH_Gyro_Id"] = 0x7967fa58b9501600d96bd843173b9334983ee6e600020000000000000000056e;
        values[arbitrum]["wstETH_wETH_Gyro_Gauge"] = 0x96d7C70c80518Ee189CB6ba672FbD22E4fDD9c19.toBytes32();
        values[arbitrum]["aura_wstETH_wETH_Gyro"] = 0x93e567b423ED470562911078b4d7A902d4E0BEea.toBytes32();
        values[arbitrum]["weETH_wstETH_Gyro_BPT"] = 0xCDCef9765D369954a4A936064535710f7235110A.toBytes32();
        values[arbitrum]["weETH_wstETH_Gyro_Id"] = 0xcdcef9765d369954a4a936064535710f7235110a000200000000000000000558;
        values[arbitrum]["weETH_wstETH_Gyro_Gauge"] = 0xdB66fFFf713B1FA758E348e69E2f2e24595111cF.toBytes32();
        values[arbitrum]["aura_weETH_wstETH_Gyro"] = 0x40bF10900a55c69c9dADdc3dC52465e01AcEF4A4.toBytes32();
        values[arbitrum]["osETH_wETH_BPT"] = 0x42f7Cfc38DD1583fFdA2E4f047F4F6FA06CEFc7c.toBytes32();
        values[arbitrum]["osETH_wETH_Id"] = 0x42f7cfc38dd1583ffda2e4f047f4f6fa06cefc7c000000000000000000000553;
        values[arbitrum]["osETH_wETH_Gauge"] = 0x5DA32F4724373c91Fdc657E0AD7B1836c70A4E52.toBytes32();

        // Karak
        values[arbitrum]["vaultSupervisor"] = 0x399f22ae52a18382a67542b3De9BeD52b7B9A4ad.toBytes32();
        values[arbitrum]["kETHFI"] = 0xc9A908402C7f0e343691cFB8c8Fc637449333ce0.toBytes32();
    }

    function _addOptimismValues() private {
        values[optimism]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[optimism]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[optimism]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[optimism]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[optimism]["uniV3Router"] = 0xE592427A0AEce92De3Edee1F18E0157C05861564.toBytes32();
        values[optimism]["aggregationRouterV5"] = 0x1111111254EEB25477B68fb85Ed929f73A960582.toBytes32();
        values[optimism]["oneInchExecutor"] = 0xE37e799D5077682FA0a244D46E5649F71457BD09.toBytes32();

        values[optimism]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[optimism]["WEETH"] = 0x346e03F8Cce9fE01dCB3d0Da3e9D00dC2c0E08f0.toBytes32();
        values[optimism]["WSTETH"] = 0x1F32b1c2345538c0c6f582fCB022739c4A194Ebb.toBytes32();
        values[optimism]["RETH"] = 0x9Bcef72be871e61ED4fBbc7630889beE758eb81D.toBytes32();
        values[optimism]["WEETH_OFT"] = 0x5A7fACB970D094B6C7FF1df0eA68D99E6e73CBFF.toBytes32();
        values[optimism]["OP"] = 0x4200000000000000000000000000000000000042.toBytes32();
        values[optimism]["CRV"] = 0x0994206dfE8De6Ec6920FF4D779B0d950605Fb53.toBytes32();
        values[optimism]["AURA"] = 0x1509706a6c66CA549ff0cB464de88231DDBe213B.toBytes32();
        values[optimism]["BAL"] = 0xFE8B128bA8C78aabC59d4c64cEE7fF28e9379921.toBytes32();
        values[optimism]["UNI"] = 0x6fd9d7AD17242c41f7131d257212c54A0e816691.toBytes32();
        values[optimism]["CBETH"] = 0xadDb6A0412DE1BA0F936DCaeb8Aaa24578dcF3B2.toBytes32();

        values[optimism]["vault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[optimism]["balancerVault"] = 0xBA12222222228d8Ba445958a75a0704d566BF2C8.toBytes32();
        values[optimism]["minter"] = 0x239e55F427D44C3cc793f49bFB507ebe76638a2b.toBytes32();

        values[optimism]["uniswapV3NonFungiblePositionManager"] = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88.toBytes32();
        values[optimism]["ccipRouter"] = 0x3206695CaE29952f4b0c22a169725a865bc8Ce0f.toBytes32();
        values[optimism]["weETH_ETH_ExchangeRate"] = 0x72EC6bF88effEd88290C66DCF1bE2321d80502f5.toBytes32();

        // Gearbox
        values[optimism]["dWETHV3"] = 0x42dB77B3103c71059F4b997d6441cFB299FD0d94.toBytes32();
        values[optimism]["sdWETHV3"] = 0x704c4C9F0d29257E5b0E526b20b48EfFC8f758b2.toBytes32();

        // Standard Bridge
        values[optimism]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[optimism]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();

        // Aave V3
        values[optimism]["v3Pool"] = 0x794a61358D6845594F94dc1DB02A252b5b4814aD.toBytes32();

        // Merkl
        values[optimism]["merklDistributor"] = 0x3Ef3D8bA38EBe18DB133cEc108f4D14CE00Dd9Ae.toBytes32();

        // Beethoven
        values[optimism]["wstETH_weETH_BPT"] = 0x2Bb4712247D5F451063b5E4f6948abDfb925d93D.toBytes32();
        values[optimism]["wstETH_weETH_Id"] = 0x2bb4712247d5f451063b5e4f6948abdfb925d93d000000000000000000000136;
        values[optimism]["wstETH_weETH_Gauge"] = 0xF3B314B1D2bd7d9afa8eC637716A9Bb81dBc79e5.toBytes32();
        values[optimism]["aura_wstETH_weETH"] = 0xe351a69EB84a22E113E92A4C683391C95448d7d4.toBytes32();

        // Velodrome
        values[optimism]["velodromeRouter"] = 0xa062aE8A9c5e11aaA026fc2670B0D65cCc8B2858.toBytes32();
        values[optimism]["velodromeNonFungiblePositionManager"] = 0x416b433906b1B72FA758e166e239c43d68dC6F29.toBytes32();
        values[optimism]["velodrome_Weth_Wsteth_v3_1_gauge"] = 0xb2218A2cFeF38Ca30AE8C88B41f2E2BdD9347E3e.toBytes32();

        // Compound V3
        values[optimism]["cWETHV3"] = 0xE36A30D249f7761327fd973001A32010b521b6Fd.toBytes32();
        values[optimism]["cometRewards"] = 0x443EA0340cb75a160F31A440722dec7b5bc3C2E9.toBytes32();
    }

    function _addHoleskyValues() private {
        // ERC20
        values[holesky]["WSTETH"] = 0x8d09a4502Cc8Cf1547aD300E066060D043f6982D.toBytes32();

        // Symbiotic
        values[holesky]["wstETHSymbioticVault"] = 0x89D62D1d89d8636367fc94998b3bE095a3d9c2f9.toBytes32();
    }

    function _addMantleValues() private {
        values[mantle]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[mantle]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[mantle]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[mantle]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[mantle]["balancerVault"] = address(1).toBytes32();

        // ERC20
        values[mantle]["WETH"] = 0xdEAddEaDdeadDEadDEADDEAddEADDEAddead1111.toBytes32();
        values[mantle]["USDC"] = 0x09Bc4E0D864854c6aFB6eB9A9cdF58aC190D0dF9.toBytes32();
        values[mantle]["METH"] = 0xcDA86A272531e8640cD7F1a92c01839911B90bb0.toBytes32();

        // Standard Bridge.
        values[mantle]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[mantle]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }

    function _addZircuitValues() private {
        values[zircuit]["deployerAddress"] = 0xFD65ADF7d2f9ea09287543520a703522E0a360C9.toBytes32();
        values[zircuit]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[zircuit]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[zircuit]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[zircuit]["balancerVault"] = address(1).toBytes32();

        values[zircuit]["WETH"] = 0x4200000000000000000000000000000000000006.toBytes32();
        values[zircuit]["METH"] = 0x91a0F6EBdCa0B4945FbF63ED4a95189d2b57163D.toBytes32();

        // Standard Bridge.
        values[zircuit]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        values[zircuit]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }

    function _addLineaValues() private {
        values[linea]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[linea]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[linea]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[linea]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[linea]["balancerVault"] = address(1).toBytes32();
        // ERC20
        values[linea]["DAI"] = 0x4AF15ec2A0BD43Db75dd04E62FAA3B8EF36b00d5.toBytes32();
        values[linea]["WETH"] = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f.toBytes32();
        values[linea]["WEETH"] = 0x1Bf74C010E6320bab11e2e5A532b5AC15e0b8aA6.toBytes32();

        // Linea Bridge.
        values[linea]["tokenBridge"] = 0x353012dc4a9A6cF55c941bADC267f82004A8ceB9.toBytes32(); //approve, also bridge token
        values[linea]["lineaMessageService"] = 0x508Ca82Df566dCD1B0DE8296e70a96332cD644ec.toBytes32(); // claim message, sendMessage
    }

    function _addScrollValues() private {
        values[scroll]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[scroll]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[scroll]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[scroll]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[scroll]["balancerVault"] = address(1).toBytes32();
        // ERC20
        values[scroll]["DAI"] = 0xcA77eB3fEFe3725Dc33bccB54eDEFc3D9f764f97.toBytes32();
        values[scroll]["WETH"] = 0x5300000000000000000000000000000000000004.toBytes32();
        values[scroll]["WEETH"] = 0x01f0a31698C4d065659b9bdC21B3610292a1c506.toBytes32();

        // Scroll Bridge.
        values[scroll]["scrollGatewayRouter"] = 0x4C0926FF5252A435FD19e10ED15e5a249Ba19d79.toBytes32(); // withdrawERC20
        values[scroll]["scrollMessenger"] = 0x781e90f1c8Fc4611c9b7497C3B47F99Ef6969CbC.toBytes32(); // sendMessage
        values[scroll]["scrollCustomERC20Gateway"] = 0xaC78dff3A87b5b534e366A93E785a0ce8fA6Cc62.toBytes32(); // sendMessage
    }

    function _addFraxtalValues() private {
        values[fraxtal]["deployerAddress"] = 0x5F2F11ad8656439d5C14d9B351f8b09cDaC2A02d.toBytes32();
        values[fraxtal]["dev0Address"] = 0x0463E60C7cE10e57911AB7bD1667eaa21de3e79b.toBytes32();
        values[fraxtal]["dev1Address"] = 0xf8553c8552f906C19286F21711721E206EE4909E.toBytes32();
        values[fraxtal]["liquidPayoutAddress"] = 0xA9962a5BfBea6918E958DeE0647E99fD7863b95A.toBytes32();
        values[fraxtal]["balancerVault"] = address(1).toBytes32();
        // ERC20
        values[fraxtal]["wfrxETH"] = 0xFC00000000000000000000000000000000000006.toBytes32();

        // Standard Bridge.
        // values[fraxtal]["standardBridge"] = 0x4200000000000000000000000000000000000010.toBytes32();
        // values[fraxtal]["crossDomainMessenger"] = 0x4200000000000000000000000000000000000007.toBytes32();
    }
}
