// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Owned} from "@solmate/auth/Owned.sol";

contract IncentiveDistributor is Owned {
    using SafeERC20 for IERC20;

    // merkleroot -> bool
    mapping(bytes32 => bool) public merkleAvailable;

    //merkleroot -> user address -> bool
    mapping(bytes32 => mapping(address => bool)) public claimed;

    event RegisteredMerkleTree(bytes32 rootHash);
    event UnRegisteredMerkleTree(bytes32 rootHash);
    event Claimed(bytes32 rootHash, address user, address token, uint256 balance);

    constructor(address _owner) Owned(_owner) {}

    function registerMerkleTree(bytes32 _rootHash) external onlyOwner {
        require(!merkleAvailable[_rootHash], "Already registered");

        merkleAvailable[_rootHash] = true;

        emit RegisteredMerkleTree(_rootHash);
    }

    function unregisterMerkleTree(bytes32 _rootHash) external onlyOwner {
        require(merkleAvailable[_rootHash], "Not registered");

        merkleAvailable[_rootHash] = false;

        emit UnRegisteredMerkleTree(_rootHash);
    }

    function claim(
        address _to,
        bytes32[] calldata _rootHashes,
        address[] calldata _tokens,
        uint256[] calldata _balances,
        bytes32[][] calldata _merkleProofs
    ) external {
        uint256 length = _rootHashes.length;
        require(_tokens.length == length, "Incorrect array length");
        require(_balances.length == length, "Incorrect array length");
        require(_merkleProofs.length == length, "Incorrect array length");

        for (uint256 i; i < length; ++i) {
            _claim(_to, _tokens[i], _balances[i], _rootHashes[i], _merkleProofs[i]);
            _pay(_to, _tokens[i], _balances[i]);
        }
    }

    function verifyClaim(
        address _to,
        address _token,
        uint256 _balance,
        bytes32 _rootHash,
        bytes32[] calldata _merkleProof
    ) external view returns (bool) {
        require(merkleAvailable[_rootHash] == true, "Not available merkle root");

        return _verifyClaim(_to, _token, _balance, _rootHash, _merkleProof);
    }

    function withdraw(address _to, address _token, uint256 _balance) external onlyOwner {
        uint256 tokenAmount = _balance;

        if (_balance == 0) {
            tokenAmount = IERC20(_token).balanceOf(address(this));
        }

        IERC20(_token).safeTransfer(_to, tokenAmount);
    }

    function _claim(address _to, address _token, uint256 _balance, bytes32 _rootHash, bytes32[] calldata _merkleProof)
        private
    {
        require(merkleAvailable[_rootHash] == true, "Not available merkle root");
        require(!claimed[_rootHash][_to], "It has already claimed");
        require(_verifyClaim(_to, _token, _balance, _rootHash, _merkleProof), "Incorrect merkle proof");

        claimed[_rootHash][_to] = true;

        emit Claimed(_rootHash, _to, _token, _balance);
    }

    function _verifyClaim(
        address _to,
        address _token,
        uint256 _balance,
        bytes32 _rootHash,
        bytes32[] calldata _merkleProof
    ) private pure returns (bool) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_to, _token, _balance))));

        return MerkleProof.verify(_merkleProof, _rootHash, leaf);
    }

    function _pay(address _to, address _token, uint256 _balance) private {
        require(_balance > 0, "No balance would be transferred");

        IERC20(_token).safeTransfer(_to, _balance);
    }
}
