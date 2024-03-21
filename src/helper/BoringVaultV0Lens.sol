// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

contract BoringVaultV0Lens {
    function totalAssets() external view returns (uint256 assets);
    function previewDeposit() external view returns (uint256 shares);
    function balanceOf(address account) external view returns (uint256 shares);
    function balanceOfInAssets(address account) external view returns (uint256 assets);
    function pendingBalanceOf(address account) external view returns (uint256 shares);
    // useful for net value
    function pendingBalanceOfInAssets(address account) external view returns (uint256 assets);
    function exchangeRate() external view returns (uint256 rate);
    // Functions check if contract is paused, if deposit asset is good, and if users allowance is good, also user balance
    function checkUserDeposit() external view returns (bool);
    function checkUserDepositWithPermit() external view returns (bool);
    // when user shares are unlocked
    function userUnlockTime() external view returns (uint256);
}
