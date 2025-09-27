// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./RewardSystem.sol";

contract QualityCheckPhase {
    DurianNFT public durianNFT;
    RewardSystem public rewardSystem;
    
    struct QualityInspection {
        address inspector;
        uint256 timestamp;
        bool passed;
        string grade;
        uint256 score; // 质量评分 1-100
        string notes;
        uint256 sizeRating; // 大小评级 1-5
        uint256 colorRating; // 颜色评级 1-5
        uint256 aromaRating; // 香气评级 1-5
        bool hasInsectDamage;
        bool hasFungus;
        bool isRipe;
    }
    
    mapping(uint256 => QualityInspection) public qualityInspections;
    
    event QualityChecked(uint256 tokenId, address inspector, bool passed, string grade, uint256 score);
    event QualityAlert(uint256 tokenId, string alertType);
    
    constructor(address _nftContract, address _rewardContract) {
        durianNFT = DurianNFT(_nftContract);
        rewardSystem = RewardSystem(_rewardContract);
    }
    
    function performQualityCheck(
        uint256 tokenId,
        string memory grade,
        uint256 score,
        string memory notes,
        uint256 sizeRating,
        uint256 colorRating,
        uint256 aromaRating,
        bool hasInsectDamage,
        bool hasFungus,
        bool isRipe
    ) public {
        require(durianNFT.rolesContract().hasRole(durianNFT.rolesContract().QA_ROLE(), msg.sender), 
            "Only QA inspectors can perform quality check");
        require(durianNFT.getCurrentPhase(tokenId) == 2, "Durian not ready for QA"); // 假设2是收获后阶段
        
        bool passed = (score >= 70) && !hasInsectDamage && !hasFungus && isRipe;
        
        QualityInspection memory inspection = QualityInspection({
            inspector: msg.sender,
            timestamp: block.timestamp,
            passed: passed,
            grade: grade,
            score: score,
            notes: notes,
            sizeRating: sizeRating,
            colorRating: colorRating,
            aromaRating: aromaRating,
            hasInsectDamage: hasInsectDamage,
            hasFungus: hasFungus,
            isRipe: isRipe
        });

        qualityInspections[tokenId] = inspection;
        
        // 更新NFT质检信息
        durianNFT.updateQualityInfo(tokenId, grade, passed);
        
        if (!passed) {
            emit QualityAlert(tokenId, "QUALITY_FAILED");
        }
        
        // 发放质检奖励
        if (passed && score >= 85) {
            rewardSystem.distributeReward(
                tokenId, 
                4, 
                msg.sender, 
                score, 
                "High quality inspection performed"
            );
        }
        
        // 转移到包装阶段
        address packer = _getPacker();
        durianNFT.transferOwnershipStep(tokenId, packer, "QA to Packing", 3);
        
        emit QualityChecked(tokenId, msg.sender, passed, grade, score);
    }
    
    function _getPacker() private view returns (address) {
        // 简化实现
        return msg.sender;
    }
    
    function getQualityInspection(uint256 tokenId) public view returns (QualityInspection memory) {
        return qualityInspections[tokenId];
    }
    
    function isQualityPassed(uint256 tokenId) public view returns (bool) {
        return qualityInspections[tokenId].passed;
    }
}