// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Base} from "./ERC721Base.sol";
import {Strings} from "./utils/Strings.sol";

/// @title PlaygroundNFT
/// @notice Public-sale ERC-721 collection: capped supply, fixed mint price, per-wallet limit.
contract PlaygroundNFT is ERC721Base {
    address public owner;

    uint256 public immutable maxSupply;
    uint256 public mintPrice;
    uint256 public maxPerWallet;
    bool public saleOpen;

    /// @notice Prefix for token metadata, e.g. `ipfs://<cid>/`. tokenURI is `baseURI + id + ".json"`.
    string public baseURI;

    /// @notice Number of tokens minted so far. Token ids run from 1 to `totalMinted`.
    uint256 public totalMinted;
    mapping(address => uint256) public mintedBy;

    event SaleStateChanged(bool open);
    event MintPriceChanged(uint256 price);
    event MaxPerWalletChanged(uint256 limit);
    event BaseURIChanged(string baseURI);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    error NotOwner();
    error SaleClosed();
    error InvalidQuantity();
    error MaxSupplyReached();
    error WalletLimitReached();
    error WrongPayment(uint256 expected, uint256 sent);
    error WithdrawFailed();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(string memory _name, string memory _symbol, uint256 _maxSupply, uint256 _mintPrice, uint256 _maxPerWallet)
        ERC721Base(_name, _symbol)
    {
        owner = msg.sender;
        maxSupply = _maxSupply;
        mintPrice = _mintPrice;
        maxPerWallet = _maxPerWallet;
        emit OwnershipTransferred(address(0), msg.sender);
    }

    // ----------------------------------------------------------------- sale

    function mint(uint256 quantity) external payable {
        if (!saleOpen) revert SaleClosed();
        if (quantity == 0) revert InvalidQuantity();
        if (totalMinted + quantity > maxSupply) revert MaxSupplyReached();
        if (mintedBy[msg.sender] + quantity > maxPerWallet) revert WalletLimitReached();

        uint256 cost = mintPrice * quantity;
        if (msg.value != cost) revert WrongPayment(cost, msg.value);

        // Effects before interactions: _safeMint may call into the receiver.
        uint256 firstId = totalMinted + 1;
        totalMinted += quantity;
        mintedBy[msg.sender] += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            _safeMint(msg.sender, firstId + i);
        }
    }

    // ---------------------------------------------------------------- admin

    function setSaleOpen(bool open) external onlyOwner {
        saleOpen = open;
        emit SaleStateChanged(open);
    }

    function setMintPrice(uint256 price) external onlyOwner {
        mintPrice = price;
        emit MintPriceChanged(price);
    }

    function setMaxPerWallet(uint256 limit) external onlyOwner {
        maxPerWallet = limit;
        emit MaxPerWalletChanged(limit);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURIChanged(newBaseURI);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function withdraw() external onlyOwner {
        (bool ok,) = owner.call{value: address(this).balance}("");
        if (!ok) revert WithdrawFailed();
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (!_exists(tokenId)) revert NonexistentToken(tokenId);
        if (bytes(baseURI).length == 0) return "";
        return string.concat(baseURI, Strings.toString(tokenId), ".json");
    }

    /// @notice Burns a token. Callable by the owner of the token or an approved address.
    function burn(uint256 tokenId) external {
        address tokenOwner = ownerOf(tokenId);
        if (msg.sender != tokenOwner && msg.sender != _tokenApprovals[tokenId] && !_operatorApprovals[tokenOwner][msg.sender]) {
            revert NotOwnerNorApproved();
        }
        _burn(tokenId);
    }
}
