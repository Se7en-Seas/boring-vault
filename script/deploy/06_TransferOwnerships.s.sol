
// // SPDX-License-Identifier: Apache-2.0
// pragma solidity 0.8.21;

// import { BaseScript } from "./../Base.s.sol";

// /**
//  * Update `rolesAuthority` and transfer ownership from deployer EOA to the
//  * protocol.
//  */
// contract TransferOwnerships is BaseScript {
//     // TODO Refactor deployed addresses in multiple .json file to a single one
//     function run() public broadcast {
//         boringVault.setAuthority(rolesAuthority);
//         manager.setAuthority(rolesAuthority);
//         accountant.setAuthority(rolesAuthority);
//         teller.setAuthority(rolesAuthority);

//         boringVault.transferOwnership(protocolAdmin);
//         manager.transferOwnership(protocolAdmin);
//         accountant.transferOwnership(protocolAdmin);
//         teller.transferOwnership(protocolAdmin);

//         rolesAuthority.transferOwnership(protocolAdmin);
//     }
// }