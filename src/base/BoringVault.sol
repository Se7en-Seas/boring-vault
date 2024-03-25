// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {BeforeTransferHook} from "src/interfaces/BeforeTransferHook.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract BoringVault is ERC20, Auth, ERC721Holder, ERC1155Holder {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= STATE =========================================

    /**
     * @notice Contract responsbile for implementing `beforeTransfer`.
     */
    BeforeTransferHook public hook;

    //============================== EVENTS ===============================

    event Enter(address from, address asset, uint256 amount, address to, uint256 shares);
    event Exit(address to, address asset, uint256 amount, address from, uint256 shares);

    //============================== CONSTRUCTOR ===============================

    constructor(address _owner, string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
        Auth(_owner, Authority(address(0)))
    {}

    //============================== MANAGE ===============================

    /**
     * @notice Allows manager to make an arbitrary function call from this contract.
     */
    function manage(address target, bytes calldata data, uint256 value) external requiresAuth {
        target.functionCallWithValue(data, value);
    }

    /**
     * @notice Allows manager to make arbitrary function calls from this contract.
     */
    function manage(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
        external
        requiresAuth
    {
        uint256 targetsLength = targets.length;
        for (uint256 i; i < targetsLength; ++i) {
            targets[i].functionCallWithValue(data[i], values[i]);
        }
    }

    //============================== ENTER ===============================

    /**
     * @notice Allows minter to mint shares, in exchange for assets.
     * @dev If assetAmount is zero, no assets are transferred in.
     */
    function enter(address from, ERC20 asset, uint256 assetAmount, address to, uint256 shareAmount)
        external
        requiresAuth
    {
        // Transfer assets in
        if (assetAmount > 0) asset.safeTransferFrom(from, address(this), assetAmount);

        // Mint shares.
        _mint(to, shareAmount);

        emit Enter(from, address(asset), assetAmount, to, shareAmount);
    }

    //============================== EXIT ===============================

    /**
     * @notice Allows burner to burn shares, in exchange for assets.
     * @dev If assetAmount is zero, no assets are transferred out.
     */
    function exit(address to, ERC20 asset, uint256 assetAmount, address from, uint256 shareAmount)
        external
        requiresAuth
    {
        // Burn shares.
        _burn(from, shareAmount);

        // Transfer assets out.
        if (assetAmount > 0) asset.safeTransfer(to, assetAmount);

        emit Exit(to, address(asset), assetAmount, from, shareAmount);
    }

    //============================== BEFORE TRANSFER HOOK ===============================
    /**
     * @notice Sets the share locker.
     * @notice If set to zero address, the share locker logic is disabled.
     */
    function setBeforeTransferHook(address _hook) external requiresAuth {
        hook = BeforeTransferHook(_hook);
    }

    /**
     * @notice Check if from addresses shares are locked, reverting if so.
     */
    function _callBeforeTransfer(address from) internal view {
        if (address(hook) != address(0)) hook.beforeTransfer(from);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _callBeforeTransfer(msg.sender);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _callBeforeTransfer(from);
        return super.transferFrom(from, to, amount);
    }

    //============================== RECEIVE ===============================

    receive() external payable {}
}
