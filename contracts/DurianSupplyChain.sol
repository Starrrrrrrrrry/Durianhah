// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Roles.sol";
import "./DurianNFT.sol";
import "./IoTData.sol";
import "./RewardSystem.sol";
import "./PlantationPhase.sol";
import "./HarvestPhase.sol";
import "./PackingPhase.sol";
import "./QualityCheckPhase.sol";
import "./LogisticsPhase.sol";
import "./RetailPhase.sol";

contract DurianSupplyChain {
    Roles public roles;
    DurianNFT public durianNFT;
    IoTData public iotData;
    RewardSystem public rewardSystem;
    
    // 各阶段合约
    PlantationPhase public plantationPhase;
    HarvestPhase public harvestPhase;
    PackingPhase public packingPhase;
    QualityCheckPhase public qualityCheckPhase;
    LogisticsPhase public logisticsPhase;
    RetailPhase public retailPhase;
    
    address public owner;
    
    event SupplyChainInitialized(address owner, uint256 timestamp);
    event NewDurianPlanted(uint256 tokenId, address farmer, string variety);
    
    constructor(address rewardTokenAddress) {
        owner = msg.sender;
        
        // 按正确顺序部署合约
        roles = new Roles();
        durianNFT = new DurianNFT(address(roles));
        iotData = new IoTData(address(roles));
        rewardSystem = new RewardSystem(address(roles), address(durianNFT), rewardTokenAddress);
        
        // 部署各阶段合约
        plantationPhase = new PlantationPhase(address(durianNFT), address(iotData), address(rewardSystem));
        harvestPhase = new HarvestPhase(address(durianNFT), address(iotData), address(rewardSystem));
        packingPhase = new PackingPhase(address(durianNFT), address(rewardSystem));
        qualityCheckPhase = new QualityCheckPhase(address(durianNFT), address(rewardSystem));
        logisticsPhase = new LogisticsPhase(address(durianNFT), address(iotData), address(rewardSystem));
        retailPhase = new RetailPhase(address(durianNFT), address(rewardSystem));
        
        // 设置权限
        _setupPermissions();
        
        emit SupplyChainInitialized(owner, block.timestamp);
    }
    
    function _setupPermissions() private {
        // 为合约设置必要的权限
        // 在实际应用中，这里需要更精细的权限管理
    }
    
    // 获取完整的榴莲历史
    function getFullDurianHistory(uint256 tokenId) public view returns (
        DurianNFT.DurianMetadata memory nftData,
        IoTData.IoTDataSet memory plantationData,
        IoTData.IoTDataSet memory harvestData,
        IoTData.IoTDataSet memory transportData,
        QualityCheckPhase.QualityInspection memory qualityData,
        uint256 totalRewards
    ) {
        nftData = durianNFT.getDurianMetadata(tokenId);
        plantationData = iotData.getPhaseIoTData(tokenId, 1);
        harvestData = iotData.getPhaseIoTData(tokenId, 2);
        transportData = iotData.getPhaseIoTData(tokenId, 5);
        qualityData = qualityCheckPhase.getQualityInspection(tokenId);
        totalRewards = rewardSystem.getPendingReward(durianNFT.ownerOf(tokenId));
        
        return (nftData, plantationData, harvestData, transportData, qualityData, totalRewards);
    }
    
    // 获取供应链状态
    function getSupplyChainStatus(uint256 tokenId) public view returns (
        uint256 currentPhase,
        address currentOwner,
        string memory phaseName,
        bool isQAPassed,
        uint256 dataScore
    ) {
        currentPhase = durianNFT.getCurrentPhase(tokenId);
        currentOwner = durianNFT.ownerOf(tokenId);
        isQAPassed = durianNFT.isQAPassed(tokenId);
        dataScore = iotData.getCurrentDataScore(tokenId);
        
        string memory phase;
        if (currentPhase == 1) phase = "Plantation";
        else if (currentPhase == 2) phase = "Harvest";
        else if (currentPhase == 3) phase = "Packing";
        else if (currentPhase == 4) phase = "Quality Check";
        else if (currentPhase == 5) phase = "Logistics";
        else if (currentPhase == 6) phase = "Retail";
        else phase = "Completed";
        
        return (currentPhase, currentOwner, phase, isQAPassed, dataScore);
    }
    
    // 授予角色权限
    function grantFarmerRole(address account) public {
        require(msg.sender == owner, "Only owner can grant roles");
        roles.grantFarmerRole(account);
    }
    
    function grantPackerRole(address account) public {
        require(msg.sender == owner, "Only owner can grant roles");
        roles.grantPackerRole(account);
    }
    
    function grantQARole(address account) public {
        require(msg.sender == owner, "Only owner can grant roles");
        roles.grantQARole(account);
    }
    
    function grantLogisticsRole(address account) public {
        require(msg.sender == owner, "Only owner can grant roles");
        roles.grantLogisticsRole(account);
    }
    
    function grantRetailerRole(address account) public {
        require(msg.sender == owner, "Only owner can grant roles");
        roles.grantRetailerRole(account);
    }
    
    // 存入奖励代币
    function depositRewardTokens(uint256 amount) public {
        require(msg.sender == owner, "Only owner can deposit tokens");
        rewardSystem.depositRewardTokens(amount);
    }
    
    // 获取合约信息
    function getContractAddresses() public view returns (
        address rolesAddr,
        address nftAddr,
        address iotAddr,
        address rewardAddr,
        address plantationAddr,
        address harvestAddr,
        address packingAddr,
        address qualityAddr,
        address logisticsAddr,
        address retailAddr
    ) {
        return (
            address(roles),
            address(durianNFT),
            address(iotData),
            address(rewardSystem),
            address(plantationPhase),
            address(harvestPhase),
            address(packingPhase),
            address(qualityCheckPhase),
            address(logisticsPhase),
            address(retailPhase)
        );
    }
}