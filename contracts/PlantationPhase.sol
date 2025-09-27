// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./IoTData.sol";
import "./RewardSystem.sol";

contract PlantationPhase {
    DurianNFT public durianNFT;
    IoTData public iotData;
    RewardSystem public rewardSystem;
    
    struct PlantationInfo {
        address farmer;
        uint256 plantDate;
        string location;
        string soilType;
        uint256 treeAge;
        string fertilizerUsed;
    }
    
    mapping(uint256 => PlantationInfo) public plantationRecords;
    
    event DurianPlanted(uint256 tokenId, address farmer, string variety, string location);
    event PlantationDataRecorded(uint256 tokenId, uint256 dataScore);
    
    constructor(address _nftContract, address _iotContract, address _rewardContract) {
        durianNFT = DurianNFT(_nftContract);
        iotData = IoTData(_iotContract);
        rewardSystem = RewardSystem(_rewardContract);
    }
    
    function plantDurian(
        string memory variety,
        string memory location,
        uint256 weight,
        string memory soilType,
        uint256 treeAge,
        string memory fertilizerUsed
    ) public returns (uint256) {
        require(durianNFT.rolesContract().hasRole(durianNFT.rolesContract().FARMER_ROLE(), msg.sender), 
            "Only farmers can plant");
        
        // 创建NFT
        uint256 tokenId = durianNFT.plantDurian(variety, location, weight);
        
        // 记录种植信息
        plantationRecords[tokenId] = PlantationInfo({
            farmer: msg.sender,
            plantDate: block.timestamp,
            location: location,
            soilType: soilType,
            treeAge: treeAge,
            fertilizerUsed: fertilizerUsed
        });
        
        emit DurianPlanted(tokenId, msg.sender, variety, location);
        return tokenId;
    }
    
    function recordPlantationData(
        uint256 tokenId,
        int256 temperature,
        uint256 humidity,
        uint256 soilMoisture,
        uint256 soilPH,
        int256 gpsLatitude,
        int256 gpsLongitude,
        uint256 lightIntensity,
        uint256 co2Level,
        string memory additionalData
    ) public returns (uint256) {
        require(durianNFT.ownerOf(tokenId) == msg.sender, "Not owner of this durian");
        
        uint256 dataScore = iotData.recordPlantationData(
            tokenId, temperature, humidity, soilMoisture, soilPH, 
            gpsLatitude, gpsLongitude, lightIntensity, co2Level, additionalData
        );
        
        // 如果数据质量高，发放奖励
        if (dataScore >= 80) {
            rewardSystem.distributeReward(
                tokenId, 
                1, 
                msg.sender, 
                dataScore, 
                "High quality plantation data recorded"
            );
        }
        
        emit PlantationDataRecorded(tokenId, dataScore);
        return dataScore;
    }
    
    function getPlantationInfo(uint256 tokenId) public view returns (PlantationInfo memory) {
        return plantationRecords[tokenId];
    }
}