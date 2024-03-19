// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {AccessControlDefaultAdminRules} from
    "@openzeppelin/contracts/access/extensions/AccessControlDefaultAdminRules.sol";
import {IShareLocker} from "src/interfaces/IShareLocker.sol";

contract BoringVault is ERC20, AccessControlDefaultAdminRules, ERC721Holder, ERC1155Holder {
    using Address for address;
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    // ========================================= CONSTANTS =========================================

    /**
     * @notice Role needed to rebalance the vault.
     */
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    /**
     * @notice Role needed to deposit into vault.
     */
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /**
     * @notice Role needed to withdraw form vault.
     */
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    //============================== EVENTS ===============================

    event Enter(address from, address asset, uint256 amount, address to, uint256 shares);
    event Exit(address to, address asset, uint256 amount, address from, uint256 shares);

    //============================== CONSTRUCTOR ===============================

    constructor(address _owner, string memory _name, string memory _symbol, uint8 _decimals)
        ERC20(_name, _symbol, _decimals)
        AccessControlDefaultAdminRules(3 days, _owner)
    {}

    //============================== MANAGE ===============================

    /**
     * @notice Allows manager to make an arbitrary function call from this contract.
     */
    function manage(address target, bytes calldata data, uint256 value) external onlyRole(MANAGER_ROLE) {
        target.functionCallWithValue(data, value);
    }

    /**
     * @notice Allows manager to make arbitrary function calls from this contract.
     */
    function manage(address[] calldata targets, bytes[] calldata data, uint256[] calldata values)
        external
        onlyRole(MANAGER_ROLE)
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
        onlyRole(MINTER_ROLE)
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
        onlyRole(BURNER_ROLE)
    {
        // Burn shares.
        _burn(from, shareAmount);

        // Transfer assets out.
        if (assetAmount > 0) asset.safeTransfer(to, assetAmount);

        emit Exit(to, address(asset), assetAmount, from, shareAmount);
    }

    //============================== SHARELOCKER ===============================

    IShareLocker public locker;

    function setShareLocker(address _locker) external {
        locker = IShareLocker(_locker);
    }

    function _checkShareLock(address from) internal view {
        if (address(locker) != address(0)) locker.revertIfLocked(from);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _checkShareLock(msg.sender);
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _checkShareLock(from);
        return super.transferFrom(from, to, amount);
    }

    //============================== RECEIVE ===============================

    receive() external payable {}

    //============================== VIEW ===============================

    /**
     * @notice Override this here, so that we only report supporting ERC1155, and not the AccessControl interface.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Holder, AccessControlDefaultAdminRules)
        returns (bool)
    {
        return ERC1155Holder.supportsInterface(interfaceId);
    }
}
