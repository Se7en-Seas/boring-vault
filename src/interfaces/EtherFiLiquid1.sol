// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

interface EtherFiLiquid1 {
    struct AdaptorCall {
        address adaptor;
        bytes[] callData;
    }

    error CellarWithMultiAssetDeposit__AlternativeAssetFeeTooLarge();
    error CellarWithMultiAssetDeposit__AlternativeAssetNotSupported();
    error CellarWithMultiAssetDeposit__CallDataLengthNotSupported();
    error Cellar__AssetMismatch(address asset, address expectedAsset);
    error Cellar__CallToAdaptorNotAllowed(address adaptor);
    error Cellar__CallerNotBalancerVault();
    error Cellar__ContractNotShutdown();
    error Cellar__ContractShutdown();
    error Cellar__DebtMismatch(uint32 position);
    error Cellar__ExpectedAddressDoesNotMatchActual();
    error Cellar__ExternalInitiator();
    error Cellar__FailedToForceOutPosition();
    error Cellar__IlliquidWithdraw(address illiquidPosition);
    error Cellar__IncompleteWithdraw(uint256 assetsOwed);
    error Cellar__InvalidFee();
    error Cellar__InvalidFeeCut();
    error Cellar__InvalidHoldingPosition(uint32 positionId);
    error Cellar__InvalidRebalanceDeviation(uint256 requested, uint256 max);
    error Cellar__InvalidShareSupplyCap();
    error Cellar__MinimumConstructorMintNotMet();
    error Cellar__OracleFailure();
    error Cellar__Paused();
    error Cellar__PositionAlreadyUsed(uint32 position);
    error Cellar__PositionArrayFull(uint256 maxPositions);
    error Cellar__PositionNotEmpty(uint32 position, uint256 sharesRemaining);
    error Cellar__PositionNotInCatalogue(uint32 position);
    error Cellar__PositionNotUsed(uint32 position);
    error Cellar__RemovingHoldingPosition();
    error Cellar__SettingValueToRegistryIdZeroIsProhibited();
    error Cellar__ShareSupplyCapExceeded();
    error Cellar__TotalAssetDeviatedOutsideRange(uint256 assets, uint256 min, uint256 max);
    error Cellar__TotalSharesMustRemainConstant(uint256 current, uint256 expected);
    error Cellar__ZeroAssets();
    error Cellar__ZeroShares();

