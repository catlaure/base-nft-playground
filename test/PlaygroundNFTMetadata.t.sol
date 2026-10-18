// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC721Base} from "../src/ERC721Base.sol";
import {PlaygroundNFT} from "../src/PlaygroundNFT.sol";

contract PlaygroundNFTMetadataTest is Test {
    PlaygroundNFT nft;
    address alice = makeAddr("alice");

    uint256 constant PRICE = 0.01 ether;

    event BaseURIChanged(string baseURI);

    function setUp() public {
        nft = new PlaygroundNFT("Playground", "PLAY", 10, PRICE, 5);
        nft.setSaleOpen(true);
        vm.deal(alice, 10 ether);
        vm.prank(alice);
        nft.mint{value: PRICE * 3}(3);
    }

    function test_TokenUriIsEmptyUntilBaseUriIsSet() public view {
        assertEq(nft.tokenURI(1), "");
    }

    function test_TokenUriConcatenatesBaseIdAndExtension() public {
        nft.setBaseURI("ipfs://bafyexample/");
        assertEq(nft.tokenURI(1), "ipfs://bafyexample/1.json");
        assertEq(nft.tokenURI(3), "ipfs://bafyexample/3.json");
    }

    function test_TokenUriWorksForMultiDigitIds() public {
        PlaygroundNFT big = new PlaygroundNFT("Big", "BIG", 100, 0, 100);
        big.setSaleOpen(true);
        vm.prank(alice);
        big.mint(12);
        big.setBaseURI("https://example.com/meta/");
        assertEq(big.tokenURI(12), "https://example.com/meta/12.json");
    }

    function test_TokenUriRevertsForUnmintedToken() public {
        nft.setBaseURI("ipfs://bafyexample/");
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 4));
        nft.tokenURI(4);
    }

    function test_TokenUriRevertsForBurnedToken() public {
        nft.setBaseURI("ipfs://bafyexample/");
        vm.prank(alice);
        nft.burn(2);
        vm.expectRevert(abi.encodeWithSelector(ERC721Base.NonexistentToken.selector, 2));
        nft.tokenURI(2);
    }

    function test_SetBaseUriEmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit BaseURIChanged("ipfs://new/");
        nft.setBaseURI("ipfs://new/");
        assertEq(nft.baseURI(), "ipfs://new/");
    }

    function test_SetBaseUriIsOwnerOnly() public {
        vm.prank(alice);
        vm.expectRevert(PlaygroundNFT.NotOwner.selector);
        nft.setBaseURI("ipfs://evil/");
    }

    function test_BaseUriCanBeChanged() public {
        nft.setBaseURI("ipfs://old/");
        nft.setBaseURI("ipfs://new/");
        assertEq(nft.tokenURI(1), "ipfs://new/1.json");
    }
}
