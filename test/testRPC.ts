import { ethers } from "ethers";

console.log("HHH", process.env.GOERLY_ALCHEMY_URL);

const provider = new ethers.providers.JsonRpcProvider(process.env.GOERLY_ALCHEMY_URL);

provider.getBlockNumber().then(console.log)