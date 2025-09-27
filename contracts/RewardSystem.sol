// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Roles.sol";
import "./DurianNFT.sol";

contract RewardSystem is Ownable {
    Roles public rolesContract;
    DurianNFT public durianNFT;
    IERC20 public rewardToken;
    
    // 奖励条件结构
    struct RewardCondition {
        uint256 phase;
        uint256 baseReward;
        uint256 bonusMultiplier;
        uint256 maxBonus;
        string condition;
    }
    
    // 阶段定义
    uint8 constant PLANTATION_PHASE = 1;
    uint8 constant HARVEST_PHASE = 2;
    uint8 constant PACKING_PHASE = 3;
    uint8 constant QA_PHASE = 4;
    uint8 constant LOGISTICS_PHASE = 5;
    uint8 constant RETAIL_PHASE = 6;
    
    // 各阶段奖励条件
    mapping(uint8 => mapping(bytes32 => RewardCondition)) public rewardConditions;
    
    // 奖励记录
    struct RewardRecord {
        address recipient;
        uint256 amount;
        uint256 timestamp;
        uint8 phase;
        string reason;
        bool claimed;
    }
    
    mapping(uint256 => mapping(uint8 => RewardRecord)) public tokenRewards;
    mapping(address => uint256) public pendingRewards;
    mapping(address => uint256) public totalClaimedRewards;
    mapping(address => RewardRecord[]) public rewardHistory;
    
    event RewardConditionSet(uint8 phase, bytes32 role, uint256 baseReward);
    event RewardDistributed(uint256 tokenId, uint8 phase, address recipient, uint256 amount, string reason);
    event RewardClaimed(address recipient, uint256 amount);
    event TokensDeposited(uint256 amount);
    event TokensWithdrawn(uint256 amount);

    constructor(address _rolesContract, address _durianNFT, address _rewardToken) {
        rolesContract = Roles(_rolesContract);
        durianNFT = DurianNFT(_durianNFT);
        rewardToken = IERC20(_rewardToken);
        transferOwnership(msg.sender);
        _initializeRewardConditions();
    }
    
    function _initializeRewardConditions() private {
        // 种植阶段奖励条件
        _setRewardCondition(PLANTATION_PHASE, rolesContract.FARMER_ROLE(), 
            100 ether, 150, 50 ether, "成功种植并记录完整环境数据");
        
        // 收获阶段奖励条件  
        _setRewardCondition(HARVEST_PHASE, rolesContract.FARMER_ROLE(), 
            150 ether, 200, 75 ether, "按时收获且果实成熟度达标");
        
        // 包装阶段奖励条件
        _setRewardCondition(PACKING_PHASE, rolesContract.PACKER_ROLE(), 
            80 ether, 120, 40 ether, "包装完好且符合标准");
        
        // 质检阶段奖励条件
        _setRewardCondition(QA_PHASE, rolesContract.QA_ROLE(), 
            120 ether, 180, 60 ether, "严格质检且通过率高");
        
        // 物流阶段奖励条件
        _setRewardCondition(LOGISTICS_PHASE, rolesContract.LOGISTICS_ROLE(), 
            200 ether, 250, 100 ether, "按时送达且温控达标");
        
        // 零售阶段奖励条件
        _setRewardCondition(RETAIL_PHASE, rolesContract.RETAILER_ROLE(), 
            100 ether, 150, 50 ether, "销售完成且客户满意度高");
    }
    
    function _setRewardCondition(uint8 phase, bytes32 role, uint256 base, uint256 multiplier, uint256 maxBonus, string memory condition) private {
        rewardConditions[phase][role] = RewardCondition({
            phase: phase,
            baseReward: base,
            bonusMultiplier: multiplier,
            maxBonus: maxBonus,
            condition: condition
        });
        emit RewardConditionSet(phase, role, base);
    }
    
    // 计算奖励（考虑IoT数据质量）
    function calculateReward(
        uint256 tokenId, 
        uint8 phase, 
        address actor, 
        uint256 iotDataScore
    ) public view returns (uint256) {
        bytes32 role = _getRoleForAddress(actor);
        RewardCondition memory condition = rewardConditions[phase][role];
        require(condition.baseReward > 0, "No reward condition for this phase/role");
        
        // 基础奖励
        uint256 baseReward = condition.baseReward;
        
        // IoT数据质量加成 (0-100分转换为加成百分比)
        uint256 bonusPercentage = (iotDataScore * condition.bonusMultiplier) / 100;
        uint256 bonusAmount = (baseReward * bonusPercentage) / 10000; // 除以10000因为bonusPercentage是百分比*100
        
        // 限制最大奖励
        if (bonusAmount > condition.maxBonus) {
            bonusAmount = condition.maxBonus;
        }
        
        return baseReward + bonusAmount;
    }
    
    // 分发奖励
    function distributeReward(
        uint256 tokenId,
        uint8 phase,
        address actor,
        uint256 iotDataScore,
        string memory reason
    ) public {
        require(msg.sender == owner() || rolesContract.hasRole(rolesContract.DEFAULT_ADMIN_ROLE(), msg.sender), 
            "Only owner or admin can distribute rewards");
        
        uint256 rewardAmount = calculateReward(tokenId, phase, actor, iotDataScore);
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Insufficient reward tokens");
        
        RewardRecord memory record = RewardRecord({
            recipient: actor,
            amount: rewardAmount,
            timestamp: block.timestamp,
            phase: phase,
            reason: reason,
            claimed: false
        });
        
        tokenRewards[tokenId][phase] = record;
        pendingRewards[actor] += rewardAmount;
        rewardHistory[actor].push(record);
        
        emit RewardDistributed(tokenId, phase, actor, rewardAmount, reason);
    }
    
    // 领取奖励
    function claimReward() public {
        uint256 rewardAmount = pendingRewards[msg.sender];
        require(rewardAmount > 0, "No rewards to claim");
        require(rewardToken.balanceOf(address(this)) >= rewardAmount, "Insufficient contract balance");
        
        pendingRewards[msg.sender] = 0;
        totalClaimedRewards[msg.sender] += rewardAmount;
        
        // 标记所有未领取的记录为已领取
        for (uint i = 0; i < rewardHistory[msg.sender].length; i++) {
            if (!rewardHistory[msg.sender][i].claimed) {
                rewardHistory[msg.sender][i].claimed = true;
            }
        }
        
        require(rewardToken.transfer(msg.sender, rewardAmount), "Reward transfer failed");
        emit RewardClaimed(msg.sender, rewardAmount);
    }
    
    // 存入奖励代币
    function depositRewardTokens(uint256 amount) public onlyOwner {
        require(rewardToken.transferFrom(msg.sender, address(this), amount), "Transfer failed");
        emit TokensDeposited(amount);
    }
    
    // 提取奖励代币（仅Owner）
    function withdrawRewardTokens(uint256 amount) public onlyOwner {
        require(rewardToken.transfer(msg.sender, amount), "Transfer failed");
        emit TokensWithdrawn(amount);
    }
    
    function _getRoleForAddress(address actor) private view returns (bytes32) {
        if (rolesContract.hasRole(rolesContract.FARMER_ROLE(), actor)) return rolesContract.FARMER_ROLE();
        if (rolesContract.hasRole(rolesContract.PACKER_ROLE(), actor)) return rolesContract.PACKER_ROLE();
        if (rolesContract.hasRole(rolesContract.QA_ROLE(), actor)) return rolesContract.QA_ROLE();
        if (rolesContract.hasRole(rolesContract.LOGISTICS_ROLE(), actor)) return rolesContract.LOGISTICS_ROLE();
        if (rolesContract.hasRole(rolesContract.RETAILER_ROLE(), actor)) return rolesContract.RETAILER_ROLE();
        revert("No valid role found");
    }
    
    function getPendingReward(address user) public view returns (uint256) {
        return pendingRewards[user];
    }
    
    function getRewardHistory(address user) public view returns (RewardRecord[] memory) {
        return rewardHistory[user];
    }
    
    function getContractBalance() public view returns (uint256) {
        return rewardToken.balanceOf(address(this));
    }
}