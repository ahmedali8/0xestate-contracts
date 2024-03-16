// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IWorldID} from "../interfaces/IWorldID.sol";
import {ByteHasher} from "./ByteHasher.sol";
import {WorldIDMock} from "../mock/WorldIDMock.sol";

abstract contract WorldIDVerify {
    using ByteHasher for bytes;

    IWorldID internal immutable worldId;
    uint256 internal immutable externalNullifier;
    uint256 internal immutable groupId = 1;
    mapping(uint256 => bool) internal nullifierHashes;

    /// @notice Thrown when attempting to reuse a nullifier
    error InvalidNullifier();

    constructor(
        string memory _appId, // app_staging_482e634f656d2dfd3243bf8d49c4ab7d
        string memory _actionId // user-verification
    ) {
        // Initialize World ID verification
        // world id router
        // worldId = IWorldID(0x42FF98C4E85212a5D31358ACbFe76a621b50fC02);
        worldId = new WorldIDMock();
        externalNullifier = abi.encodePacked(abi.encodePacked(_appId).hashToField(), _actionId).hashToField();
    }

    // Function to verify World ID proof and execute logic
    function verifyWID(address _signal, uint256 _root, uint256 _nullifierHash, uint256[8] memory _proof)
        internal
        view
    {
        // Verify User has a valid World ID
        worldId.verifyProof(
            _root,
            groupId, // set to "1" in the constructor
            abi.encodePacked(_signal).hashToField(),
            _nullifierHash,
            externalNullifier,
            _proof
        );
    }
}
