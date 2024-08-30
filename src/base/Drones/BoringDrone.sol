// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {DroneLib} from "src/base/Drones/DroneLib.sol";

//                                            .
//                                         ......
//                                         ..........
//                                         ..:::.......
//                                         ..::........
//                                         ....::::.......
//                                         ......::..:....
//                                         ........:..:...
//                   ............          .......:.:........
//                    ..:::.........       ..........:..::...
//                    ....::::..::.....    ..........:...::..
//                      ....-:::...::....  ...............:-...
//                       .....--::::.::................:...:...
//                           ...:-::::::::..............:..:::.
//                            .....--:::::-:.............:::::....
//                               ....:==-:::--............::..-...
//                                 .....:*+-:::::..........::.:-..
//                                   ......:+*=---:.......:::::::......
//                              ........::::--+#*==:....:-------::........
//                           .....-=---=+-=+--===##==:..-+++++=====---:....
//                         ....=*##*====-+*=++=-===+#+=-=*+**+*******+==:......
//                    .....==:=####*=----*+==+=====::=#*++*******##*****=-:.......
//                 ......:##+-++=+++=---+####*+==--:--=+#%#*###**********==++=-.....
//                 ....-:+%*=---===++==+*%%%###++=-----+*#@%###@%%###****#*#%%**+=:..
//                 ..:*=-===----+*###**++%###%%#*+=+====+++**#@@%%%##**#%%#%@%###*-....
//                 ..+#=--++*+++*#%%%##***#%%%%%%#*+++==+***+++=+%%###%%%%%%%%@%##=.::.
//                ..-=#+==+#%%#***#++##%######%##%@%#*++##*+**+*##%%#%##%##+##@@%*+:=+:.
//               ..=+-*%%#*+#%%*+=%@#+*%@%%%%%%###%#*===*********##%%%*#*#@@%@%%*=-==::..
//               ..*%#++####***+#@@%===-=+#%@%*+++##+=-==+*******#%@%*=##%@@@@%%**+=-+:..
//               ..=###*++**+=+%@@@#--::.....::-*#=++=---==++++*#%%#+=-**@@@@@%**#-....
//              ...-**++++===+@%%%%=...........+#*+##=::::::-=+%*---::-=+#@@@%#+##-....
//              ....::::::---@@@%#*:...    ...-#@#:........:=%@#:.....::=+*###**##:.
//                 ..........=+%@%=..      ...*%%*.........:#@%-....=-:::-=+***#+-...
//                       ...#@%%%#:..      ..:%@@=..     ...+%%... ...==---+*##*=...
//                      ...#@@@@@%:.       ..:#@%:..     ..=*#-... ..........-#**...
//                      ..*@@@@@%-...      ..:*#+....   ..=*@%..          ....=+..
//                     ..:%@%%%#:...       ..-@@%:...   ..+@@+.              ....
//                   .....-*%%*...         ..=@@%-...  ...=%#:.
//                   ....:*#:.....         ..-@%%-..   ..:%=...
//                 ..:+++-.......          ...+*#:.. ....**:.
//                 ..-:......              ....==.......=*:..
//                 ....                    ...-#:. ....-+:...
//                 ....                    ..:=:.. ..:*=....
//                                         ....... .:=-...
//                                ...              .......
//
//
contract BoringDrone is ERC721Holder, ERC1155Holder {
    using Address for address;

    //============================== MODIFIERS ===============================

    modifier onlyBoringVault() {
        if (msg.sender != boringVault) revert BoringDrone__OnlyBoringVault();
        _;
    }

    //============================== ERRORS ===============================

    error BoringDrone__OnlyBoringVault();
    error BoringDrone__ReceiveFailed();

    //============================== CONSTRUCTOR ===============================

    /**
     * @notice The address of the BoringVault that can control this drone.
     */
    address internal immutable boringVault;

    /**
     * @notice The amount of gas needed to forward native to the BoringVault.
     * @dev This value was determined from guess and check. Realisitically, the value should be closer to 10k, but
     *      21k is used for extra safety.
     */
    uint256 internal immutable safeGasToForwardNative;

    constructor(address _boringVault, uint256 _safeGasToForwardNative) {
        boringVault = _boringVault;
        safeGasToForwardNative = _safeGasToForwardNative < 21_000 ? 21_000 : _safeGasToForwardNative;
    }

    //============================== WITHDRAW ===============================

    /**
     * @notice Withdraws all native from the drone.
     */
    function withdrawNativeFromDrone() external onlyBoringVault {
        (bool success,) = boringVault.call{value: address(this).balance}("");
        if (!success) revert BoringDrone__ReceiveFailed();
    }

    //============================== FALLBACK ===============================

    /**
     * @notice This contract in its current state can only be interacted with by the BoringVault.
     * @notice The real target is extracted from the call data using `extractTargetFromCalldata()`.
     * @notice The drone then forwards
     */
    fallback() external payable onlyBoringVault {
        // Extract real target from end of calldata
        address target = DroneLib.extractTargetFromCalldata();

        // Forward call to real target.
        target.functionCallWithValue(msg.data, msg.value);
    }

    //============================== RECEIVE ===============================

    receive() external payable {
        // If gas left is less than safe gas needed to forward native, return.
        if (gasleft() < safeGasToForwardNative) return;

        (bool success,) = boringVault.call{value: msg.value}("");
        if (!success) revert BoringDrone__ReceiveFailed();
    }
}
