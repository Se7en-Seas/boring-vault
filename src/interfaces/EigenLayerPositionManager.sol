// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface PositionManager {
    struct Withdrawal {
        address staker;
        address delegatedTo;
        address withdrawer;
        uint256 nonce;
        uint32 startBlock;
        address[] strategies;
        uint256[] shares;
    }

    event ApproveToken(address indexed token, address guy, uint256 wad);
    event Assemble(address indexed caller, address[] tokens, uint256[] amounts, uint256 lpt_change);
    event Deposit(address indexed caller, address token, uint256 amount, uint256 lpt_change);
    event Disassemble(address indexed caller, address[] tokens, uint256[] amounts, uint256 lpt_change);
    event ExecutorUpdated(address indexed executor, bool enabled);
    event LogWithdraw(address indexed _to, address indexed _asset_address, uint256 amount);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event StartWithdrawal(
        address indexed caller,
        address token,
        uint256 withdrawal_nonce,
        uint256 withdrawal_index,
        uint256 start_block,
        uint256 withdrawal_block,
        uint256 lpt_amount
    );
    event UpdateDelegationManager(address indexed caller, address delegation_manager);
    event UpdatePositionConfig(address indexed caller, address liquid_staking, address underlying, address delegate_to);
    event UpdateStrategyManager(address indexed caller, address strategy_manager);
    event Withdraw(
        address indexed caller,
        address token,
        uint256 withdrawal_nonce,
        uint256 withdrawal_index,
        uint256 amount,
        uint256 lpt_change
    );

    receive() external payable;

    function VERSION() external pure returns (string memory);
    function WNATIVE() external view returns (address payable);
    function acceptOwnership() external;
    function addExecutor(address _executor) external;
    function approveToken(address _token, address _guy, uint256 _wad) external;
    function assemble(uint256 _min_lpt_out) external returns (uint256 lpt_out);
    function balanceOf(address _asset_address, address _account) external view returns (uint256);
    function batchExecute(address[] memory _tos, uint256[] memory _values, bytes[] memory _datas) external payable;
    function canCompleteWithdrawals() external view returns (bool);
    function completeNextWithdrawal(uint256 _min_out) external returns (uint256 lpt_burnt, uint256 coin_out);
    function completeNextWithdrawals(uint256 _min_out)
        external
        returns (uint256 total_lpt_burnt, uint256 total_coin_out);
    function completeWithdrawal(uint256 _withdrawal_index, uint256 _min_out)
        external
        returns (uint256 lpt_burnt, uint256 coin_out);
    function cumulativeWithdrawalsQueued() external view returns (uint256);
    function delegate() external;
    function delegation_manager() external view returns (address);
    function deposit(uint256 _amount, uint256 _min_lpt_out) external returns (uint256 lpt_out);
    function disassemble(uint256 _percentage, uint256 _min_coin_out) external returns (uint256 coin_out);
    function execute(address _to, uint256 _value, bytes memory _data) external payable;
    function executors(address) external view returns (bool);
    function fullDisassemble(uint256 _min_coin_out) external returns (uint256);
    function getLPTStaked() external view returns (uint256);
    function getPositionAssets() external view returns (address[] memory);
    function getTotalLPT() external view returns (uint256);
    function getUnderlyings() external view returns (address[] memory assets, uint256[] memory amounts);
    function getWithdrawalDelay() external view returns (uint256);
    function haveWithdrawalsQueued() external view returns (bool);
    function indexNextWithdrawal() external view returns (uint256);
    function lptPendingOfWithdraw() external view returns (uint256 amount_pending);
    function nextWithdrawalIsReady() external view returns (bool);
    function overrideWithdrawalIndexes(uint256 _cumulativeWithdrawalsQueued, uint256 _indexNextWithdrawal) external;
    function owner() external view returns (address);
    function pendingOwner() external view returns (address);
    function positionConfig() external view returns (address liquid_staking, address underlying, address delegate_to);
    function removeExecutor(address _executor) external;
    function renounceOwnership() external;
    function revokeToken(address _token, address _guy) external;
    function startWithdrawal(uint256 _shares_amount) external;
    function strategy_manager() external view returns (address);
    function transferOwnership(address newOwner) external;
    function unwrapNative(uint256 _amount) external;
    function updateDelegationManager(address _delegation_manager) external;
    function updatePositionConfig(address _liquid_staking, address _underlying, address _delegate_to) external;
    function updateStrategyManager(address _strategy_manager) external;
    function withdraw(address _asset_address, uint256 _amount) external;
    function withdrawAll(address _asset_address) external;
    function withdrawAllTo(address _asset_address, address payable _to) external;
    function withdrawTo(address _asset_address, uint256 _amount, address payable _to) external;
    function withdrawalIsPending(uint256 _withdrawal_index) external view returns (bool);
    function withdrawalIsReady(uint256 _withdrawal_index) external view returns (bool);
    function withdrawalQueue(uint256) external view returns (uint256 withdrawal_block, Withdrawal memory withdrawal);
    function wrapNative(uint256 _amount) external;
}
