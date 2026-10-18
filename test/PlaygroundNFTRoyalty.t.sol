// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {PlaygroundNFT} from "../src/PlaygroundNFT.sol";
import {ERC721Base} from "../src/ERC721Base.sol";

contract PlaygroundNFTRoyaltyTest is Test {
    PlaygroundNFT nft;
    address alice = makeAddr("alice");
    address treasury = makeAddr("treasury");

    event RoyaltyChanged(address indexed receiver, uint96 bps);

    function setUp() public {
        nft = new PlaygroundNFT("Playground", "PLAY", 10, 0.01 ether, 5);
    }

    function test_DefaultRoyaltyIsFivePercentToDeployer() public view {
        assertEq(nft.royaltyReceiver(), address(this));
        assertEq(uint256(nft.royaltyBps()), 500);

        (address receiver, uint256 amount) = nft.royaltyInfo(1, 1 ether);
        assertEq(receiver, address(this));
        assertEq(amount, 0.05 ether);
    }

    function test_OwnerCanSetRoyalty() public {
        vm.expectEmit(true, false, false, true);
        emit RoyaltyChanged(treasury, 250);
        nft.setRoyalty(treasury, 250);

        (address receiver, uint256 amount) = nft.royaltyInfo(7, 2 ether);
        assertEq(receiver, treasury);
        assertEq(amount, 0.05 ether); // 2.5% of 2 ETH
    }

    function test_RoyaltyCanBeZero() public {
        nft.setRoyalty(treasury, 0);
        (, uint256 amount) = nft.royaltyInfo(1, 1 ether);
        assertEq(amount, 0);
    }

    function test_RoyaltyAtCapIsAllowed() public {
        nft.setRoyalty(treasury, nft.MAX_ROYALTY_BPS());
        (, uint256 amount) = nft.royaltyInfo(1, 1 ether);
        assertEq(amount, 0.1 ether);
    }

    function test_RoyaltyAboveCapReverts() public {
        vm.expectRevert(abi.encodeWithSelector(PlaygroundNFT.RoyaltyTooHigh.selector, uint96(1_001)));
        nft.setRoyalty(treasury, 1_001);
    }

    function test_ZeroReceiverReverts() public {
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.setRoyalty(address(0), 500);
    }

    function test_SetRoyaltyIsOwnerOnly() public {
        vm.prank(alice);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setRoyalty(alice, 1_000);
    }

    function test_SupportsExpectedInterfaces() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(nft.supportsInterface(0x5b5e139f)); // ERC-721 Metadata
        assertTrue(nft.supportsInterface(0x2a55205a)); // ERC-2981
        assertFalse(nft.supportsInterface(0xffffffff));
    }

    function testFuzz_RoyaltyNeverExceedsTenPercent(uint96 bps, uint128 salePrice) public {
        bps = uint96(bound(bps, 0, 1_000));
        nft.setRoyalty(treasury, bps);
        (, uint256 amount) = nft.royaltyInfo(1, salePrice);
        assertLe(amount, uint256(salePrice) / 10);
    }
}
