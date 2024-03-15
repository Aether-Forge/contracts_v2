// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable-4.7.3/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/security/ReentrancyGuardUpgradeable.sol";

import "hardhat/console.sol";

contract AEGStaking_2 is Initializable, ReentrancyGuardUpgradeable {
    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool holderWhenStaking;
    }

    struct Pool {
        uint256 lockDuration;
        uint256 rewardRate;
        uint256 rewardMultiplier;
        uint256 totalStaked;
        uint256 limitPerAddress;
        uint256 maxStake;
        uint256 endTime;
        bool isPaused;
        mapping(address => uint256) balances;
        // mapping(address => uint256) startTimes;
        // mapping(address => bool) holdersWhenStaking;
        mapping(address => uint256) rewardsClaimed;
        // mapping(address => uint256) unclaimedRewards;
        mapping(address => Stake[]) stakes;
    }

    struct PoolView {
        uint256 lockDuration;
        uint256 rewardRate;
        uint256 rewardMultiplier;
        uint256 totalStaked;
        uint256 limitPerAddress;
        uint256 maxStake;
        uint256 endTime;
        bool isPaused;
    }

    struct UserPoolInfo {
        uint256 balance;
        uint256 startTime;
        uint256 lockDuration;
        uint256 currentReward;
        uint256 rewardsClaimed;
        bool holderWhenStaking;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    address public owner;

    Pool[] public pools;
    IERC20 public aegToken;
    IERC721 public nft;
    uint256 public totalStaked;
    uint256 public totalRewardsClaimed;

    function initialize(IERC20 _aegToken, IERC721 _nft) external initializer {
        aegToken = _aegToken;
        nft = _nft;
        owner = msg.sender;
        __ReentrancyGuard_init();
    }

    function createPool(
        uint256 lockDuration,
        uint256 rewardRate,
        uint256 rewardMultiplier,
        uint256 limitPerAddress,
        uint256 maxStake,
        uint256 endTime,
        bool isPaused
    ) external onlyOwner {
        Pool storage newPool = pools.push();
        newPool.lockDuration = lockDuration;
        newPool.rewardRate = rewardRate;
        newPool.rewardMultiplier = rewardMultiplier;
        newPool.limitPerAddress = limitPerAddress;
        newPool.maxStake = maxStake;
        newPool.endTime = endTime;
        newPool.totalStaked = 0;
        newPool.isPaused = isPaused;
    }

    function stake(uint256 poolId, uint256 amount) external nonReentrant {
        require(poolId < pools.length, "Pool does not exist");
        require(!pools[poolId].isPaused, "Pool is paused");
        require(block.timestamp < pools[poolId].endTime, "Pool has ended");
        require(amount > 0, "Cannot stake 0 tokens");
        require(
            aegToken.balanceOf(msg.sender) >= amount,
            "Insufficient token balance"
        );
        require(
            pools[poolId].balances[msg.sender] + amount <=
                pools[poolId].limitPerAddress,
            "Exceeds limit per address"
        );
        require(
            pools[poolId].totalStaked + amount <= pools[poolId].maxStake,
            "Exceeds max stake"
        );
        Pool storage pool = pools[poolId];
        Stake memory newStake = Stake({
            amount: amount,
            startTime: block.timestamp,
            holderWhenStaking: nft.balanceOf(msg.sender) > 0
        });
        pool.stakes[msg.sender].push(newStake);
        // if (pool.balances[msg.sender] > 0) {
        //     uint256 reward = calculateReward(poolId, msg.sender);
        //     pool.unclaimedRewards[msg.sender] += reward;
        // }

        pool.balances[msg.sender] += amount;
        pool.totalStaked += amount;
        totalStaked += amount;
        aegToken.transferFrom(msg.sender, address(this), amount);
        // pool.startTimes[msg.sender] = block.timestamp;
        // pool.holdersWhenStaking[msg.sender] = nft.balanceOf(msg.sender) > 0;
    }

    // function unstake(uint256 poolId) external nonReentrant {
    //     require(poolId < pools.length, "Pool does not exist");
    //     Pool storage pool = pools[poolId];
    //     uint256 amount = pool.balances[msg.sender];
    //     _claim(poolId);
    //     pool.balances[msg.sender] -= amount;
    //     pool.totalStaked -= amount;
    //     totalStaked -= amount;
    //     aegToken.transfer(msg.sender, amount);
    // }

    function unstake(uint256 poolId) external nonReentrant {
        require(poolId < pools.length, "Pool does not exist");
        Pool storage pool = pools[poolId];
        Stake[] storage stakes = pool.stakes[msg.sender];
        uint256 totalAmount = 0;

        for (uint256 i = stakes.length; i > 0; i--) {
            if (
                stakes[i - 1].amount > 0 &&
                block.timestamp > stakes[i - 1].startTime + pool.lockDuration
            ) {
                _claim(poolId, i - 1);
                totalAmount += stakes[i - 1].amount;
                stakes[i - 1].amount = 0;
            }
        }

        require(totalAmount > 0, "No tokens to unstake");

        pool.totalStaked -= totalAmount;
        totalStaked -= totalAmount;
        pool.balances[msg.sender] -= totalAmount;
        aegToken.transfer(msg.sender, totalAmount);
    }

    function _claim(uint256 poolId, uint256 stakeIndex) internal {
        require(
            block.timestamp >
                pools[poolId].stakes[msg.sender][stakeIndex].startTime +
                    pools[poolId].lockDuration,
            "Tokens are still locked"
        );

        uint256 reward = calculateReward(poolId, msg.sender, stakeIndex);
        // pools[poolId].unclaimedRewards[msg.sender];

        require(
            aegToken.balanceOf(address(this)) >= reward,
            "Contract does not have enough tokens for reward"
        );

        // pools[poolId].startTimes[msg.sender] = block.timestamp;
        // pools[poolId].unclaimedRewards[msg.sender] = 0;
        aegToken.transfer(msg.sender, reward);
        totalRewardsClaimed += reward;
        pools[poolId].rewardsClaimed[msg.sender] += reward;
    }

    function calculateReward(
        uint256 poolId,
        address userAddress,
        uint256 stakeIndex
    ) public view returns (uint256) {
        require(poolId < pools.length, "Pool does not exist");
        Pool storage pool = pools[poolId];
        Stake storage stakeD = pool.stakes[userAddress][stakeIndex];
        uint256 timeStaked = block.timestamp - stakeD.startTime;
        uint256 rewardRate = pool.rewardRate;

        if (pool.lockDuration > 0 && timeStaked > pool.lockDuration) {
            timeStaked = pool.lockDuration;
        }

        if (stakeD.holderWhenStaking && nft.balanceOf(userAddress) > 0) {
            rewardRate = (rewardRate * pool.rewardMultiplier) / 1000;
        }

        return (rewardRate * timeStaked * stakeD.amount) / 1000000000000;
    }

    function togglePause(uint256 poolId) external onlyOwner {
        require(poolId < pools.length, "Pool does not exist");
        pools[poolId].isPaused = !pools[poolId].isPaused;
    }

    function setEndTime(uint256 poolId, uint256 endTime) external onlyOwner {
        require(poolId < pools.length, "Pool does not exist");
        pools[poolId].endTime = endTime;
    }

    function userPoolInfo(
        uint256 poolId,
        address account
    ) external view returns (UserPoolInfo memory) {
        uint256 totalBalance = 0;
        uint256 totalRewards = 0;

        if (pools[poolId].stakes[account].length == 0) {
            return UserPoolInfo(0, 0, pools[poolId].lockDuration, 0, 0, false);
        }

        for (uint256 i = 0; i < pools[poolId].stakes[account].length; i++) {
            totalBalance += pools[poolId].stakes[account][i].amount;
            totalRewards += calculateReward(poolId, account, i);
        }

        return
            UserPoolInfo(
                totalBalance,
                pools[poolId].stakes[account][0].startTime,
                pools[poolId].lockDuration,
                totalRewards,
                pools[poolId].lockDuration,
                nft.balanceOf(account) > 0
            );
    }

    function userStakesInfo(
        uint256 poolId,
        address account
    ) external view returns (Stake[] memory) {
        return pools[poolId].stakes[account];
    }

    function allPools() external view returns (PoolView[] memory) {
        PoolView[] memory poolViews = new PoolView[](pools.length);
        for (uint i = 0; i < pools.length; i++) {
            poolViews[i] = PoolView(
                pools[i].lockDuration,
                pools[i].rewardRate,
                pools[i].rewardMultiplier,
                pools[i].totalStaked,
                pools[i].limitPerAddress,
                pools[i].maxStake,
                pools[i].endTime,
                pools[i].isPaused
            );
        }
        return poolViews;
    }

    function transferOwnership(address _owner) external onlyOwner {
        owner = _owner;
    }

    function withdrawTokens(
        address tokenAddress,
        uint256 amount
    ) external onlyOwner {
        require(
            IERC20(tokenAddress).balanceOf(address(this)) - totalStaked >=
                amount,
            "Cannot withdraw user staked tokens"
        );
        IERC20(tokenAddress).transfer(owner, amount);
    }
}
