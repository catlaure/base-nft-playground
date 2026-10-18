// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721Base} from "../../src/ERC721Base.sol";

/// @dev Exposes the internal mint/burn helpers of ERC721Base for testing.
contract ERC721Harness is ERC721Base {
    constructor() ERC721Base("Harness", "HAR") {}

    function mint(address to, uint256 tokenId) external {
        _mint(to, tokenId);
    }

    function safeMint(address to, uint256 tokenId) external {
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
        _burn(tokenId);
    }
}
