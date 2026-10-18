// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Base} from "../src/ERC721Base.sol";
import {ERC721Harness} from "./mocks/ERC721Harness.sol";

contract ERC721BaseTest is Test {
    ERC721Harness nft;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");
    address carol = makeAddr("carol");

    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function setUp() public {
        nft = new ERC721Harness();
        nft.mint(alice, 1);
        nft.mint(alice, 2);
        nft.mint(bob, 3);
    }

    // ---------------------------------------------------------- views

    function test_Metadata() public view {
        assertEq(nft.name(), "Harness");
        assertEq(nft.symbol(), "HAR");
    }

    function test_BalancesAndOwners() public view {
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.balanceOf(bob), 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(3), bob);
    }

    function test_BalanceOfZeroAddressReverts() public {
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.balanceOf(address(0));
    }

    function test_OwnerOfNonexistentReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 99));
        nft.ownerOf(99);
    }

    function test_SupportsExpectedInterfaces() public view {
        assertTrue(nft.supportsInterface(0x01ffc9a7)); // ERC-165
        assertTrue(nft.supportsInterface(0x80ac58cd)); // ERC-721
        assertTrue(nft.supportsInterface(0x5b5e139f)); // ERC-721 Metadata
        assertFalse(nft.supportsInterface(0xffffffff));
        assertFalse(nft.supportsInterface(0x2a55205a)); // ERC-2981 is not part of the base
    }

    // ----------------------------------------------------------- mint

    function test_MintEmitsTransferFromZero() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), carol, 10);
        nft.mint(carol, 10);
        assertEq(nft.ownerOf(10), carol);
    }

    function test_MintDuplicateReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.AlreadyMinted.selector, 1));
        nft.mint(bob, 1);
    }

    function test_MintToZeroReverts() public {
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.mint(address(0), 10);
    }

    // ------------------------------------------------------ approvals

    function test_ApproveSetsApprovedAndEmits() public {
        vm.expectEmit(true, true, true, true);
        emit Approval(alice, bob, 1);
        vm.prank(alice);
        nft.approve(bob, 1);
        assertEq(nft.getApproved(1), bob);
    }

    function test_ApproveByNonOwnerReverts() public {
        vm.prank(bob);
        vm.expectRevert(ERC721Base.NotOwnerNorApproved.selector);
        nft.approve(bob, 1);
    }

    function test_OperatorCanApprove() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        vm.prank(bob);
        nft.approve(carol, 1);
        assertEq(nft.getApproved(1), carol);
    }

    function test_SetApprovalForAllEmitsAndToggles() public {
        vm.expectEmit(true, true, false, true);
        emit ApprovalForAll(alice, bob, true);
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);
        assertTrue(nft.isApprovedForAll(alice, bob));

        vm.prank(alice);
        nft.setApprovalForAll(bob, false);
        assertFalse(nft.isApprovedForAll(alice, bob));
    }

    function test_SetApprovalForAllZeroOperatorReverts() public {
        vm.prank(alice);
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.setApprovalForAll(address(0), true);
    }

    function test_GetApprovedNonexistentReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 99));
        nft.getApproved(99);
    }

    // ------------------------------------------------------ transfers

    function test_OwnerCanTransfer() public {
        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, carol, 1);
        vm.prank(alice);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(carol), 1);
    }

    function test_ApprovedCanTransferAndApprovalIsCleared() public {
        vm.prank(alice);
        nft.approve(bob, 1);

        vm.prank(bob);
        nft.transferFrom(alice, carol, 1);

        assertEq(nft.ownerOf(1), carol);
        assertEq(nft.getApproved(1), address(0));
    }

    function test_OperatorCanTransferAnyToken() public {
        vm.prank(alice);
        nft.setApprovalForAll(bob, true);

        vm.startPrank(bob);
        nft.transferFrom(alice, carol, 1);
        nft.transferFrom(alice, carol, 2);
        vm.stopPrank();

        assertEq(nft.balanceOf(carol), 2);
    }

    function test_StrangerCannotTransfer() public {
        vm.prank(carol);
        vm.expectRevert(ERC721Base.NotOwnerNorApproved.selector);
        nft.transferFrom(alice, carol, 1);
    }

    function test_ApprovalForOneTokenDoesNotCoverAnother() public {
        vm.prank(alice);
        nft.approve(bob, 1);
        vm.prank(bob);
        vm.expectRevert(ERC721Base.NotOwnerNorApproved.selector);
        nft.transferFrom(alice, carol, 2);
    }

    function test_TransferWithWrongFromReverts() public {
        vm.prank(alice);
        vm.expectRevert(ERC721Base.WrongFrom.selector);
        nft.transferFrom(bob, carol, 1);
    }

    function test_TransferToZeroReverts() public {
        vm.prank(alice);
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.transferFrom(alice, address(0), 1);
    }

    function test_TransferNonexistentReverts() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 99));
        nft.transferFrom(alice, carol, 99);
    }

    function test_SelfTransferKeepsBalance() public {
        vm.prank(alice);
        nft.transferFrom(alice, alice, 1);
        assertEq(nft.balanceOf(alice), 2);
        assertEq(nft.ownerOf(1), alice);
    }

    // ----------------------------------------------------------- burn

    function test_BurnRemovesTokenAndClearsApproval() public {
        vm.prank(alice);
        nft.approve(bob, 1);

        vm.expectEmit(true, true, true, true);
        emit Transfer(alice, address(0), 1);
        nft.burn(1);

        assertEq(nft.balanceOf(alice), 1);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 1));
        nft.ownerOf(1);
    }

    function test_BurnNonexistentReverts() public {
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 99));
        nft.burn(99);
    }

    // ----------------------------------------------------------- fuzz

    function testFuzz_TransferMovesExactlyOneToken(address to) public {
        vm.assume(to != address(0) && to != alice && to != bob);
        vm.prank(alice);
        nft.transferFrom(alice, to, 1);
        assertEq(nft.ownerOf(1), to);
        assertEq(nft.balanceOf(alice), 1);
        assertEq(nft.balanceOf(to), 1);
    }
}
