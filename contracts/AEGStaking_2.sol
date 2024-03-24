// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

contract AEGStaking_2 is Initializable, ReentrancyGuardUpgradeable {
    struct Stake {
        uint256 amount;
        uint256 startTime;
        bool holderWhenStaking;
    }

    struct Pool {
        string name;
        uint256 lockDuration;
        uint256 rewardRate;
        uint256 rewardMultiplier;
        uint256 totalStaked;
        uint256 limitPerAddress;
        uint256 maxStake;
        uint256 endTime;
        bool isPaused;
        mapping(address => uint256) balances;
        mapping(address => uint256) rewardsClaimed;
        mapping(address => Stake[]) stakes;
    }

    struct PoolView {
        string name;
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
        string name;
        uint256 balance;
        uint256 releasable;
        uint256 startTime;
        uint256 currentReward;
        uint256 rewardsClaimed;
    }

    modifier poolExists(uint256 poolId) {
        require(poolId < pools.length, "Pool does not exist");
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }

    event PoolCreated(uint256 poolId, string name);
    event PoolPaused(uint256 poolId, bool isPaused);
    event AllPoolsPaused();
    event EndTimeSet(uint256 poolId, uint256 endTime);
    event TokensWithdrawn(address tokenAddress, uint256 amount);

    address public owner;

    Pool[] public pools;
    IERC20 public aegToken;
    IERC721 public nft;
    uint256 public totalStaked;
    uint256 public totalRewardsClaimed;

    function initialize(IERC20 _aegToken, IERC721 _nft) external initializer {
        require(address(_aegToken) != address(0), "Zero address");
        require(address(_nft) != address(0), "Zero address");
        aegToken = _aegToken;
        nft = _nft;
        owner = msg.sender;
        __ReentrancyGuard_init();
    }

    function createPool(
        string memory name,
        uint256 lockDuration,
        uint256 rewardRate,
        uint256 rewardMultiplier,
        uint256 limitPerAddress,
        uint256 maxStake,
        uint256 endTime,
        bool isPaused
    ) external onlyOwner {
        Pool storage newPool = pools.push();
        newPool.name = name;
        newPool.lockDuration = lockDuration;
        newPool.rewardRate = rewardRate;
        newPool.rewardMultiplier = rewardMultiplier;
        newPool.limitPerAddress = limitPerAddress;
        newPool.maxStake = maxStake;
        newPool.endTime = endTime;
        newPool.totalStaked = 0;
        newPool.isPaused = isPaused;

        emit PoolCreated(pools.length - 1, name);
    }

    function stake(
        uint256 poolId,
        uint256 amount
    ) external nonReentrant poolExists(poolId) {
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

        pool.balances[msg.sender] += amount;
        pool.totalStaked += amount;
        totalStaked += amount;
        require(
            aegToken.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );
    }

    function unstake(uint256 poolId) external nonReentrant poolExists(poolId) {
        Pool storage pool = pools[poolId];
        Stake[] storage stakes = pool.stakes[msg.sender];
        uint256 totalAmount = 0;
        uint256 totalReward = 0;

        for (uint256 i = stakes.length; i > 0; i--) {
            if (
                stakes[i - 1].amount > 0 &&
                block.timestamp > stakes[i - 1].startTime + pool.lockDuration
            ) {
                totalReward += calculateReward(poolId, msg.sender, i - 1);
                totalAmount += stakes[i - 1].amount;
                stakes[i - 1].amount = 0;
            }
        }

        require(totalAmount > 0, "No tokens to unstake");

        pool.totalStaked -= totalAmount;
        totalStaked -= totalAmount;
        totalRewardsClaimed += totalReward;
        pool.rewardsClaimed[msg.sender] += totalReward;
        pool.balances[msg.sender] -= totalAmount;
        require(
            aegToken.transfer(msg.sender, totalAmount + totalReward),
            "Transfer failed"
        );
    }

    function calculateReward(
        uint256 poolId,
        address userAddress,
        uint256 stakeIndex
    ) public view poolExists(poolId) returns (uint256) {
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

    function togglePause(uint256 poolId) external onlyOwner poolExists(poolId) {
        pools[poolId].isPaused = !pools[poolId].isPaused;
        emit PoolPaused(poolId, pools[poolId].isPaused);
    }

    function pauseAllPools() external onlyOwner {
        for (uint256 i = 0; i < pools.length; i++) {
            pools[i].isPaused = true;
        }
        emit AllPoolsPaused();
    }

    function setEndTime(
        uint256 poolId,
        uint256 endTime
    ) external onlyOwner poolExists(poolId) {
        require(endTime > block.timestamp, "End time must be in the future");
        pools[poolId].endTime = endTime;
        emit EndTimeSet(poolId, endTime);
    }

    function userPoolInfo(
        uint256 poolId,
        address account
    ) external view returns (UserPoolInfo memory) {
        uint256 totalBalance = 0;
        uint256 totalRewards = 0;
        uint256 releasable = 0;

        if (pools[poolId].stakes[account].length == 0) {
            revert("No stakes found");
        }

        uint256 startTime = pools[poolId].stakes[account][0].startTime;

        for (uint256 i = 0; i < pools[poolId].stakes[account].length; i++) {
            totalBalance += pools[poolId].stakes[account][i].amount;
            totalRewards += calculateReward(poolId, account, i);
            if (
                block.timestamp >
                pools[poolId].stakes[account][i].startTime +
                    pools[poolId].lockDuration
            ) {
                releasable += pools[poolId].stakes[account][i].amount;
            }
        }
        return
            UserPoolInfo(
                pools[poolId].name,
                totalBalance,
                releasable,
                startTime,
                totalRewards,
                pools[poolId].rewardsClaimed[account]
            );
    }

    function userStakesInfo(
        uint256 poolId,
        address account
    ) external view returns (Stake[] memory) {
        Stake[] memory stakes = pools[poolId].stakes[account];
        for (uint256 i = 0; i < stakes.length; i++) {
            stakes[i].holderWhenStaking =
                nft.balanceOf(account) > 0 &&
                stakes[i].holderWhenStaking;
        }
        return stakes;
    }

    function allPools() external view returns (PoolView[] memory) {
        PoolView[] memory poolViews = new PoolView[](pools.length);
        for (uint i = 0; i < pools.length; i++) {
            poolViews[i] = PoolView(
                pools[i].name,
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
}
