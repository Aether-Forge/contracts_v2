const { expect } = require("chai")
const { ethers, upgrades } = require("hardhat")
const { createPools } = require("../utils/pools")

describe("AEGStaking", function () {
  let aegStaking, owner, addr1, addr2, testToken, aegStakingAddress, testTokenAddress

  const deployer = async () => {
    const [owner, addr1, addr2] = await ethers.getSigners()
    return { owner, addr1, addr2 }
  }

  beforeEach(async () => {
    const deployers = await deployer()
    owner = deployers.owner
    addr1 = deployers.addr1
    addr2 = deployers.addr2

    const TestToken = await ethers.getContractFactory("TestToken")
    testToken = await TestToken.deploy()
    await testToken.waitForDeployment()

    testTokenAddress = await testToken.getAddress()
    const testNFTAdress = testTokenAddress

    const AEGStaking = await ethers.getContractFactory("AEGStaking")
    aegStaking = await upgrades.deployProxy(AEGStaking, [testTokenAddress, testNFTAdress])
    await aegStaking.waitForDeployment()

    // await aegStaking.setAegToken(testTokenAddress)

    aegStakingAddress = await aegStaking.getAddress()

    // ------------------- Create a pool -------------------

    await createPools(aegStaking)

    // ------------------- Fill Contract -------------------

    //send 10000 testtokens to stakingContract
    const contractInitialAmountOfTokens = "10000000000000000000000" //10000 tokens
    await testToken.transfer(aegStakingAddress, contractInitialAmountOfTokens)

    //get user balance of testToken
    // const userBalance = await testToken.balanceOf(owner.address)
    // const contractBalance = await testToken.balanceOf(aegStakingAddress)
  })

  describe("Deployment", function () {
    it("Should have the right token", async function () {
      const testTokenAddress = await testToken.getAddress()
      expect(await aegStaking.aegToken()).to.equal(testTokenAddress)
    })
  })

  describe("Staking", function () {
    it("Should allow staking", async function () {
      const amount = "1000000000000000000000" //1000 tokens
      // const amount = "238000000000000000000" //238 tokens

      const approveRes = await testToken.approve(aegStakingAddress, amount)

      await aegStaking.stake(0, amount)
      const pool = await aegStaking.pools(0)
      expect(pool.totalStaked).to.equal(amount)

      //check the users balance in the pool
      const userBalance = await aegStaking.balanceOf(0, owner.address)
      expect(userBalance).to.equal(amount)
    })

    it("Should not allow staking more than balance", async function () {
      const amount = "10001000000000000000000" //10000 tokens

      //need to approve the contract to spend the tokens
      await testToken.approve(aegStakingAddress, amount)
      await expect(aegStaking.stake(0, amount)).to.be.revertedWith("Insufficient token balance")
    })

    it("Should not allow staking in non-existent pool", async function () {
      const amount = "1000000000000000000000" //1000 tokens

      await testToken.approve(aegStakingAddress, amount)
      await expect(aegStaking.stake(1, amount)).to.be.revertedWith("Pool does not exist")
    })

    it("Should not allow staking 0 tokens", async function () {
      const amount = "0" //0 tokens

      await testToken.approve(aegStakingAddress, amount)
      await expect(aegStaking.stake(0, amount)).to.be.revertedWith("Cannot stake 0 tokens")
    })

    it("Should not allow staking more than limitPerAddress", async function () {
      //get user currecnt balance of testToken
      const balance = await testToken.balanceOf(owner.address)
      console.log("balance", balance.toString())
      const pool = await aegStaking.pools(0)
      const limitPerAddress = pool.limitPerAddress.toString()
      const amount = limitPerAddress + 1

      await testToken.approve(aegStakingAddress, amount)
      await expect(aegStaking.stake(0, amount)).to.be.revertedWith("Exceeds limit per address")
    })
    it("Should not allow staking more than maxStake", async function () {
      const pool = await aegStaking.pools(0)
      const maxStake = pool.maxStake.toString()
      console.log("maxStake", maxStake)
      const amount = maxStake + 1

      await testToken.approve(aegStakingAddress, amount)
      await expect(aegStaking.stake(0, amount)).to.be.revertedWith("Exceeds max stake")
    })
  })

  describe("Unstaking", function () {
    const amount = "1000000000000000000000" //1000 tokens

    let userBalanceBefore, userBalanceAfter

    beforeEach(async () => {
      await testToken.approve(aegStakingAddress, amount)
      userBalanceBefore = await testToken.balanceOf(owner.address)
      console.log("userBalanceBefore", userBalanceBefore.toString()) //should be 1000
      await aegStaking.stake(0, amount)
    })

    // it("Should not allow unstaking more than staked", async function () {
    //   await expect(aegStaking.unstake(0)).to.be.revertedWith("Not enough balance")
    // })

    it("Should not allow unstaking from non-existent pool", async function () {
      await expect(aegStaking.unstake(1)).to.be.revertedWith("Pool does not exist")
    })

    it("Should allow unstaking and the balance should be slightly higher than originally in users wallet", async function () {
      //wait 10 seconds
      // console.log("waiting 10 seconds")
      // await new Promise((resolve) => setTimeout(resolve, 10000))

      //time warp 1 year into the future // USE THIS FOR SEEING APR RESULTS
      // await network.provider.send("evm_increaseTime", [31536000])
      // await network.provider.send("evm_mine")

      //get the reward amount from contract
      const reward = await aegStaking.calculateReward(0)
      console.log("reward", reward.toString())

      await aegStaking.unstake(0)

      const userBalanceAfter = await testToken.balanceOf(owner.address)
      console.log("userBalanceAfter", userBalanceAfter.toString()) //should be 1000.0001
      expect(userBalanceAfter).to.be.gt(userBalanceBefore)
    })
  })

  describe("Claiming", function () {
    const amount = "1000000000000000000000" //1000 tokens
    let userBalanceBefore, userBalanceAfter

    beforeEach(async () => {
      await testToken.approve(aegStakingAddress, amount)
      await aegStaking.stake(0, amount)
      userBalanceBefore = await testToken.balanceOf(owner.address)
      console.log("userBalanceBefore", userBalanceBefore.toString()) //should be 1000
    })

    it("Should not allow claiming from non-existent pool", async function () {
      await expect(aegStaking.claim(1)).to.be.revertedWith("Pool does not exist")
    })

    it("Should allow claiming", async function () {
      //time warp 1 year into the future // USE THIS FOR SEEING APR RESULTS
      // await network.provider.send("evm_increaseTime", [31536000])
      // await network.provider.send("evm_mine")

      //get the reward amount from contract
      const reward = await aegStaking.calculateReward(0)
      console.log("reward", reward.toString())

      await aegStaking.claim(0)
      userBalanceAfter = await testToken.balanceOf(owner.address)
      console.log("userBalanceAfter", userBalanceAfter.toString()) //should be 1000.0001
      //after should be gt before
      expect(userBalanceAfter).to.be.gt(userBalanceBefore)
    })

    it("Should not allow claiming before end time", async function () {
      await expect(aegStaking.claim(0)).to.be.revertedWith("Tokens are still locked")
    })
  })
})
