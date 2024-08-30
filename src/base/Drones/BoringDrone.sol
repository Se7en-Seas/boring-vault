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
     * @notice The address of the BoringVault that can control this puppet.
     */
    address internal immutable boringVault;

    constructor(address _boringVault) {
        boringVault = _boringVault;
    }

    //============================== WITHDRAW ===============================

    function withdrawNativeFromDrone() external onlyBoringVault {
        (bool success,) = boringVault.call{value: address(this).balance}("");
        if (!success) revert BoringDrone__ReceiveFailed();
    }

    //============================== FALLBACK ===============================

    /**
     * @notice This contract in its current state can only be interacted with by the BoringVault.
     * @notice The real target is extracted from the call data using `extractTargetFromCalldata()`.
     * @notice The puppet then forwards
     */
    fallback() external payable onlyBoringVault {
        // Exctract real target from end of calldata
        address target = DroneLib.extractTargetFromCalldata();

        // Forward call to real target.
        target.functionCallWithValue(msg.data, msg.value);
    }

    //============================== RECEIVE ===============================

    receive() external payable {
        // If gas left is less than minimum gas needed to forward ETH, return.
        if (gasleft() < 2_300) return;

        (bool success,) = boringVault.call{value: msg.value}("");
        if (!success) revert BoringDrone__ReceiveFailed();
    }
}
