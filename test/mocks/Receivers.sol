// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC721Receiver} from "../../src/interfaces/IERC721Receiver.sol";

/// @dev Accepts every token and remembers the last call.
contract GoodReceiver is IERC721Receiver {
    address public lastOperator;
    address public lastFrom;
    uint256 public lastTokenId;
    bytes public lastData;

    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4)
    {
        lastOperator = operator;
        lastFrom = from;
        lastTokenId = tokenId;
        lastData = data;
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev Implements the hook but returns the wrong selector.
contract WrongSelectorReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return 0xdeadbeef;
    }
}

/// @dev Reverts with a custom reason.
contract RevertingReceiver is IERC721Receiver {
    error Nope();

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        revert Nope();
    }
}

/// @dev A contract with no ERC-721 receiver hook at all.
contract NonReceiver {}
