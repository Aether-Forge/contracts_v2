//simple script to deploy the upgradable contract ZealyClaim

const { ethers, upgrades, network } = require("hardhat")

// ADMIN=0xdf8b4c520ffe197c5343c6f5aec59570151ef9a492f2c624fd45ddde6135ec42

async function main() {
  let token, tokenAddress, NFTAddress, isLocal
  const [owner, addr1, addr2] = await ethers.getSigners()
  console.log("Deploying ZealyClaim...", network.name)

  if (network.name === "polygon") {
    tokenAddress = "0xE3f2b1B2229C0333Ad17D03F179b87500E7C5e01"
    token = await ethers.getContractAt("TestToken", tokenAddress)
    NFTAddress = "0xA271d8A51170884bFCE12c2Bbc5c7B4047d9f725"
    console.log("Deploying on polygon NOT ALLOWED YET")
    return
  } else if (network.name === "mumbai") {
    tokenAddress = "0x6866E9BDaF921050302680537DeFe9E17352F780"
    token = await ethers.getContractAt("TestToken", tokenAddress)
    NFTAddress = "0x930574f4d25f7C67aB021384727D81ab0d8baC17"
  } else {
    const TestToken = await ethers.getContractFactory("TestToken")
    token = await TestToken.deploy()
    await token.waitForDeployment()

    tokenAddress = await token.getAddress()
    NFTAddress = tokenAddress //TODO: DEPLOY TEST NFT ONLY ON LOCAL NETWORKs
    isLocal = true
  }

  console.log("tokenAddress", tokenAddress)
  console.log("NFTAddress", NFTAddress)

  const ZealyClaim = await ethers.getContractFactory("ZealyClaim")
  const zealyClaim = await upgrades.deployProxy(ZealyClaim, [tokenAddress, NFTAddress], { initializer: "initialize" })
  await zealyClaim.waitForDeployment()
  const zealyClaimAddress = await zealyClaim.getAddress()

  console.log("zealyClaim deployed to: ", zealyClaimAddress)

  if (network.name !== "polygon") {
    await zealyClaim.setAllocation(owner.address, ethers.parseEther("100"), 5)

    const allocation = await zealyClaim.allocationOf(owner.address)
    console.log("owner allocation", allocation)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })

// then need to set MINTER role in cards contract to zealyClaimAddress
// and fill the claim contract with aeg
