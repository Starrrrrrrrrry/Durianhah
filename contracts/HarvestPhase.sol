// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./IoTData.sol";
import "./RewardSystem.sol";

contract HarvestPhase {
    DurianNFT public durianNFT;
    IoTData public iotData;
    RewardSystem public rewardSystem;
    
    struct HarvestData {
        address harvester;
        uint256 harvestDate;
        uint256 weight;
        uint256 brixLevel; // 糖度
        uint256 maturity; // 成熟度 1-100
        string harvestMethod;
    }
    
    mapping(uint256 => HarvestData) public harvestRecords;
    
    event DurianHarvested(uint256 tokenId, address harvester, uint256 weight, uint256 maturity);
    event HarvestDataRecorded(uint256 tokenId, uint256 dataScore);
    
    constructor(address _nftContract, address _iotContract, address _rewardContract) {
        durianNFT = DurianNFT(_nftContract);
        iotData = IoTData(_iotContract);
        rewardSystem = RewardSystem(_rewardContract);
    }
    
    function harvestDurian(
        uint256 tokenId,
        uint256 weight,
        uint256 brixLevel,
        uint256 maturity,
        string memory harvestMethod
    ) public {
        require(durianNFT.rolesContract().hasRole(durianNFT.rolesContract().FARMER_ROLE(), msg.sender), 
            "Only farmers can harvest");
        require(durianNFT.ownerOf(tokenId) == msg.sender, "Not owner of this durian");
        require(durianNFT.getCurrentPhase(tokenId) == 1, "Durian not ready for harvest");
        
        // 记录收获数据
        harvestRecords[tokenId] = HarvestData({
            harvester: msg.sender,
            harvestDate: block.timestamp,
            weight: weight,
            brixLevel: brixLevel,
            maturity: maturity,
            harvestMethod: harvestMethod
        });
        
        // 更新NFT重量信息
        durianNFT.updateWeight(tokenId, weight);
        
        // 转移到下一阶段（包装）
        address packer = _getNextHandler(); // 简化：这里应该从数据库或配置获取
        durianNFT.transferOwnershipStep(tokenId, packer, "Harvest to Packing", 2);
        
        emit DurianHarvested(tokenId, msg.sender, weight, maturity);
    }
    
    function recordHarvestData(
        uint256 tokenId,
        int256 temperature,
        uint256 humidity,
        int256 gpsLatitude,
        int256 gpsLongitude,
        uint256 fruitMaturity,
        uint256 sugarContent,
        string memory additionalData
    ) public returns (uint256) {
        require(durianNFT.ownerOf(tokenId) == msg.sender, "Not owner of this durian");
        
        uint256 dataScore = iotData.recordHarvestData(
            tokenId, temperature, humidity, gpsLatitude, gpsLongitude, 
            fruitMaturity, sugarContent, additionalData
        );
        
        // 发放收获奖励
        if (dataScore >= 75) {
            rewardSystem.distributeReward(
                tokenId, 
                2, 
                msg.sender, 
                dataScore, 
                "Quality harvest data recorded"
            );
        }
        
        emit HarvestDataRecorded(tokenId, dataScore);
        return dataScore;
    }
    
    function _getNextHandler() private view returns (address) {
        // 简化实现 - 实际应用中应该从注册的包装商中选择
        return msg.sender; // 这里应该返回实际的包装商地址
    }
    
    function getHarvestData(uint256 tokenId) public view returns (HarvestData memory) {
        return harvestRecords[tokenId];
    }
}