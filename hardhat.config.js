require('dotenv').config();
require("@nomiclabs/hardhat-waffle");
require('hardhat-dependency-compiler');

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 module.exports = {
  solidity: {
    version: "0.8.3",
    settings: {
      optimizer: {
        enabled: true,
        runs: 10,
      },
    },
  },
  paths: {
    artifacts: './artifacts',
  },
  networks: {
    hardhat: {
      chainId: 1337
    },
    rinkeby: {
      url: process.env.ALCHEMY_RINKEBY_URL,
      accounts: [`0x${process.env.DEV_PRIVATE_KEY}`],
    }
  },
  dependencyCompiler: {
    paths: [
      '@openzeppelin/contracts/token/ERC20/IERC20.sol',
      '@openzeppelin/contracts/token/ERC721/IERC721.sol',
      '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol',
      '@openzeppelin/contracts/token/ERC1155/IERC1155.sol',
    ]
  }
};
