// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {BaseScript} from "./../Base.s.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

interface IAuthority {
    function setAuthority(address newAuthority) external;
    function transferOwnership(address newOwner) external;
    function owner() external returns (address);
}

/**
 * Update `rolesAuthority` and transfer ownership from deployer EOA to the
 * protocol.
 */
contract SetAuthorityAndTransferOwnerships is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/06_SetAuthorityAndTransferOwnerships.json";
    string config = vm.readFile(path);

    IAuthority boringVault = IAuthority(config.readAddress(".boringVault"));
    IAuthority manager = IAuthority(config.readAddress(".manager"));
    IAuthority accountant = IAuthority(config.readAddress(".accountant"));
    IAuthority teller = IAuthority(config.readAddress(".teller"));

    address rolesAuthority = config.readAddress(".rolesAuthority");

    function run() public broadcast {
        require(address(boringVault).code.length != 0, "boringVault must have code");
        require(address(manager).code.length != 0, "manager must have code");
        require(address(teller).code.length != 0, "teller must have code");
        require(address(accountant).code.length != 0, "accountant must have code");
        
        require(address(boringVault) != address(0), "boringVault");
        require(address(manager) != address(0), "manager");
        require(address(accountant) != address(0), "accountant");
        require(address(teller) != address(0), "teller");
        require(rolesAuthority != address(0), "rolesAuthority");

        require(protocolAdmin != address(0), "protocolAdmin");

        boringVault.setAuthority(rolesAuthority);
        manager.setAuthority(rolesAuthority);
        accountant.setAuthority(rolesAuthority);
        teller.setAuthority(rolesAuthority);

        boringVault.transferOwnership(protocolAdmin);
        manager.transferOwnership(protocolAdmin);
        accountant.transferOwnership(protocolAdmin);
        teller.transferOwnership(protocolAdmin);

        IAuthority(rolesAuthority).transferOwnership(protocolAdmin);

        require(boringVault.owner() == protocolAdmin, "boringVault");
        require(manager.owner() == protocolAdmin, "manager");
        require(accountant.owner() == protocolAdmin, "accountant");
        require(teller.owner() == protocolAdmin, "teller");
    }
}
