pragma solidity 0.8.21;

import {FixedPointMathLib} from "@solmate/utils/FixedPointMathLib.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";
import {Auth, Authority} from "@solmate/auth/Auth.sol";

contract PaymentSplitter is Auth {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for ERC20;

    //============================== STRUCTS ===============================

    struct SplitInformation {
        address to;
        uint96 percent;
    }

    //============================== STATE ===============================

    SplitInformation[] public splits;

    //============================== IMMUTABLES ===============================

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

    function rescueERC20(ERC20 asset) external requiresAuth {
        asset.safeTransfer(msg.sender, asset.balanceOf(address(this)));
    }

    // ========================================= PAYOUT =========================================

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