    event AdaptorCalled(address adaptor, bytes data);
    event AdaptorCatalogueAltered(address adaptor, bool inCatalogue);
    event AlternativeAssetDropped(address asset);
    event AlternativeAssetUpdated(address asset, uint32 holdingPosition, uint32 depositFee);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event AuthorityUpdated(address indexed user, address indexed newAuthority);
    event Deposit(address indexed caller, address indexed owner, uint256 assets, uint256 shares);
    event MultiAssetDeposit(
        address indexed caller, address indexed owner, address depositAsset, uint256 assets, uint256 shares
    );
    event OwnershipTransferred(address indexed user, address indexed newOwner);
    event PositionAdded(uint32 position, uint256 index);
    event PositionCatalogueAltered(uint32 positionId, bool inCatalogue);
    event PositionRemoved(uint32 position, uint256 index);
    event PositionSwapped(uint32 newPosition1, uint32 newPosition2, uint256 index1, uint256 index2);
    event RebalanceDeviationChanged(uint256 oldDeviation, uint256 newDeviation);
    event SharePriceOracleUpdated(address newOracle);
    event ShutdownChanged(bool isShutdown);
    event StrategistPayoutAddressChanged(address oldPayoutAddress, address newPayoutAddress);
    event StrategistPlatformCutChanged(uint64 oldPlatformCut, uint64 newPlatformCut);
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Withdraw(
        address indexed caller, address indexed receiver, address indexed owner, uint256 assets, uint256 shares
    );

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function addAdaptorToCatalogue(address adaptor) external;
    function addPosition(uint32 index, uint32 positionId, bytes memory configurationData, bool inDebtArray) external;
    function addPositionToCatalogue(uint32 positionId) external;
    function allowance(address, address) external view returns (uint256);
    function alternativeAssetData(address)
        external
        view
        returns (bool isSupported, uint32 holdingPosition, uint32 depositFee);
    function approve(address spender, uint256 amount) external returns (bool);
    function asset() external view returns (address);
    function authority() external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function blockExternalReceiver() external view returns (bool);
    function cachePriceRouter(bool checkTotalAssets, uint16 allowableRange, address expectedPriceRouter) external;
    function callOnAdaptor(AdaptorCall[] memory data) external;
    function convertToAssets(uint256 shares) external view returns (uint256 assets);
    function convertToShares(uint256 assets) external view returns (uint256 shares);
    function decimals() external view returns (uint8);
    function decreaseShareSupplyCap(uint192 _newShareSupplyCap) external;
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function dropAlternativeAssetData(address _alternativeAsset) external;
    function feeData()
        external
        view
        returns (uint64 strategistPlatformCut, uint64 platformFee, uint64 lastAccrual, address strategistPayoutAddress);
    function forcePositionOut(uint32 index, uint32 positionId, bool inDebtArray) external;
    function getCreditPositions() external view returns (uint32[] memory);
    function getDebtPositions() external view returns (uint32[] memory);
    function holdingPosition() external view returns (uint32);
    function ignorePause() external view returns (bool);
    function increaseShareSupplyCap(uint192 _newShareSupplyCap) external;
    function initiateShutdown() external;
    function isPaused() external view returns (bool);
    function isPositionUsed(uint256) external view returns (bool);
    function isShutdown() external view returns (bool);
    function liftShutdown() external;
    function locked() external view returns (bool);
    function maxDeposit(address) external view returns (uint256);
    function maxMint(address) external view returns (uint256);
    function maxRedeem(address owner) external view returns (uint256);
    function maxWithdraw(address owner) external view returns (uint256);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function multiAssetDeposit(address depositAsset, uint256 assets, address receiver)
        external
        returns (uint256 shares);
    function multicall(bytes[] memory data) external;
    function name() external view returns (string memory);
    function nonces(address) external view returns (uint256);
    function onERC721Received(address, address, uint256, bytes memory) external returns (bytes4);
    function owner() external view returns (address);
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s)
        external;
    function previewDeposit(uint256 assets) external view returns (uint256 shares);
    function previewMint(uint256 shares) external view returns (uint256 assets);
    function previewMultiAssetDeposit(address depositAsset, uint256 assets) external view returns (uint256 shares);
    function previewRedeem(uint256 shares) external view returns (uint256 assets);
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);
    function priceRouter() external view returns (address);
    function receiveFlashLoan(
        address tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external;
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function registry() external view returns (address);
    function removeAdaptorFromCatalogue(address adaptor) external;
    function removePosition(uint32 index, bool inDebtArray) external;
    function removePositionFromCatalogue(uint32 positionId) external;
    function setAlternativeAssetData(
        address _alternativeAsset,
        uint32 _alternativeHoldingPosition,
        uint32 _alternativeAssetFee
    ) external;
    function setAuthority(address newAuthority) external;
    function setHoldingPosition(uint32 positionId) external;
    function setRebalanceDeviation(uint256 newDeviation) external;
    function setSharePriceOracle(uint256 _registryId, address _sharePriceOracle) external;
    function setStrategistPayoutAddress(address payout) external;
    function setStrategistPlatformCut(uint64 cut) external;
    function sharePriceOracle() external view returns (address);
    function shareSupplyCap() external view returns (uint192);
    function swapPositions(uint32 index1, uint32 index2, bool inDebtArray) external;
    function symbol() external view returns (string memory);
    function toggleIgnorePause() external;
    function totalAssets() external view returns (uint256 assets);
    function totalAssetsWithdrawable() external view returns (uint256 assets);
    function totalSupply() external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transferOwnership(address newOwner) external;
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
}
