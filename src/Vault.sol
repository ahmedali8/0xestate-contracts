// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Token} from "./abstract/Token.sol";
import {ERC721Holder} from "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";

contract Vault is Ownable, ERC721Holder, Token {
    /// @notice The ERC721 token address of the fractional NFT.
    address public collection;

    /// @notice The ERC721 token ID of the fractional NFT.
    uint256 public tokenId;

    /// @notice A boolean to indicate if the vault has closed.
    bool public vaultClosed;

    enum State {
        inactive,
        fractionalized,
        redeemed
    }

    State public state;

    /// @notice Emitted when an NFT is transferred to the token vault NFT contract.
    /// @param sender The address that sent the NFT.
    event DepositedERC721(address indexed sender);

    /// @notice Emitted when a user successfully fractionalizes an NFT and receives the total supply of the newly created ERC20 token.
    /// @param collection The address of the newly fractionalized NFT.
    /// @param token The contract address of the newly created ERC20 token.
    event Fractionalized(address indexed collection, address indexed token);

    /// @notice Emitted when a user successfully redeems an NFT in exchange for the total ERC20 supply.
    /// @param sender The address that redeemed the NFT (i.e., the address that called redeem()).
    /// @param collection The address of fractionalized NFT.
    /// @param tokenId The token Id of fractionalized NFT.
    event Redeemed(address indexed sender, address indexed collection, uint256 indexed tokenId);

    /// @notice Vault's constructor
    /// @param _name The desired name of the vault
    /// @param _symbol The desired symbol of the vault
    constructor(address _initialOwner, string memory _name, string memory _symbol)
        Ownable(_initialOwner)
        Token(_name, _symbol)
    {
        state = State.inactive;
    }

    /// @notice Create a fractionalized NFT: Lock the NFT in the contract; create a new ERC20 token, as specified;
    ///         and transfer the total supply of the token to the curator.
    /// @param _to The address of the curator/NFT owner.
    /// @param _collection The address of the NFT that is to be fractionalized.
    /// @param _tokenId The token ID of the NFT that is to be fractionalized.
    /// @param _supply The count of fractions of the fractionalized NFT - the total supply amount of vault ERC20 tokens.
    /// @dev Note the NFT must be approved for transfer by the owner of NFT token ID.
    function fractionalize(address _to, address _collection, uint256 _tokenId, uint256 _supply) external onlyOwner {
        require(state == State.inactive, "State should be inactive");
        collection = _collection;
        tokenId = _tokenId;
        state = State.fractionalized;
        _mint(_to, _supply);

        emit Fractionalized(collection, address(this));
    }

    /// @notice A holder of the entire ERC20 supply can call redeem in order to receive the underlying NFT from the contract.
    ///         The function burns all shares and transfers the vault NFT to the user.
    /// @dev Note, the ERC20 must be approved for transfer by the TokenVault contract before calling redeem().
    function redeem() external {
        uint256 redeemerBalance = IERC20(address(this)).balanceOf(_msgSender());
        require(redeemerBalance == IERC20(address(this)).totalSupply(), "Redeemer does not hold the entire supply");
        state = State.redeemed;
        _burn(_msgSender(), totalSupply());
        IERC721(collection).safeTransferFrom(address(this), _msgSender(), tokenId);

        emit Redeemed(_msgSender(), collection, tokenId);
    }
}
