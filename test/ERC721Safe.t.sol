// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Base} from "../src/ERC721Base.sol";
import {ERC721Harness} from "./mocks/ERC721Harness.sol";
import {GoodReceiver, WrongSelectorReceiver, RevertingReceiver, NonReceiver} from "./mocks/Receivers.sol";

contract ERC721SafeTest is Test {
    ERC721Harness nft;
    GoodReceiver good;
    address alice = makeAddr("alice");

    function setUp() public {
        nft = new ERC721Harness();
        good = new GoodReceiver();
        nft.mint(alice, 1);
    }

    function test_SafeTransferToEOA() public {
        address bob = makeAddr("bob");
        vm.prank(alice);
        nft.safeTransferFrom(alice, bob, 1);
        assertEq(nft.ownerOf(1), bob);
    }

    function test_SafeTransferCallsReceiverWithContext() public {
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(good), 1, hex"1234");

        assertEq(nft.ownerOf(1), address(good));
        assertEq(good.lastOperator(), alice);
        assertEq(good.lastFrom(), alice);
        assertEq(good.lastTokenId(), 1);
        assertEq(good.lastData(), hex"1234");
    }

    function test_SafeTransferWithoutDataPassesEmptyBytes() public {
        vm.prank(alice);
        nft.safeTransferFrom(alice, address(good), 1);
        assertEq(good.lastData().length, 0);
    }

    function test_SafeTransferToWrongSelectorReverts() public {
        address bad = address(new WrongSelectorReceiver());
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.InvalidReceiver.selector, bad));
        nft.safeTransferFrom(alice, bad, 1);
        assertEq(nft.ownerOf(1), alice);
    }

    function test_SafeTransferToNonReceiverReverts() public {
        address plain = address(new NonReceiver());
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.InvalidReceiver.selector, plain));
        nft.safeTransferFrom(alice, plain, 1);
    }

    function test_SafeTransferBubblesReceiverRevert() public {
        address reverting = address(new RevertingReceiver());
        vm.prank(alice);
        vm.expectRevert(RevertingReceiver.Nope.selector);
        nft.safeTransferFrom(alice, reverting, 1);
    }

    function test_SafeMintToReceiver() public {
        nft.safeMint(address(good), 2);
        assertEq(nft.ownerOf(2), address(good));
        assertEq(good.lastFrom(), address(0));
        assertEq(good.lastTokenId(), 2);
    }

    function test_SafeMintToNonReceiverReverts() public {
        address plain = address(new NonReceiver());
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.InvalidReceiver.selector, plain));
        nft.safeMint(plain, 2);
    }

    function test_PlainTransferFromSkipsReceiverCheck() public {
        address plain = address(new NonReceiver());
        vm.prank(alice);
        nft.transferFrom(alice, plain, 1);
        assertEq(nft.ownerOf(1), plain);
    }
}
