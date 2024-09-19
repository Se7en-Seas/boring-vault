// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    AaveV3EthereumEtherFi,
    AaveV3EthereumEtherFiEModes
} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/src/AaveV3EthereumEtherFi.sol";
import {AaveV3Ethereum} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/src/AaveV3Ethereum.sol";
import {MiscEthereum} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/src/MiscEthereum.sol";
import {AaveV3PayloadEthereumEtherFi} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/src/v3-config-engine/AaveV3PayloadEthereumEtherFi.sol";
import {EngineFlags} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/periphery/contracts/v3-config-engine/EngineFlags.sol";
import {IAaveV3ConfigEngine} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/periphery/contracts/v3-config-engine/IAaveV3ConfigEngine.sol";
import {IERC20} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/solidity-utils/src/contracts/oz-common/interfaces/IERC20.sol";
import {SafeERC20} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/solidity-utils/src/contracts/oz-common/SafeERC20.sol";
import {IPoolAddressesProviderRegistry} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPoolAddressesProviderRegistry.sol";

/**
 * @title EtherFi Ethereum Activation
 * @author Catapulta @catapulta_sh
 * - Snapshot: https://snapshot.org/#/aave.eth/proposal/0x4acd11c6100a6b85a553e21359f3720fa5cd4783a76c77857436ace134f88c05
 * - Discussion: https://governance.aave.com/t/arfc-deploy-an-etherfi-stablecoin-aave-v3-instance/18440
 */
