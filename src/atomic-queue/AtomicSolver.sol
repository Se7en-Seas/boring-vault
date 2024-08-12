// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {AtomicQueue, ERC20, SafeTransferLib} from "./AtomicQueue.sol";
import {IAtomicSolver} from "./IAtomicSolver.sol";

import {Owned} from "@solmate/auth/Owned.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

contract AtomicSolver is IAtomicSolver, Owned, ERC721Holder {
    using Address for address;
    using SafeTransferLib for ERC20;

    constructor(address _owner, address _vault) Owned(_owner) {
        _balancerVault = _vault;
    }

    bool private _solving;
    address private immutable _balancerVault;
    mapping(address => bool) private approvedToCallFinishSolve;

    function updateMapping(address who, bool state) external onlyOwner {
        approvedToCallFinishSolve[who] = state;
    }

    function finishSolve(bytes calldata runData, address initiator, ERC20, ERC20 want, uint256, uint256 assetsForWant)
        external
    {
        require(initiator == owner);
        require(approvedToCallFinishSolve[msg.sender]);
        (address[] memory targets, uint256[] memory values, bytes[] memory ammo) =
            abi.decode(runData, (address[], uint256[], bytes[]));
        _solving = true;
        for (uint256 i; i < ammo.length; ++i) {
            targets[i].functionCallWithValue(ammo[i], values[i]);
        }
        want.safeApprove(msg.sender, assetsForWant);
        _solving = false;
    }

    // fn to make multiple external calls
    function doStuff(address[] calldata targets, uint256[] calldata values, bytes[] calldata ammo)
        external
        payable
        onlyOwner
    {
        _solving = true;
        for (uint256 i; i < ammo.length; ++i) {
            targets[i].functionCallWithValue(ammo[i], values[i]);
        }
        _solving = false;
    }

    // fn to receive balancer flash loans
    function receiveFlashLoan(
        address[] calldata tokens,
        uint256[] calldata amounts,
        uint256[] calldata feeAmounts,
        bytes calldata userData
    ) external {
        require(msg.sender == _balancerVault);
        require(_solving);
        (address[] memory targets, uint256[] memory values, bytes[] memory ammo) =
            abi.decode(userData, (address[], uint256[], bytes[]));
        for (uint256 i; i < ammo.length; ++i) {
            targets[i].functionCallWithValue(ammo[i], values[i]);
        }

        for (uint256 i = 0; i < amounts.length; ++i) {
            ERC20(tokens[i]).safeTransfer(_balancerVault, (amounts[i] + feeAmounts[i]));
        }
    }

    function getEth(address payable receiver) external onlyOwner {
        receiver.transfer(address(this).balance);
    }

    receive() external payable {}
}
