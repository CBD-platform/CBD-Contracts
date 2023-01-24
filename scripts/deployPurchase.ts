import { ethers, network } from "hardhat";
require("dotenv").config()
import "@nomiclabs/hardhat-ethers"
const hre = require("hardhat");


async function main() {
  // goerliCBD = 0x6e8eCf88F39E08e06764Ff26d67c1ed99f8ea1CE
  // goerliPurchase = 0x0700620130188a8F463f8d54139ED3f5F589Ad35
  const Purchase = await ethers.getContractFactory("Purchase");
  const purchase = await Purchase.deploy(
    process.env.GOERLI_CBD as string,
    process.env.GOERLI_USDC as string,
    `${20*10**18}`,
    process.env.GOERLI_USDC_ORACLE as string
  );

  await purchase.deployed();

  console.log(`Purchase contract deployed to ${purchase.address}`);

  if (network.name == "hardhat" || network.name == "localhost") return
  await purchase.deployTransaction.wait(21)
  console.log("Verifing...")
  await hre.run("verify:verify", {
    address: purchase.address,
    constructorArguments: [
        process.env.GOERLI_CBD as string,
        process.env.GOERLI_USDC as string,
        `${20*10**18}`,
        process.env.GOERLI_USDC_ORACLE as string
    ],
  })
  console.log("Contract verified successfully !")

}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