contract AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902 is AaveV3PayloadEthereumEtherFi {
    using SafeERC20 for IERC20;

    address public constant weETH = 0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee;
    uint256 public constant weETH_SEED_AMOUNT = 1e17;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    uint256 public constant USDC_SEED_AMOUNT = 1_000_000e6;
    address public constant PYUSD = 0x6c3ea9036406852006290770BEdFcAbA0e23A0e8;
    uint256 public constant PYUSD_SEED_AMOUNT = 1_000_000e6;
    address public constant FRAX = 0x853d955aCEf822Db058eb8505911ED77F175b99e;
    uint256 public constant FRAX_SEED_AMOUNT = 1_000_000e18;
    address public constant weETHs = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    uint256 public constant weETHs_SEED_AMOUNT = 1e17;

    function _preExecute() internal override {
        // Set EtherFi Ethereum as ID 45, previous instance is ZkSync with ID 44
        IPoolAddressesProviderRegistry(AaveV3Ethereum.POOL_ADDRESSES_PROVIDER_REGISTRY).registerAddressesProvider(
            address(AaveV3EthereumEtherFi.POOL_ADDRESSES_PROVIDER), 45
        );
    }

    function _postExecute() internal override {
        // Roles
        AaveV3EthereumEtherFi.ACL_MANAGER.addPoolAdmin(0x2CFe3ec4d5a6811f4B8067F0DE7e47DfA938Aa30);
        AaveV3EthereumEtherFi.ACL_MANAGER.addRiskAdmin(AaveV3EthereumEtherFi.CAPS_PLUS_RISK_STEWARD);

        // Seed amounts
        IERC20(weETH).forceApprove(address(AaveV3EthereumEtherFi.POOL), weETH_SEED_AMOUNT);
        AaveV3EthereumEtherFi.POOL.supply(weETH, weETH_SEED_AMOUNT, address(AaveV3EthereumEtherFi.COLLECTOR), 0);
        IERC20(USDC).forceApprove(address(AaveV3EthereumEtherFi.POOL), USDC_SEED_AMOUNT);
        AaveV3EthereumEtherFi.POOL.supply(USDC, USDC_SEED_AMOUNT, address(AaveV3EthereumEtherFi.COLLECTOR), 0);
        IERC20(PYUSD).forceApprove(address(AaveV3EthereumEtherFi.POOL), PYUSD_SEED_AMOUNT);
        AaveV3EthereumEtherFi.POOL.supply(PYUSD, PYUSD_SEED_AMOUNT, address(AaveV3EthereumEtherFi.COLLECTOR), 0);
        IERC20(FRAX).forceApprove(address(AaveV3EthereumEtherFi.POOL), FRAX_SEED_AMOUNT);
        AaveV3EthereumEtherFi.POOL.supply(FRAX, FRAX_SEED_AMOUNT, address(AaveV3EthereumEtherFi.COLLECTOR), 0);
        IERC20(weETHs).forceApprove(address(AaveV3EthereumEtherFi.POOL), weETHs_SEED_AMOUNT);
        AaveV3EthereumEtherFi.POOL.supply(weETHs, weETHs_SEED_AMOUNT, address(AaveV3EthereumEtherFi.COLLECTOR), 0);

        // Catapulta service fee
        AaveV3Ethereum.COLLECTOR.transfer(MiscEthereum.GHO_TOKEN, 0x6D53be86136c3d4AA6448Ce4bF6178AD66e63661, 15000e18);
    }

    function newListings() public pure override returns (IAaveV3ConfigEngine.Listing[] memory) {
        IAaveV3ConfigEngine.Listing[] memory listings = new IAaveV3ConfigEngine.Listing[](5);
        listings[0] = IAaveV3ConfigEngine.Listing({
            asset: weETH,
            assetSymbol: "weETH",
            priceFeed: 0xf112aF6F0A332B815fbEf3Ff932c057E570b62d3,
            eModeCategory: AaveV3EthereumEtherFiEModes.NONE,
            enabledToBorrow: EngineFlags.DISABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: 78_00,
            liqThreshold: 81_00,
            liqBonus: 6_00,
            reserveFactor: 45_00,
            supplyCap: 50_000,
            borrowCap: 0,
            debtCeiling: 0,
            liqProtocolFee: 10_00,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 35_00,
                baseVariableBorrowRate: 0,
                variableRateSlope1: 7_00,
                variableRateSlope2: 300_00
            })
        });
        listings[1] = IAaveV3ConfigEngine.Listing({
            asset: USDC,
            assetSymbol: "USDC",
            priceFeed: 0x736bF902680e68989886e9807CD7Db4B3E015d3C,
            eModeCategory: AaveV3EthereumEtherFiEModes.NONE,
            enabledToBorrow: EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: 0,
            liqThreshold: 0,
            liqBonus: 0,
            reserveFactor: 10_00,
            supplyCap: 140_000_000,
            borrowCap: 135_000_000,
            debtCeiling: 0,
            liqProtocolFee: 10_00,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 90_00,
                baseVariableBorrowRate: 0,
                variableRateSlope1: 6_50,
                variableRateSlope2: 60_00
            })
        });
        listings[2] = IAaveV3ConfigEngine.Listing({
            asset: PYUSD,
            assetSymbol: "PYUSD",
            priceFeed: 0x150bAe7Ce224555D39AfdBc6Cb4B8204E594E022,
            eModeCategory: AaveV3EthereumEtherFiEModes.NONE,
            enabledToBorrow: EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: 0,
            liqThreshold: 0,
            liqBonus: 0,
            reserveFactor: 20_00,
            supplyCap: 60_000_000,
            borrowCap: 54_000_000,
            debtCeiling: 0,
            liqProtocolFee: 10_00,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 90_00,
                baseVariableBorrowRate: 0,
                variableRateSlope1: 5_50,
                variableRateSlope2: 80_00
            })
        });
        listings[3] = IAaveV3ConfigEngine.Listing({
            asset: FRAX,
            assetSymbol: "FRAX",
            priceFeed: 0x45D270263BBee500CF8adcf2AbC0aC227097b036,
            eModeCategory: AaveV3EthereumEtherFiEModes.NONE,
            enabledToBorrow: EngineFlags.ENABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: 0,
            liqThreshold: 0,
            liqBonus: 0,
            reserveFactor: 20_00,
            supplyCap: 15_000_000,
            borrowCap: 12_000_000,
            debtCeiling: 0,
            liqProtocolFee: 10_00,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 90_00,
                baseVariableBorrowRate: 0,
                variableRateSlope1: 5_50,
                variableRateSlope2: 80_00
            })
        });
        listings[4] = IAaveV3ConfigEngine.Listing({
            asset: weETHs,
            assetSymbol: "weETHs",
            priceFeed: 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f,
            eModeCategory: AaveV3EthereumEtherFiEModes.NONE,
            enabledToBorrow: EngineFlags.DISABLED,
            stableRateModeEnabled: EngineFlags.DISABLED,
            borrowableInIsolation: EngineFlags.DISABLED,
            withSiloedBorrowing: EngineFlags.DISABLED,
            flashloanable: EngineFlags.ENABLED,
            ltv: 78_00,
            liqThreshold: 81_00,
            liqBonus: 6_00,
            reserveFactor: 45_00,
            supplyCap: 50_000,
            borrowCap: 0,
            debtCeiling: 0,
            liqProtocolFee: 10_00,
            rateStrategyParams: IAaveV3ConfigEngine.InterestRateInputData({
                optimalUsageRatio: 35_00,
                baseVariableBorrowRate: 0,
                variableRateSlope1: 7_00,
                variableRateSlope2: 300_00
            })
        });

        return listings;
    }
}
