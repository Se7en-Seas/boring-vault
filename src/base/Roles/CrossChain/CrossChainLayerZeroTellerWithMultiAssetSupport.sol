// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ICrosschainTeller, ERC20} from "../../../interfaces/ICrosschainTeller.sol";
import {TellerWithMultiAssetSupport} from "../TellerWithMultiAssetSupport.sol";

contract CrossChainLayerZeroTellerWithMultiAssetSupport is ICrosschainTeller, TellerWithMultiAssetSupport{

    constructor(address _owner, address _vault, address _accountant, address _weth)
        TellerWithMultiAssetSupport(_owner, _vault, _accountant, _weth)
    {

    }

    /**
     * @dev function to deposit into the vault AND bridge cosschain in 1 call
     * @param depositAsset ERC20 to deposit
     * @param depositAmount amount of deposit asset to deposit
     * @param minimumMint minimum required shares to receive
     * @param data Bridge Data
     */
    function depositAndBridge(ERC20 depositAsset, uint256 depositAmount, uint256 minimumMint, BridgeData calldata data) external{
        
    }

    /**
     * @dev only code for bridging for users who already deposited
     * @param shareAmount to bridge
     * @param data bridge data
     */
    function bridge(uint256 shareAmount, BridgeData calldata data) external{

    }
}