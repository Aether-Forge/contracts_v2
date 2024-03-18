const { ethers, run, network } = require("hardhat")

const getRewardRate = (apr) => {
  const rate = (apr / 100 / 31536000) * 1000000000000
  return Math.round(rate)
}

//ex 4% APR, 4.4% boosted APR => 1100 or 1.1x
const calculateRewardMultiplier = (apr, boostedApr) => {
  const multiplier = (boostedApr / apr) * 1000
  return Math.round(multiplier)
}

//bronze, silver, gold, platinum
const prodPools = [
  {
    name: "Bronze",
    lockDuration: 60 * 60 * 24 * 30, // 30 days
    rewardRate: getRewardRate(4),
    rewardMultiplier: 1100, // 1.1x multiplier
    limitPerAddress: ethers.parseEther("10000"),
    maxStake: ethers.parseEther("30000000"),
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  {
    name: "Silver",
    lockDuration: 60 * 60 * 24 * 90, // 90 days
    rewardRate: getRewardRate(10),
    rewardMultiplier: 1100, // 1.1x multiplier
    limitPerAddress: ethers.parseEther("30000"),
    maxStake: ethers.parseEther("12000000"),
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  {
    name: "Gold",
    lockDuration: 60 * 60 * 24 * 180, // 180 days
    rewardRate: getRewardRate(18),
    rewardMultiplier: 1100, // 1.1x multiplier
    limitPerAddress: ethers.parseEther("70000"),
    maxStake: ethers.parseEther("21000000"),
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  {
    name: "Platinum",
    lockDuration: 60 * 60 * 24 * 365, // 365 days
    rewardRate: getRewardRate(30),
    rewardMultiplier: 1100, // 1.1x multiplier
    limitPerAddress: ethers.parseEther("100000"),
    maxStake: ethers.parseEther("15000000"),
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
]

const devPools = [
  {
    name: "Dev Pool 1",
    lockDuration: 0, // 0 seconds
    rewardRate: getRewardRate(10), // 10% APR
    rewardMultiplier: 3000, // 3x multiplier
    limitPerAddress: ethers.parseEther("1000"), // 10000 tokens
    maxStake: ethers.parseEther("10000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365, // 1 year
    isPaused: false,
  },
  {
    name: "Dev Pool 2",
    lockDuration: 60 * 10, // 10 minutes
    rewardRate: getRewardRate(50), // 50% APR
    rewardMultiplier: 2000, // 2x multiplier
    limitPerAddress: ethers.parseEther("1000"), // 10000 tokens
    maxStake: ethers.parseEther("10000"), // 10000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365, // 1 year
    isPaused: false,
  },
]
let pools = []
if (network.name === "polygon" || network.name === "matic") {
  pools = prodPools
} else {
  pools = [...prodPools, ...devPools]
}

const createPools = async (stakingContract) => {
  for (const pool of pools) {
    // console.log("Creating pool", pool)

    const res = await stakingContract.createPool(
      pool.name,
      pool.lockDuration,
      pool.rewardRate,
      pool.rewardMultiplier,
      pool.limitPerAddress,
      pool.maxStake,
      pool.endTime,
      pool.isPaused
    )

    console.log("Pool created", res.hash)
  }
}

module.exports = {
  pools,
  getRewardRate,
  createPools,
}
