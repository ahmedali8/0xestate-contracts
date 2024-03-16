// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/**
 * @title IERC6065
 * @dev Interface for Real World Assets (RWA) NFTs, extending the IERC721 interface.
 * This interface provides methods to access immutable data of the NFT, manage debt associated with the RWA,
 * and track the foreclosure status of the asset.
 */
interface IERC6065 is IERC721 {
    /**
     * @dev This event MUST be emitted if the asset is foreclosed.
     * @param id The NFT identifier that was foreclosed.
     */
    event Foreclosed(uint256 indexed id);

    // Immutable property details
    function legalDescriptionOf(uint256 _id) external view returns (string memory);
    function addressOf(uint256 _id) external view returns (string memory);
    function geoJsonOf(uint256 _id) external view returns (string memory);
    function parcelIdOf(uint256 _id) external view returns (string memory);
    function legalOwnerOf(uint256 _id) external view returns (string memory);
    function operatingAgreementHashOf(uint256 _id) external view returns (bytes32);

    /**
     * @dev Returns the debt details associated with the NFT, including the denomination token,
     * the amount (negative value represents credit), and foreclosure status.
     * @param _id The NFT identifier.
     * @return debtToken The address of the token in which the debt is denominated.
     * @return debtAmt The amount of debt associated with the NFT (negative values represent credit).
     * @return foreclosed Indicates if the asset backing the NFT has been foreclosed.
     */
    function debtOf(uint256 _id) external view returns (address debtToken, int256 debtAmt, bool foreclosed);

    /**
     * @dev Returns the manager of the NFT, who may have additional rights to the NFT or associated RWA, either on-chain or off-chain.
     * @param _id The NFT identifier.
     * @return The address of the manager.
     */
    function managerOf(uint256 _id) external view returns (address);
}
