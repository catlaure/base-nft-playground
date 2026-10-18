# base-nft-playground

A dependency-free ERC-721 collection for [Base](https://base.org), with Foundry tests and a small metadata generator.

## Contracts (`src/`)

| File | Purpose |
| --- | --- |
| `ERC721Base.sol` | Minimal ERC-721 (EIP-721, metadata extension, ERC-165) with safe-transfer receiver checks |
| `PlaygroundNFT.sol` | Public-sale collection on top of it (see below) |
| `interfaces/` | `IERC165`, `IERC721`, `IERC721Metadata`, `IERC721Receiver`, `IERC2981` |
| `utils/Strings.sol` | `toString(uint256)` used to build token URIs |

### PlaygroundNFT

- **Sale:** capped supply, fixed mint price, per-wallet limit; the owner opens and closes the sale and can change price and limit. Exact payment is required.
- **Metadata:** `tokenURI(id)` is `baseURI + id + ".json"`; the owner sets `baseURI` (e.g. `ipfs://<cid>/`).
- **Royalties:** EIP-2981, 5% by default, owner-configurable up to a 10% cap.
- **Admin:** ownership transfer and `withdraw()` of mint proceeds. Holders (or approved addresses) can burn.

## Tests

Requires [Foundry](https://book.getfoundry.sh/getting-started/installation).

```sh
forge install foundry-rs/forge-std --no-git
forge build
forge test -vvv
```

Covered: ERC-721 ownership, approvals, transfers and burn; safe transfers against receiver contracts; the sale rules, admin controls and burn; `tokenURI`/`baseURI`; royalties (including a fuzz test on the cap); `Strings.toString`.

## Deploying to Base Sepolia

```sh
NFT_NAME="Base Playground" NFT_SYMBOL=PLAY MAX_SUPPLY=1000 MINT_PRICE=0 MAX_PER_WALLET=5 BASE_URI=ipfs://<cid>/ \
  forge script script/Deploy.s.sol --rpc-url base_sepolia --broadcast --private-key $PRIVATE_KEY
```

All variables are optional. Use a throwaway key with testnet funds only.

## Metadata generator (`tools/`)

Generates `1.json … N.json` with weighted random traits. Output is deterministic for a given `seed`. Requires Node 20+, no dependencies.

```sh
node tools/generate-metadata.mjs tools/example-config.json metadata
npm run test:tools
```

Edit `tools/example-config.json` (name, description, image base URI, count, seed, traits and weights), upload the images, upload the generated folder, then call `setBaseURI` on the contract.

## License

MIT
