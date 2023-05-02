import { ethers, network } from "hardhat";
require("dotenv").config()
import "@nomiclabs/hardhat-ethers"
const hre = require("hardhat");


async function main() {
  
  // polygonCBD = 0xd2Ad443CfdD184A503c9d911CcF98d4387BC7cC2
  
  const CBDToken = await ethers.getContractFactory("CBDToken");
  const cbdToken = await CBDToken.deploy("CBD", "CBD");

  await cbdToken.deployed();

  console.log(`CBD token deployed to ${cbdToken.address}`);

  if (network.name == "hardhat" || network.name == "localhost") return
  await cbdToken.deployTransaction.wait(21)
  
  console.log("Verifing...")
  await hre.run("verify:verify", {
    address: cbdToken.address,
    // address: "0xB5f4fE9eaCB1287ff57f1eAe5488554935fA08c3",
    constructorArguments: [
      "CBD",
      "CBD"
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
