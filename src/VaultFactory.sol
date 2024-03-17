// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {CREATE3} from "solmate/utils/CREATE3.sol";
import {Vault} from "./Vault.sol";

contract VaultFactory is Ownable, Pausable {
    /// @notice the number of vaults
    uint256 public vaultCount;

    /// @notice the mapping of vault number to vault contract
    mapping(uint256 => address) public vaults;

    /// @notice Emitted when a new NFT vault is deployed.
    event VaultCreated(address collection, uint256 tokenId, address vault, uint256 vaultCount);

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /// @notice the function to create and deploy a new vault
    /// @param _collection the ERC721 token address fo the NFT
    /// @param _tokenId the uint ID of the token
    /// @param _supply the total supply amount of fractions of the fractionalized NFT
    /// @param _name the desired name of the vault
    /// @param _symbol the desired sumbol of the vault
    /// @return address of the vault
    function createVault(
        address _collection,
        uint256 _tokenId,
        uint256 _supply,
        string memory _name,
        string memory _symbol
    ) public whenNotPaused onlyOwner returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(_collection, _tokenId, _supply, _msgSender(), _name, _symbol));

        Vault vault = Vault(
            CREATE3.deploy(
                salt, abi.encodePacked(type(Vault).creationCode, abi.encode(address(this), _name, _symbol)), 0
            )
        );

        assert(address(vault) == CREATE3.getDeployed(salt));

        IERC721(_collection).transferFrom(_msgSender(), address(vault), _tokenId);

        Vault(vault).fractionalize(_msgSender(), _collection, _tokenId, _supply);

        address vaultAddress = address(vault);

        ++vaultCount;
        vaults[vaultCount] = vaultAddress;

        emit VaultCreated(_collection, _tokenId, vaultAddress, vaultCount);

        return vaultAddress;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
