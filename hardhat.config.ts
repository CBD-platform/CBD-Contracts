import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
require('dotenv').config()

const config: HardhatUserConfig = {
  solidity: {
    compilers:[
      {
        version:"0.8.0"
      },
      {
        version:"0.8.17"
      },
    ]
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.ETH_URL as string,
        blockNumber: 15436690
      },
    },
    goerli: {
      url: process.env.GOERLY_URL,
      accounts:[process.env.PRIVATE_KEY as string] 
  },
    sepolia: {
      url: process.env.SEPOLIA_URL,
      accounts:[process.env.PRIVATE_KEY as string] 
  },
  binance: {
    url: process.env.BINANCE_TESTNET_RPC,
    accounts:[process.env.PRIVATE_KEY as string] 
},
},
etherscan: {
  // Your API key for Etherscan
  // Obtain one at https://etherscan.io/
  apiKey: process.env.ETHERSCAN_KEY
  // apiKey: process.env.BSCSCAN_KEY
},
};

export default config;
