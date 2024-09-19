// SPDX-License-Identifier: MIT
pragma solidity >=0.6.0;

import {DataTypes} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/protocol/libraries/types/DataTypes.sol";
import {Errors} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/protocol/libraries/helpers/Errors.sol";
import {ConfiguratorInputTypes} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/protocol/libraries/types/ConfiguratorInputTypes.sol";
import {IPoolAddressesProvider} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPoolAddressesProvider.sol";
import {IAToken} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IAToken.sol";
import {IPool} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPool.sol";
import {IPoolConfigurator} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPoolConfigurator.sol";
import {IPriceOracleGetter} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPriceOracleGetter.sol";
import {IAaveOracle} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IAaveOracle.sol";
import {IACLManager as BasicIACLManager} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IACLManager.sol";
import {IPoolDataProvider} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPoolDataProvider.sol";
import {IDefaultInterestRateStrategyV2} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IDefaultInterestRateStrategyV2.sol";
import {IReserveInterestRateStrategy} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IReserveInterestRateStrategy.sol";
import {IPoolDataProvider as IAaveProtocolDataProvider} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/interfaces/IPoolDataProvider.sol";
import {AggregatorInterface} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/core/contracts/dependencies/chainlink/AggregatorInterface.sol";

interface IACLManager is BasicIACLManager {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function DEFAULT_ADMIN_ROLE() external pure returns (bytes32);

    function renounceRole(bytes32 role, address account) external;

    function getRoleAdmin(bytes32 role) external view returns (bytes32);

    function grantRole(bytes32 role, address account) external;

    function revokeRole(bytes32 role, address account) external;
}
