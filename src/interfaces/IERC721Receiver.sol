// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice Contracts must implement this to accept safe ERC-721 transfers.
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
