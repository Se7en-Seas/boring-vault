// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

// Swell
interface ISWETH {
    function deposit() external payable;
}

// EtherFi
interface ILiquidityPool {
    function deposit() external payable returns (uint256);

    function requestWithdraw(address recipient, uint256 amount) external returns (uint256);

    function amountForShare(uint256 shares) external view returns (uint256);

    function etherFiAdminContract() external view returns (address);

    function addEthAmountLockedForWithdrawal(uint128 _amount) external;
}

interface IWithdrawRequestNft {
    struct WithdrawRequest {
        uint96 amountOfEEth;
        uint96 shareOfEEth;
        bool isValid;
        uint32 feeGwei;
    }

    function claimWithdraw(uint256 tokenId) external;

    function getRequest(uint256 requestId) external view returns (WithdrawRequest memory);

    function finalizeRequests(uint256 requestId) external;

    function owner() external view returns (address);

    function updateAdmin(address admin, bool isAdmin) external;
}

interface IWEETH {
    function wrap(uint256 amount) external returns (uint256);

    function unwrap(uint256 amount) external returns (uint256);

    function getRate() external view returns (uint256);
}

// Kelp DAO
interface ILRTDepositPool {
    function depositAsset(
        address asset,
        uint256 depositAmount,
        uint256 minRSETHAmountToReceive,
        string calldata referralId
    ) external;
}

// Lido
interface ISTETH {
    function submit(address referral) external payable returns (uint256);
}

interface IWSTETH {
    function wrap(uint256 amount) external returns (uint256);

    function unwrap(uint256 amount) external returns (uint256);
}

interface IUNSTETH {
    struct WithdrawalRequestStatus {
        /// @notice stETH token amount that was locked on withdrawal queue for this request
        uint256 amountOfStETH;
        /// @notice amount of stETH shares locked on withdrawal queue for this request
        uint256 amountOfShares;
        /// @notice address that can claim or transfer this request
        address owner;
        /// @notice timestamp of when the request was created, in seconds
        uint256 timestamp;
        /// @notice true, if request is finalized
        bool isFinalized;
        /// @notice true, if request is claimed. Request is claimable if (isFinalized && !isClaimed)
        bool isClaimed;
    }

    function getWithdrawalStatus(uint256[] calldata _requestIds)
        external
        view
        returns (WithdrawalRequestStatus[] memory statuses);

    function requestWithdrawals(uint256[] calldata _amounts, address _owner)
        external
        returns (uint256[] memory requestIds);

    function claimWithdrawal(uint256 _requestId) external;

    function claimWithdrawals(uint256[] calldata _requestIds, uint256[] calldata _hints) external;

    function finalize(uint256 _lastRequestIdToBeFinalized, uint256 _maxShareRate) external payable;

    function getRoleMember(bytes32 role, uint256 index) external view returns (address);

    function FINALIZE_ROLE() external view returns (bytes32);

    function getLastFinalizedRequestId() external view returns (uint256);

    function getLastCheckpointIndex() external view returns (uint256);

    function findCheckpointHints(uint256[] memory requestIds, uint256 firstIndex, uint256 lastIndex)
        external
        view
        returns (uint256[] memory);

    function getClaimableEther(uint256[] memory requestIds, uint256[] memory hints)
        external
        view
        returns (uint256[] memory);
}

// Renzo
interface IRestakeManager {
    function depositETH() external payable;
}

// Stader
interface IStakePoolManager {
    function deposit(address _receiver) external payable returns (uint256);

    function getExchangeRate() external view returns (uint256);
}

interface IStaderConfig {
    function getDecimals() external view returns (uint256);
}

interface IUserWithdrawManager {
    struct WithdrawRequest {
        address owner;
        uint256 ethXAmount;
        uint256 ethExpected;
        uint256 ethFinalized;
        uint256 requestTime;
    }

    function requestWithdraw(uint256 _ethXAmount, address _owner) external returns (uint256);

    function claim(uint256 _requestId) external;

    function userWithdrawRequests(uint256) external view returns (WithdrawRequest memory);

    function finalizeUserWithdrawalRequest() external;
}
