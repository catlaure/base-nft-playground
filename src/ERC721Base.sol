// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Metadata} from "./interfaces/IERC721Metadata.sol";
import {IERC721Receiver} from "./interfaces/IERC721Receiver.sol";

/// @title ERC721Base
/// @notice Minimal, dependency-free ERC-721 implementation (EIP-721 + metadata + ERC-165).
abstract contract ERC721Base is IERC721Metadata {
    string public override name;
    string public override symbol;

    mapping(uint256 => address) internal _owners;
    mapping(address => uint256) internal _balances;
    mapping(uint256 => address) internal _tokenApprovals;
    mapping(address => mapping(address => bool)) internal _operatorApprovals;

    error ZeroAddress();
    error NonexistentToken(uint256 tokenId);
    error AlreadyMinted(uint256 tokenId);
    error NotOwnerNorApproved();
    error WrongFrom();
    error InvalidReceiver(address receiver);

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    // ---------------------------------------------------------------- views

    function balanceOf(address owner) public view virtual override returns (uint256) {
        if (owner == address(0)) revert ZeroAddress();
        return _balances[owner];
    }

    function ownerOf(uint256 tokenId) public view virtual override returns (address) {
        address owner = _owners[tokenId];
        if (owner == address(0)) revert NonexistentToken(tokenId);
        return owner;
    }

    function getApproved(uint256 tokenId) public view virtual override returns (address) {
        if (_owners[tokenId] == address(0)) revert NonexistentToken(tokenId);
        return _tokenApprovals[tokenId];
    }

    function isApprovedForAll(address owner, address operator) public view virtual override returns (bool) {
        return _operatorApprovals[owner][operator];
    }

    function tokenURI(uint256 tokenId) public view virtual override returns (string memory) {
        if (_owners[tokenId] == address(0)) revert NonexistentToken(tokenId);
        return "";
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == 0x01ffc9a7 // ERC-165
            || interfaceId == 0x80ac58cd // ERC-721
            || interfaceId == 0x5b5e139f; // ERC-721 Metadata
    }

    // ------------------------------------------------------------ approvals

    function approve(address to, uint256 tokenId) public virtual override {
        address owner = ownerOf(tokenId);
        if (msg.sender != owner && !_operatorApprovals[owner][msg.sender]) revert NotOwnerNorApproved();
        _tokenApprovals[tokenId] = to;
        emit Approval(owner, to, tokenId);
    }

    function setApprovalForAll(address operator, bool approved) public virtual override {
        if (operator == address(0)) revert ZeroAddress();
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    // ------------------------------------------------------------ transfers

    function transferFrom(address from, address to, uint256 tokenId) public virtual override {
        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(address from, address to, uint256 tokenId) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
    }

    function safeTransferFrom(address from, address to, uint256 tokenId, bytes memory data)
        public
        virtual
        override
    {
        _transfer(from, to, tokenId);
        _checkOnERC721Received(from, to, tokenId, data);
    }

    // ------------------------------------------------------------ internals

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _owners[tokenId] != address(0);
    }

    function _transfer(address from, address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        address owner = ownerOf(tokenId);
        if (owner != from) revert WrongFrom();
        if (msg.sender != owner && msg.sender != _tokenApprovals[tokenId] && !_operatorApprovals[owner][msg.sender]) {
            revert NotOwnerNorApproved();
        }

        delete _tokenApprovals[tokenId];
        unchecked {
            _balances[from] -= 1;
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(from, to, tokenId);
    }

    function _mint(address to, uint256 tokenId) internal {
        if (to == address(0)) revert ZeroAddress();
        if (_owners[tokenId] != address(0)) revert AlreadyMinted(tokenId);

        unchecked {
            _balances[to] += 1;
        }
        _owners[tokenId] = to;
        emit Transfer(address(0), to, tokenId);
    }

    function _safeMint(address to, uint256 tokenId) internal {
        _mint(to, tokenId);
        _checkOnERC721Received(address(0), to, tokenId, "");
    }

    function _burn(uint256 tokenId) internal {
        address owner = ownerOf(tokenId);
        delete _tokenApprovals[tokenId];
        unchecked {
            _balances[owner] -= 1;
        }
        delete _owners[tokenId];
        emit Transfer(owner, address(0), tokenId);
    }

    function _checkOnERC721Received(address from, address to, uint256 tokenId, bytes memory data) private {
        if (to.code.length == 0) return;

        try IERC721Receiver(to).onERC721Received(msg.sender, from, tokenId, data) returns (bytes4 retval) {
            if (retval != IERC721Receiver.onERC721Received.selector) revert InvalidReceiver(to);
        } catch (bytes memory reason) {
            if (reason.length == 0) revert InvalidReceiver(to);
            assembly {
                revert(add(reason, 32), mload(reason))
            }
        }
    }
}
