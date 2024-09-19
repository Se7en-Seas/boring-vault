// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/src/20240902_AaveV3EthereumEtherFi_EtherFiEthereumActivation/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902.sol";
import {Test, stdStorage, StdStorage, stdError, console} from "@forge-std/Test.sol";

contract BoringDroneTest is Test, MerkleTreeHelper {
    using Address for address;

    address public aavePayloadController = 0xdAbad81aF85554E9ae636395611C58F7eC1aAEc5;
    address public aaveCreatePayloadCaller = 0x020E4359255f907DF480EbFfc8a7b7beac0c0216;
    address public aaveExecutePayloadCaller = 0x3Cbded22F878aFC8d39dCD744d3Fe62086B76193;
    address public aaveQueuePayloadCaller = 0xEd42a7D8559a463722Ca4beD50E0Cc05a386b0e1;
    address public aaveExecutor = 0x5300A1a15135EA4dc7aD5a167152C01EFc9b192A;

    address usdcWhale = 0x37305B1cD40574E4C5Ce33f8e8306Be057fD7341;
    address public aaveMarketSetup;

    function setUp() external {
        // Setup forked environment.
        string memory rpcKey = "MAINNET_RPC_URL";
        uint256 blockNumber = 20676058; // The block number before create payload was called

        // Then this is the tx where the payload was created.
        // https://etherscan.io/tx/0x025defc34c08bbe6c0fe56213cd11ec5d5dad8f66c817155a09de33d4f06e431
        // When the payload was executed.
        // https://etherscan.io/tx/0x8dce3e22688d50eaba48fbd1805623e7b7b9cb8910c96e609f279906c3d6ef67
        _startFork(rpcKey, blockNumber);
        setSourceChainName("mainnet");

        // Give executor enough assets to execute the payload.
        deal(getAddress(sourceChain, "WEETH"), aaveExecutor, 1e18);
        vm.prank(usdcWhale);
        getERC20(sourceChain, "USDC").transfer(aaveExecutor, 100e6);
        deal(getAddress(sourceChain, "PYUSD"), aaveExecutor, 100e6);
        deal(getAddress(sourceChain, "FRAX"), aaveExecutor, 1e18);

        aaveMarketSetup = address(new AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902());

        Action[] memory actions = new Action[](1);
        actions[0] = Action({
            target: aaveMarketSetup,
            withDelegateCall: true,
            accessLevel: 1,
            value: 0,
            signature: "execute()",
            callData: hex""
        });

        bytes memory payload =
            abi.encodeWithSignature("createPayload((address,bool,uint8,uint256,string,bytes)[])", actions);

        // Create payload
        vm.prank(aaveCreatePayloadCaller);
        (bool success,) = aavePayloadController.call(payload);
        require(success, "Failed to create payload");

        // Queue payload
        bytes memory queuePayload =
            hex"15034cba0000000000000000000000009aee0b04504cef83a65ac3f0e838d0593bcb2bc700000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a600000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000066d9c2d7";
        vm.prank(aaveQueuePayloadCaller);
        (success,) = aavePayloadController.call(queuePayload);
    }

    function testHunch() public {
        skip(5 days);
        bytes memory payload = abi.encodeWithSignature("executePayload(uint40)", 166);
        vm.prank(aaveExecutePayloadCaller);
        (bool success,) = aavePayloadController.call(payload);
        require(success, "Failed to execute payload");
    }

    // ========================================= HELPER FUNCTIONS =========================================

    struct Action {
        address target;
        bool withDelegateCall;
        uint8 accessLevel;
        uint256 value;
        string signature;
        bytes callData;
    }

    receive() external payable {}

    function _startFork(string memory rpcKey, uint256 blockNumber) internal returns (uint256 forkId) {
        forkId = vm.createFork(vm.envString(rpcKey), blockNumber);
        vm.selectFork(forkId);
    }
}
