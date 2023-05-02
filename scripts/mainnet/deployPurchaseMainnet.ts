import { ethers, network } from "hardhat";
require("dotenv").config()
import "@nomiclabs/hardhat-ethers"
const hre = require("hardhat");


async function main() {
  // polygonCBD = 0xd2Ad443CfdD184A503c9d911CcF98d4387BC7cC2
  // polygonPurchase = 0xe786a2C55E12675818b2DD5a92E8d8f2F5A0bb42
  const Purchase = await ethers.getContractFactory("Purchase");
  const purchase = await Purchase.deploy(
    process.env.POLYGON_CBD as string,
    process.env.POLYGON_USDC as string,
    `${20*10**6}`,
    process.env.POLYGON_USDC_ORACLE as string,
    {gasLimit: 6000000}
  );

  await purchase.deployed();

  console.log(`Purchase contract deployed to ${purchase.address}`);
  return;
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
