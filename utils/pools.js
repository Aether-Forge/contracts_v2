const { ethers, run } = require("hardhat")

const getRewardRate = (apr) => {
  const rate = (apr / 100 / 31536000) * 1000000000000
  return Math.round(rate)
}

const prodPools = [
  //10%, 30 days, 10k user limit
  {
    lockDuration: 60 * 60 * 24 * 30, // 30 days
    rewardRate: getRewardRate(10), // 10% APR
    rewardMultiplier: 1000, // 1x so no multiplier
    limitPerAddress: ethers.parseEther("10000"), // 10000 tokens
    maxStake: ethers.parseEther("100000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  //20%, 90 days, 30k user limit
  {
    lockDuration: 60 * 60 * 24 * 90, // 90 days
    rewardRate: getRewardRate(20), // 20% APR
    rewardMultiplier: 1000, // 1x so no multiplier
    limitPerAddress: ethers.parseEther("30000"), // 30000 tokens
    maxStake: ethers.parseEther("100000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  //25%, 180 days, 70k user limit
  {
    lockDuration: 60 * 60 * 24 * 180, // 180 days
    rewardRate: getRewardRate(25), // 25% APR
    rewardMultiplier: 1000, // 1x so no multiplier
    limitPerAddress: ethers.parseEther("70000"), // 70000 tokens
    maxStake: ethers.parseEther("100000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
  //35%, 365 days, 100k user limit
  {
    lockDuration: 60 * 60 * 24 * 365, // 365 days
    rewardRate: getRewardRate(35), // 35% APR
    rewardMultiplier: 1000, // 1x so no multiplier
    limitPerAddress: ethers.parseEther("100000"), // 100000 tokens
    maxStake: ethers.parseEther("100000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365 * 3, // 3 years from now
    isPaused: false,
  },
]

const devPools = [
  {
    lockDuration: 0, // 0 seconds
    rewardRate: getRewardRate(10), // 10% APR
    rewardMultiplier: 3000, // 3x multiplier
    limitPerAddress: ethers.parseEther("1000"), // 10000 tokens
    maxStake: ethers.parseEther("10000"), // 100000 tokens
    endTime: Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 365, // 1 year
    isPaused: false,
  },
]

const pools = [...prodPools, ...devPools]

const createPools = async (stakingContract) => {
  for (const pool of pools) {
    // console.log("Creating pool", pool)

    const res = await stakingContract.createPool(
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
