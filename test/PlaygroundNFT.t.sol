// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Base} from "../src/ERC721Base.sol";
import {PlaygroundNFT} from "../src/PlaygroundNFT.sol";
import {GoodReceiver, NonReceiver} from "./mocks/Receivers.sol";

contract PlaygroundNFTTest is Test {
    PlaygroundNFT nft;
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant MAX_SUPPLY = 10;
    uint256 constant PRICE = 0.01 ether;
    uint256 constant PER_WALLET = 3;

    event SaleStateChanged(bool open);
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);

    receive() external payable {}

    function setUp() public {
        nft = new PlaygroundNFT("Playground", "PLAY", MAX_SUPPLY, PRICE, PER_WALLET);
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
    }

    function _openSale() internal {
        nft.setSaleOpen(true);
    }

    // ------------------------------------------------------------ config

    function test_InitialState() public view {
        assertEq(nft.owner(), address(this));
        assertEq(nft.maxSupply(), MAX_SUPPLY);
        assertEq(nft.mintPrice(), PRICE);
        assertEq(nft.maxPerWallet(), PER_WALLET);
        assertFalse(nft.saleOpen());
        assertEq(nft.totalMinted(), 0);
    }

    // -------------------------------------------------------------- mint

    function test_MintRevertsWhileSaleClosed() public {
        vm.prank(alice);
        vm.expectRevert(PlaygroundNFT.SaleClosed.selector);
        nft.mint{value: PRICE}(1);
    }

    function test_MintSingleToken() public {
        _openSale();
        vm.expectEmit(true, true, true, true);
        emit Transfer(address(0), alice, 1);
        vm.prank(alice);
        nft.mint{value: PRICE}(1);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.mintedBy(alice), 1);
        assertEq(address(nft).balance, PRICE);
    }

    function test_MintBatchAssignsSequentialIds() public {
        _openSale();
        vm.prank(alice);
        nft.mint{value: PRICE * 3}(3);

        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.ownerOf(2), alice);
        assertEq(nft.ownerOf(3), alice);
        assertEq(nft.balanceOf(alice), 3);

        vm.prank(bob);
        nft.mint{value: PRICE}(1);
        assertEq(nft.ownerOf(4), bob);
    }

    function test_MintZeroQuantityReverts() public {
        _openSale();
        vm.prank(alice);
        vm.expectRevert(PlaygroundNFT.InvalidQuantity.selector);
        nft.mint(0);
    }

    function test_MintWithWrongPaymentReverts() public {
        _openSale();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PlaygroundNFT.WrongPayment.selector, PRICE * 2, PRICE));
        nft.mint{value: PRICE}(2);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PlaygroundNFT.WrongPayment.selector, PRICE, PRICE + 1));
        nft.mint{value: PRICE + 1}(1);
    }

    function test_WalletLimitIsEnforcedAcrossTransactions() public {
        _openSale();
        vm.startPrank(alice);
        nft.mint{value: PRICE * 2}(2);
        nft.mint{value: PRICE}(1);
        vm.expectRevert(PlaygroundNFT.WalletLimitReached.selector);
        nft.mint{value: PRICE}(1);
        vm.stopPrank();
    }

    function test_WalletLimitCountsMintsNotBalance() public {
        _openSale();
        vm.startPrank(alice);
        nft.mint{value: PRICE * 3}(3);
        nft.transferFrom(alice, bob, 1);
        vm.expectRevert(PlaygroundNFT.WalletLimitReached.selector);
        nft.mint{value: PRICE}(1);
        vm.stopPrank();
    }

    function test_MaxSupplyIsEnforced() public {
        _openSale();
        nft.setMaxPerWallet(100);
        vm.prank(alice);
        nft.mint{value: PRICE * 10}(10);

        vm.prank(bob);
        vm.expectRevert(PlaygroundNFT.MaxSupplyReached.selector);
        nft.mint{value: PRICE}(1);
    }

    function test_BatchThatWouldExceedSupplyReverts() public {
        _openSale();
        nft.setMaxPerWallet(100);
        vm.prank(alice);
        nft.mint{value: PRICE * 8}(8);

        vm.prank(bob);
        vm.expectRevert(PlaygroundNFT.MaxSupplyReached.selector);
        nft.mint{value: PRICE * 3}(3);
        assertEq(nft.totalMinted(), 8);
    }

    function test_MintToContractWithoutReceiverReverts() public {
        _openSale();
        address plain = address(new NonReceiver());
        vm.deal(plain, 1 ether);
        vm.prank(plain);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.InvalidReceiver.selector, plain));
        nft.mint{value: PRICE}(1);
    }

    function test_MintToReceiverContractWorks() public {
        _openSale();
        GoodReceiver receiver = new GoodReceiver();
        vm.deal(address(receiver), 1 ether);
        vm.prank(address(receiver));
        nft.mint{value: PRICE}(1);
        assertEq(nft.ownerOf(1), address(receiver));
    }

    // ------------------------------------------------------------- admin

    function test_OwnerTogglesSale() public {
        vm.expectEmit(false, false, false, true);
        emit SaleStateChanged(true);
        nft.setSaleOpen(true);
        assertTrue(nft.saleOpen());

        nft.setSaleOpen(false);
        assertFalse(nft.saleOpen());
    }

    function test_NonOwnerCannotUseAdminFunctions() public {
        vm.startPrank(alice);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setSaleOpen(true);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setMintPrice(1);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setMaxPerWallet(1);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.withdraw();
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.transferOwnership(alice);
        vm.stopPrank();
    }

    function test_PriceChangeAppliesToNextMint() public {
        _openSale();
        nft.setMintPrice(0.02 ether);
        vm.prank(alice);
        nft.mint{value: 0.02 ether}(1);
        assertEq(address(nft).balance, 0.02 ether);
    }

    function test_WithdrawSendsEverythingToOwner() public {
        _openSale();
        vm.prank(alice);
        nft.mint{value: PRICE * 2}(2);

        uint256 before = address(this).balance;
        nft.withdraw();
        assertEq(address(this).balance, before + PRICE * 2);
        assertEq(address(nft).balance, 0);
    }

    function test_TransferOwnershipMovesAdminRights() public {
        nft.transferOwnership(alice);
        assertEq(nft.owner(), alice);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setSaleOpen(true);
    }

    function test_TransferOwnershipToZeroReverts() public {
        vm.expectRevert(ERC721Base.ZeroAddress.selector);
        nft.transferOwnership(address(0));
    }

    // -------------------------------------------------------------- burn

    function test_HolderCanBurn() public {
        _openSale();
        vm.startPrank(alice);
        nft.mint{value: PRICE}(1);
        nft.burn(1);
        vm.stopPrank();

        assertEq(nft.balanceOf(alice), 0);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 1));
        nft.ownerOf(1);
    }

    function test_BurnDoesNotFreeUpSupplyOrWalletAllowance() public {
        _openSale();
        vm.startPrank(alice);
        nft.mint{value: PRICE}(1);
        nft.burn(1);
        vm.stopPrank();
        assertEq(nft.totalMinted(), 1);
        assertEq(nft.mintedBy(alice), 1);
    }

    function test_StrangerCannotBurn() public {
        _openSale();
        vm.prank(alice);
        nft.mint{value: PRICE}(1);

        vm.prank(bob);
        vm.expectRevert(ERC721Base.NotOwnerNorApproved.selector);
        nft.burn(1);
    }

    function test_ApprovedAddressCanBurn() public {
        _openSale();
        vm.startPrank(alice);
        nft.mint{value: PRICE}(1);
        nft.approve(bob, 1);
        vm.stopPrank();

        vm.prank(bob);
        nft.burn(1);
        assertEq(nft.balanceOf(alice), 0);
    }

    // -------------------------------------------------------------- fuzz

    function testFuzz_PaymentMustMatchExactly(uint256 sent) public {
        _openSale();
        vm.assume(sent != PRICE && sent <= 10 ether);
        vm.deal(alice, sent);
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(PlaygroundNFT.WrongPayment.selector, PRICE, sent));
        nft.mint{value: sent}(1);
    }
}
