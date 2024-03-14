require("@nomicfoundation/hardhat-toolbox")
require("@openzeppelin/hardhat-upgrades")
require("dotenv").config()

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.20",
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {},
    local: {
      url: "http://127.0.0.1:8545",
    },
    mumbai: {
      url: process.env.ALCHEMY_URL_MATIC_MUMBAI,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 80001,
      gasPrice: 8000000000,
    },
    polygon: {
      url: process.env.ALCHEMY_URL_MATIC,
      accounts: [process.env.PRIVATE_KEY],
      chainId: 137,
      gasPrice: 8000000000,
    },
  },
  etherscan: {
    apiKey: process.env.POLYGONSCAN_API_KEY,
  },
}
