pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract PaymentSplitter is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    //============================== STRUCTS ===============================

    /**
     * @dev Represents a split of fee payments.
     * @param to The address to send the split to.
     * @param percent The percentage of the total fee to send to this address.
     */
    struct SplitInformation {
        address to;
        uint96 percent;
    }

    //============================== STATE ===============================

    /**
     * @notice Contains split information for each address.
     */
    SplitInformation[] public splits;

    //============================== IMMUTABLES ===============================

    /**
     * @notice The cumualative percents of all splits.
     */
    uint256 internal immutable totalPercent;

    constructor(address _owner, uint256 _totalPercent, SplitInformation[] memory _splits)
        Auth(_owner, Authority(address(0)))
    {
        totalPercent = _totalPercent;
        uint256 totalSplitPercent;
        for (uint256 i = 0; i < _splits.length; i++) {
            totalSplitPercent += _splits[i].percent;
            splits.push(_splits[i]);
        }

        require(totalSplitPercent == totalPercent, "PaymentSplitter: total percent is not 100%");
    }

    // ========================================= ADMIN =========================================

    /**
     * @notice Adjusts the splits of fee payments.
     */
    function adjustSplits(SplitInformation[] calldata _splits) external requiresAuth {
        // Empty out old splits.
        uint256 splitsLength = splits.length;
        for (uint256 i; i < splitsLength; i++) {
            splits.pop();
        }

        uint256 totalSplitPercent;
        for (uint256 i = 0; i < _splits.length; i++) {
            totalSplitPercent += _splits[i].percent;
            splits.push(_splits[i]);
        }

        require(totalSplitPercent == totalPercent, "PaymentSplitter: total percent is not 100%");
    }

    /**
     * @notice Rescues any ERC20 asset sent to this contract.
     */
    function rescueERC20(ERC20 asset) external requiresAuth {
        asset.safeTransfer(msg.sender, asset.balanceOf(address(this)));
    }

    // ========================================= PAYOUT =========================================

    /**
     * @notice Pays out the splits to the respective addresses.
     */
    function payoutSplits(ERC20 asset) external requiresAuth {
        // Subtract 1 from balance so we revert if balance is 0, and to also leave dust in this contract,
        // to reduce gas costs for future transactions.
        uint256 balance = asset.balanceOf(address(this)) - 1;
        for (uint256 i = 0; i < splits.length; ++i) {
            uint256 amount = balance.mulDivDown(splits[i].percent, totalPercent);
            asset.safeTransfer(splits[i].to, amount);
        }
    }
}
