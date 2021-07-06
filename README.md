# Potluck Finance

## 🟢 Welcome

[Potluck](https://potluck.finance) is a protocol built on Ethereum enabling a multiplayer experience for NFTs. This is achieved by allowing NFTs to be bought and owned by multiple parties.

## 📜 Documentation
[Docs here](https://docs.potluck.finance) (shoutout to [GitBook](https://gitbook.com) for the complimentary premium membership for open source projects)

## ⚠️ Caveats

This contract has not been tested on mainnet and has been developed with a local fork of mainnet and Rinkeby. **Use at your own risk.**

## 🛠 Building and deployment

You may want to fork mainnet (or a test chain) to have an environment populated with NFTs. Read more [here](https://hardhat.org/guides/mainnet-forking.html).

```bash
# Install dependencies
npm install

# Compile contracts
npx hardhat compile

# Deploy
npx hardhat run scripts/deploy.js --network localhost # (fill in the deploy script to your liking)
```
