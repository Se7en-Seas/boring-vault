// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV3EthereumEtherFi} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/src/AaveV3EthereumEtherFi.sol";
import
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/lib/aave-helpers/lib/aave-address-book/lib/aave-v3-origin/src/periphery/contracts/v3-config-engine/AaveV3Payload.sol";

/**
 * @dev Base smart contract for an Aave v3.1.0 listing on v3 Ethereum EtherFi.
 * @author BGD Labs
 */
abstract contract AaveV3PayloadEthereumEtherFi is AaveV3Payload(IEngine(AaveV3EthereumEtherFi.CONFIG_ENGINE)) {
    function getPoolContext() public pure override returns (IEngine.PoolContext memory) {
        return IEngine.PoolContext({networkName: "Ethereum EtherFi", networkAbbreviation: "EthEtherFi"});
    }
}
