// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC6065} from "./interfaces/IERC6065.sol";

/**
 * Custom errors for the contract
 */
error Unauthorized(address caller);
error TokenDoesNotExist(uint256 tokenId);
error AssetIsForeclosed(uint256 tokenId);

contract Estate is IERC6065, Ownable, ERC721URIStorage, ReentrancyGuard {
    uint256 private _tokenIdCounter = 1;
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    struct AssetDetails {
        string legalDescription;
        string assetAddress;
        string geoJson;
        string parcelId;
        string legalOwner;
        bytes32 operatingAgreementHash;
        address debtToken;
        int256 debtAmt;
        bool foreclosed;
        address manager;
    }

    mapping(uint256 => AssetDetails) private _assets;

    event AssetMinted(uint256 indexed itemId, address indexed to, string uri);

    constructor(string memory _name, string memory _symbol, address _initialOwner)
        ERC721(_name, _symbol)
        Ownable(_initialOwner)
    {}

    function supportsInterface(bytes4 interfaceId) public view override(ERC721URIStorage, IERC165) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    // Function to create a new RWA NFT

    function mint(address to, string memory uri, AssetDetails memory assetDetails) public onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIdCounter;
        ++_tokenIdCounter;

        _mint(to, newItemId);
        _setTokenURI(newItemId, uri);
        _assets[newItemId] = assetDetails;

        emit AssetMinted(newItemId, to, uri); // Consider adding this event for better tracking
        return newItemId;
    }
    // Implementing IERC6065 functions

    function legalDescriptionOf(uint256 _id) external view override returns (string memory) {
        return _assets[_id].legalDescription;
    }

    function addressOf(uint256 _id) external view override returns (string memory) {
        return _assets[_id].assetAddress;
    }

    function geoJsonOf(uint256 _id) external view override returns (string memory) {
        return _assets[_id].geoJson;
    }

    function parcelIdOf(uint256 _id) external view override returns (string memory) {
        return _assets[_id].parcelId;
    }

    function legalOwnerOf(uint256 _id) external view override returns (string memory) {
        return _assets[_id].legalOwner;
    }

    function operatingAgreementHashOf(uint256 _id) external view override returns (bytes32) {
        return _assets[_id].operatingAgreementHash;
    }

    function debtOf(uint256 _id) external view override returns (address, int256, bool) {
        return (_assets[_id].debtToken, _assets[_id].debtAmt, _assets[_id].foreclosed);
    }

    function managerOf(uint256 _id) external view override returns (address) {
        return _assets[_id].manager;
    }

    // Function to foreclose an asset
    function foreclose(uint256 tokenId) public onlyOwner {
        if (ownerOf(tokenId) == address(0)) revert TokenDoesNotExist(tokenId);

        _assets[tokenId].foreclosed = true;
        emit Foreclosed(tokenId);
    }

    function burn(uint256 tokenId) public onlyOwner {
        _burn(tokenId);
    }
}
