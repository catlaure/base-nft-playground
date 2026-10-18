// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {PlaygroundNFT} from "../src/PlaygroundNFT.sol";

/// Optional env vars: NFT_NAME, NFT_SYMBOL, MAX_SUPPLY, MINT_PRICE (wei), MAX_PER_WALLET, BASE_URI
///   forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
contract Deploy is Script {
    function run() external returns (PlaygroundNFT nft) {
        string memory name = vm.envOr("NFT_NAME", string("Base Playground"));
        string memory symbol = vm.envOr("NFT_SYMBOL", string("PLAY"));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(1_000));
        uint256 mintPrice = vm.envOr("MINT_PRICE", uint256(0));
        uint256 maxPerWallet = vm.envOr("MAX_PER_WALLET", uint256(5));
        string memory baseURI = vm.envOr("BASE_URI", string(""));

        vm.startBroadcast();
        nft = new PlaygroundNFT(name, symbol, maxSupply, mintPrice, maxPerWallet);
        if (bytes(baseURI).length > 0) nft.setBaseURI(baseURI);
        vm.stopBroadcast();

        console.log("PlaygroundNFT deployed at:", address(nft));
    }
}
