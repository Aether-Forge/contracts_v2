// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable-4.7.3/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable-4.7.3/security/ReentrancyGuardUpgradeable.sol";

contract AEGStaking is Initializable, ReentrancyGuardUpgradeable {
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
        mapping(address => uint256) startTimes;
        mapping(address => bool) holdersWhenStaking;
        mapping(address => uint256) rewardsClaimed;
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
        aegToken.transferFrom(msg.sender, address(this), amount);
        pool.balances[msg.sender] += amount;
        pool.totalStaked += amount;
        totalStaked += amount;
        pool.startTimes[msg.sender] = block.timestamp;
        pool.holdersWhenStaking[msg.sender] = nft.balanceOf(msg.sender) > 0;
    }

    function unstake(uint256 poolId) external nonReentrant {
        require(poolId < pools.length, "Pool does not exist");
        Pool storage pool = pools[poolId];
        uint256 amount = pool.balances[msg.sender];
        _claim(poolId);
        pool.balances[msg.sender] -= amount;
        pool.totalStaked -= amount;
        totalStaked -= amount;
        aegToken.transfer(msg.sender, amount);
    }

    function _claim(uint256 poolId) internal {
        require(
            block.timestamp >
                pools[poolId].startTimes[msg.sender] +
                    pools[poolId].lockDuration,
            "Tokens are still locked"
        );
        uint256 reward = calculateReward(poolId, msg.sender);
        require(
            aegToken.balanceOf(address(this)) >= reward,
            "Contract does not have enough tokens for reward"
        );
        pools[poolId].startTimes[msg.sender] = block.timestamp;
        aegToken.transfer(msg.sender, reward);
        totalRewardsClaimed += reward;
        pools[poolId].rewardsClaimed[msg.sender] += reward;
    }

    function calculateReward(
        uint256 poolId,
        address userAddress
    ) public view returns (uint256) {
        Pool storage pool = pools[poolId];
        uint256 timeStaked = block.timestamp - pool.startTimes[userAddress];
        uint256 rewardRate = pool.rewardRate;

        if (pool.lockDuration > 0 && timeStaked > pool.lockDuration) {
            timeStaked = pool.lockDuration;
        }

        if (
            pool.holdersWhenStaking[userAddress] &&
            nft.balanceOf(userAddress) > 0
        ) {
            rewardRate = (rewardRate * pool.rewardMultiplier) / 1000;
        }

        return
            (rewardRate * timeStaked * pool.balances[userAddress]) /
            1000000000000;
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
        return
            UserPoolInfo(
                pools[poolId].balances[account],
                pools[poolId].startTimes[account],
                pools[poolId].lockDuration,
                calculateReward(poolId, account),
                pools[poolId].rewardsClaimed[account],
                pools[poolId].holdersWhenStaking[account]
            );
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
