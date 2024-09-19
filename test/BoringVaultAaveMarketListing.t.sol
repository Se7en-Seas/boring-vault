// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Auth, Authority} from "@solmate/auth/Auth.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {MerkleTreeHelper, ERC20} from "test/resources/MerkleTreeHelper/MerkleTreeHelper.sol";
import {AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902} from
    "src/helper/AaveV3EtherFiSetup/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902/src/20240902_AaveV3EthereumEtherFi_EtherFiEthereumActivation/AaveV3EthereumEtherFi_EtherFiEthereumActivation_20240902.sol";
import {MockAaveOracle} from "src/helper/MockAaveOracle.sol";
import {IAaveV3Pool} from "src/interfaces/IAaveV3Pool.sol";
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
    address public mockOracle;
    IAaveV3Pool public aaveV3Pool;

    address public constant weETHs = 0x917ceE801a67f933F2e6b33fC0cD1ED2d5909D88;
    address public constant weETHs_accountant = 0xbe16605B22a7faCEf247363312121670DFe5afBE;
    address public constant eth_usd_feed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

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
        getERC20(sourceChain, "USDC").transfer(aaveExecutor, 1_000_000e6);
        deal(getAddress(sourceChain, "PYUSD"), aaveExecutor, 1_000_000e6);
        deal(getAddress(sourceChain, "FRAX"), aaveExecutor, 1_000_000e18);
        deal(weETHs, aaveExecutor, 1e18);

        mockOracle = address(new MockAaveOracle(weETHs_accountant, eth_usd_feed));

        assertTrue(mockOracle == 0x5615dEB798BB3E4dFa0139dFa1b3D433Cc23b72f, "Update oracle in aave setup contract");

        aaveV3Pool = IAaveV3Pool(getAddress(sourceChain, "v3EtherFiPool"));

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

        skip(5 days);
        payload = abi.encodeWithSignature("executePayload(uint40)", 166);
        vm.prank(aaveExecutePayloadCaller);
        (success,) = aavePayloadController.call(payload);
        require(success, "Failed to execute payload");
    }

    function testSupplyingweETHsAndBorrowing() public {
        deal(weETHs, address(this), 1_000e18);

        // Approve pool to spend weETHs.
        ERC20(weETHs).approve(address(aaveV3Pool), 1_000e18);

        // Supply weETHs to the pool.
        aaveV3Pool.supply(weETHs, 1_000e18, address(this), 0);

        // Borrow USDC from pool.
        aaveV3Pool.borrow(getAddress(sourceChain, "USDC"), 1_000e6, 2, 0, address(this));

        // Check if we have borrowed USDC.
        assertEq(
            getERC20(sourceChain, "USDC").balanceOf(address(this)),
            1_000e6,
            "This contract should have borrowed 1_000 USDC"
        );
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
