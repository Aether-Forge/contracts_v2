const { ethers, upgrades, network, run } = require("hardhat")
const fs = require("fs")
const { createPools } = require("../utils/pools")

async function main() {
  let tokenAddress, NFTAddress
  const [owner, addr1, addr2] = await ethers.getSigners()
  console.log("Deploying AEGStaking...", network.name)

  if (network.name === "polygon") {
    NFTAddress = "0x0059598a11e8CF4ce0CDBF452FC32Cec4AE4b87D"
    tokenAddress = "0xE3f2b1B2229C0333Ad17D03F179b87500E7C5e01"

    console.log("Deploying on polygon NOT ALLOWED YET")
    return
  } else if (network.name === "mumbai") {
    tokenAddress = "0x6866E9BDaF921050302680537DeFe9E17352F780"
    NFTAddress = "0xE71C4CC2F27ECE14Bd4b835D5c7f188b484d085a"
  } else {
    const TestToken = await ethers.getContractFactory("TestToken")
    const testToken = await TestToken.deploy()
    await testToken.waitForDeployment()

    tokenAddress = await testToken.getAddress()
    NFTAddress = tokenAddress //TODO: DEPLOY TEST NFT ONLY ON LOCAL NETWORKs
  }

  console.log("tokenAddress", tokenAddress)
  console.log("NFTAddress", NFTAddress)

  // const testNFTAdress = testTokenAddress

  const AEGStaking = await ethers.getContractFactory("AEGStaking")
  const aegStaking = await upgrades.deployProxy(AEGStaking, [tokenAddress, NFTAddress], { initializer: "initialize" })
  await aegStaking.waitForDeployment()

  console.log("aegStaking deployed to: ", aegStaking)

  // await aegStaking.setAegToken(tokenAddress)

  // aegStakingAddress = await aegStaking.getAddress()

  // ------------------- Create a pool -------------------

  await createPools(aegStaking)

  // ------------------- Checks -------------------

  //get token in contract and nft in contract
  const tokenInContract = await aegStaking.aegToken()
  const nftInContract = await aegStaking.nft()

  console.log("tokenInContract", tokenInContract)
  console.log("nftInContract", nftInContract)

  //get pools
  const pool0 = await aegStaking.pools(0)
  // console.log("pool[0]", pool0)

  //get all pools
  const allPools = await aegStaking.allPools()
  console.log("allPools", allPools)

  //wait for 1 block
  await network.provider.send("evm_mine")

  for (let i = 0; i < allPools.length; i++) {
    console.log("----pool----", i)

    const userPoolInfo = await aegStaking.userPoolInfo(i, owner.address)
    console.log("userPoolInfo", userPoolInfo)
    const [userBalance, startTime, lockDuration, currentReward, wasNftHolderWhenStaked] = userPoolInfo
    const userPoolObject = {
      userBalance: userBalance.toString(),
      startTime: startTime.toString(),
      lockDuration: lockDuration.toString(),
      currentReward: currentReward.toString(),
      wasNftHolderWhenStaked,
    }

    console.log("userPoolObject", userPoolObject)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
