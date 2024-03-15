const { ethers, upgrades, network, run } = require("hardhat")
const fs = require("fs")
const { createPools } = require("../utils/pools")

async function main() {
  let token, tokenAddress, NFTAddress, isLocal
  const [owner, addr1, addr2] = await ethers.getSigners()
  console.log("Deploying AEGStaking...", network.name)

  if (network.name === "polygon") {
    tokenAddress = "0xE3f2b1B2229C0333Ad17D03F179b87500E7C5e01"
    token = await ethers.getContractAt("TestToken", tokenAddress)
    NFTAddress = "0x0059598a11e8CF4ce0CDBF452FC32Cec4AE4b87D"

    console.log("Deploying on polygon NOT ALLOWED YET")
    return
  } else if (network.name === "mumbai") {
    tokenAddress = "0x6866E9BDaF921050302680537DeFe9E17352F780"
    token = await ethers.getContractAt("TestToken", tokenAddress)
    NFTAddress = "0xE71C4CC2F27ECE14Bd4b835D5c7f188b484d085a"
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

  // const testNFTAdress = testTokenAddress

  const AEGStaking = await ethers.getContractFactory("AEGStaking_2")
  const aegStaking = await upgrades.deployProxy(AEGStaking, [tokenAddress, NFTAddress])
  await aegStaking.waitForDeployment()
  const aegStakingAddress = await aegStaking.getAddress()

  console.log("aegStaking deployed to: ", aegStakingAddress)

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
  console.log("allPools", allPools.length)

  //wait for 1 block
  await network.provider.send("evm_mine")

  for (let i = 0; i < allPools.length; i++) {
    // console.log("----pool----", i, owner.address)
    // const userPoolInfo = await aegStaking.userPoolInfo(i, owner.address)
    // console.log("userPoolInfo", userPoolInfo)
    // const [userBalance, startTime, lockDuration, currentReward, wasNftHolderWhenStaked] = userPoolInfo
    // const userPoolObject = {
    //   userBalance: userBalance.toString(),
    //   startTime: startTime.toString(),
    //   lockDuration: lockDuration.toString(),
    //   currentReward: currentReward.toString(),
    //   wasNftHolderWhenStaked,
    // }
    // console.log("userPoolObject", userPoolObject)
    // const userStakesInfo = await aegStaking.userStakesInfo(i, owner.address)
    // console.log("userStakesInfo", userStakesInfo)
  }
  if (isLocal) {
    console.log("starting local tests")
    const poolId = 4
    //tranfer some tokens to contract
    const contractInitialAmountOfTokens = "10000000000000000000000" //10000 tokens
    await token.transfer(aegStakingAddress, contractInitialAmountOfTokens)

    //stake some tokens, wait a bit and then check userPoolInfo and userStakesInfo
    // const amount = "1000000000000000000000" //1000 tokens
    const amount = "500000000000000000000" //1000 tokens
    const approveRes = await token.approve(aegStakingAddress, amount)

    await aegStaking.stake(poolId, amount) //4 is the unlocked pool
    await network.provider.send("evm_mine")

    const userPoolInfo = await aegStaking.userPoolInfo(poolId, owner.address)
    console.log("userPoolInfo", userPoolInfo)
    const userStakesInfo = await aegStaking.userStakesInfo(poolId, owner.address)
    console.log("userStakesInfo", userStakesInfo)

    const approveRes2 = await token.approve(aegStakingAddress, amount)
    await aegStaking.stake(poolId, amount)
    await network.provider.send("evm_mine")

    const userPoolInfo2 = await aegStaking.userPoolInfo(poolId, owner.address)
    console.log("userPoolInfo2", userPoolInfo2)
    const userStakesInfo2 = await aegStaking.userStakesInfo(poolId, owner.address)
    console.log("userStakesInfo2", userStakesInfo2)

    //unstake
    await aegStaking.unstake(4)

    const userPoolInfo3 = await aegStaking.userPoolInfo(4, owner.address)
    console.log("userPoolInfoUNSTAKED", userPoolInfo3)
    const userStakesInfo3 = await aegStaking.userStakesInfo(4, owner.address)
    console.log("userStakesInfoUNSTAKED", userStakesInfo3)
  }
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
