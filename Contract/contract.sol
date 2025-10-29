// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Yield Farming Protocol
 * @dev A decentralized yield farming protocol that allows users to stake tokens and earn rewards
 */
contract YieldFarmingProtocol {
    
    // Struct to store user staking information
    struct StakeInfo {
        uint256 amount;           // Amount of tokens staked
        uint256 startTime;        // When the stake started
        uint256 lastClaimTime;    // Last time rewards were claimed
        uint256 totalRewardsClaimed; // Total rewards claimed by user
    }
    
    // State variables
    mapping(address => StakeInfo) public stakes;
    uint256 public totalStaked;
    uint256 public rewardRatePerSecond; // Reward rate: tokens per second per token staked
    uint256 public minimumStakingPeriod; // Minimum time before unstaking
    address public owner;
    
    // Events
    event Staked(address indexed user, uint256 amount, uint256 timestamp);
    event Unstaked(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 reward, uint256 timestamp);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can call this function");
        _;
    }
    
    constructor(uint256 _rewardRatePerSecond, uint256 _minimumStakingPeriod) {
        owner = msg.sender;
        rewardRatePerSecond = _rewardRatePerSecond;
        minimumStakingPeriod = _minimumStakingPeriod;
    }
    
    /**
     * @dev Core Function 1: Stake tokens into the protocol
     * Users deposit tokens to start earning rewards
     */
    function stake() external payable {
        require(msg.value > 0, "Cannot stake 0 tokens");
        
        // If user already has a stake, claim pending rewards first
        if (stakes[msg.sender].amount > 0) {
            _claimRewards(msg.sender);
        }
        
        // Update or create stake info
        if (stakes[msg.sender].amount == 0) {
            stakes[msg.sender] = StakeInfo({
                amount: msg.value,
                startTime: block.timestamp,
                lastClaimTime: block.timestamp,
                totalRewardsClaimed: 0
            });
        } else {
            stakes[msg.sender].amount += msg.value;
            stakes[msg.sender].lastClaimTime = block.timestamp;
        }
        
        totalStaked += msg.value;
        
        emit Staked(msg.sender, msg.value, block.timestamp);
    }
    
    /**
     * @dev Core Function 2: Calculate and claim rewards
     * Users can claim their earned rewards without unstaking
     */
    function claimRewards() external {
        require(stakes[msg.sender].amount > 0, "No active stake");
        
        uint256 reward = _claimRewards(msg.sender);
        require(reward > 0, "No rewards to claim");
    }
    
    /**
     * @dev Core Function 3: Unstake tokens and claim all rewards
     * Users withdraw their staked tokens along with any pending rewards
     */
    function unstake(uint256 amount) external {
        require(stakes[msg.sender].amount >= amount, "Insufficient staked amount");
        require(amount > 0, "Cannot unstake 0 tokens");
        require(
            block.timestamp >= stakes[msg.sender].startTime + minimumStakingPeriod,
            "Minimum staking period not met"
        );
        
        // Claim any pending rewards
        _claimRewards(msg.sender);
        
        // Update stake info
        stakes[msg.sender].amount -= amount;
        totalStaked -= amount;
        
        // Transfer tokens back to user
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "Transfer failed");
        
        emit Unstaked(msg.sender, amount, block.timestamp);
    }
    
    /**
     * @dev Internal function to calculate and transfer rewards
     */
    function _claimRewards(address user) internal returns (uint256) {
        uint256 reward = calculateRewards(user);
        
        if (reward > 0) {
            stakes[user].lastClaimTime = block.timestamp;
            stakes[user].totalRewardsClaimed += reward;
            
            // Transfer rewards to user
            (bool success, ) = payable(user).call{value: reward}("");
            require(success, "Reward transfer failed");
            
            emit RewardsClaimed(user, reward, block.timestamp);
        }
        
        return reward;
    }
    
    /**
     * @dev Calculate pending rewards for a user
     */
    function calculateRewards(address user) public view returns (uint256) {
        if (stakes[user].amount == 0) {
            return 0;
        }
        
        uint256 stakingDuration = block.timestamp - stakes[user].lastClaimTime;
        uint256 reward = (stakes[user].amount * rewardRatePerSecond * stakingDuration) / 1e18;
        
        return reward;
    }
    
    /**
     * @dev Get user's stake information
     */
    function getStakeInfo(address user) external view returns (
        uint256 amount,
        uint256 startTime,
        uint256 pendingRewards,
        uint256 totalRewardsClaimed
    ) {
        StakeInfo memory userStake = stakes[user];
        return (
            userStake.amount,
            userStake.startTime,
            calculateRewards(user),
            userStake.totalRewardsClaimed
        );
    }
    
    /**
     * @dev Owner function to fund the reward pool
     */
    function fundRewardPool() external payable onlyOwner {
        require(msg.value > 0, "Must send some ETH");
    }
    
    /**
     * @dev Owner function to update reward rate
     */
    function updateRewardRate(uint256 newRate) external onlyOwner {
        rewardRatePerSecond = newRate;
    }
    
    /**
     * @dev Get contract balance (reward pool)
     */
    function getRewardPoolBalance() external view returns (uint256) {
        return address(this).balance - totalStaked;
    }
    
    // Fallback function to receive ETH
    receive() external payable {}
}