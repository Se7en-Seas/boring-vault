// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.21;

import {AccountantWithRateProviders} from "./../../src/base/Roles/AccountantWithRateProviders.sol";
import {BaseScript} from "./../Base.s.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {stdJson as StdJson} from "forge-std/StdJson.sol";

contract DeployAccountantWithRateProviders is BaseScript {
    using StdJson for string;

    string path = "./deployment-config/03_DeployAccountantWithRateProviders.json";
    string config = vm.readFile(path);

    bytes32 accountantSalt = config.readBytes32(".accountantSalt");
    address boringVault = config.readAddress(".boringVault");
    address payoutAddress = config.readAddress(".payoutAddress");
    address base = config.readAddress(".base");
    uint16 allowedExchangeRateChangeUpper = uint16(config.readUint(".allowedExchangeRateChangeUpper"));
    uint16 allowedExchangeRateChangeLower = uint16(config.readUint(".allowedExchangeRateChangeLower"));
    uint32 minimumUpdateDelayInSeconds = uint32(config.readUint(".minimumUpdateDelayInSeconds"));
    uint16 managementFee = uint16(config.readUint(".managementFee"));

    function run() public broadcast returns (AccountantWithRateProviders accountant) {
        uint256 startingExchangeRate = 10 ** ERC20(base).decimals();

        require(boringVault.code.length != 0, "boringVault must have code");
        require(base.code.length != 0, "base must have code");

        require(accountantSalt != bytes32(0), "accountant salt must not be zero");
        require(boringVault != address(0), "boring vault address must not be zero");
        require(payoutAddress != address(0), "payout address must not be zero");
        require(base != address(0), "base address must not be zero");

        require(allowedExchangeRateChangeUpper > 1e4, "allowedExchangeRateChangeUpper");
        require(allowedExchangeRateChangeUpper <= 1.0003e4, "allowedExchangeRateChangeUpper upper bound");

        require(allowedExchangeRateChangeLower < 1e4, "allowedExchangeRateChangeLower");
        require(allowedExchangeRateChangeLower >= 0.9997e4, "allowedExchangeRateChangeLower lower bound");

        require(minimumUpdateDelayInSeconds >= 3600, "minimumUpdateDelayInSeconds");

        require(managementFee < 1e4, "managementFee");

        require(startingExchangeRate == 1e18, "starting exchange rate must be 1e18");

        bytes memory creationCode = type(AccountantWithRateProviders).creationCode;

        accountant = AccountantWithRateProviders(
            CREATEX.deployCreate3(
                accountantSalt,
                abi.encodePacked(
                    creationCode,
                    abi.encode(
                        broadcaster,
                        boringVault,
                        payoutAddress,
                        startingExchangeRate,
                        base,
                        allowedExchangeRateChangeUpper,
                        allowedExchangeRateChangeLower,
                        minimumUpdateDelayInSeconds,
                        managementFee
                    )
                )
            )
        );

        (
            address _payoutAddress,
            uint128 _feesOwedInBase,
            uint128 _totalSharesLastUpdate,
            uint96 _exchangeRate,
            uint16 _allowedExchangeRateChangeUpper,
            uint16 _allowedExchangeRateChangeLower,
            uint64 _lastUpdateTimestamp,
            bool _isPaused,
            uint32 _minimumUpdateDelayInSeconds,
            uint16 _managementFee
        ) = accountant.accountantState();

        require(_payoutAddress == payoutAddress, "payout address");
        require(_feesOwedInBase == 0, "fees owed in base");
        require(_totalSharesLastUpdate == 0, "total shares last update");
        require(_exchangeRate == startingExchangeRate, "exchange rate");
        require(_allowedExchangeRateChangeUpper == allowedExchangeRateChangeUpper, "allowed exchange rate change upper");
        require(_allowedExchangeRateChangeLower == allowedExchangeRateChangeLower, "allowed exchange rate change lower");
        require(_lastUpdateTimestamp == uint64(block.timestamp), "last update timestamp");
        require(_isPaused == false, "is paused");
        require(_minimumUpdateDelayInSeconds == minimumUpdateDelayInSeconds, "minimum update delay in seconds");
        require(_managementFee == managementFee, "management fee");

        require(address(accountant.vault()) == boringVault, "vault");
        require(address(accountant.base()) == base, "base");
        require(accountant.decimals() == ERC20(base).decimals(), "decimals");
    }
}
