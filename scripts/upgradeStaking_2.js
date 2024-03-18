//this script should redploy the contract since its an upgradable contract
const { ethers, upgrades } = require("hardhat")

async function main() {
  const AEGStaking = await ethers.getContractFactory("AEGStaking_2")
  const aegStaking = await upgrades.upgradeProxy("0x937b057807a5eD4Dd2C79632934e0D87105CbB45", AEGStaking)
  console.log("AEGStaking upgraded at:", aegStaking.address)
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
