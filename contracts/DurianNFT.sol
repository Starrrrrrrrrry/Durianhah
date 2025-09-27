// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Roles.sol";

contract DurianNFT is ERC721, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    Roles public rolesContract;
    
    // 榴莲元数据结构
    struct DurianMetadata {
        string variety;           // 品种
        uint256 plantationDate;   // 种植日期
        uint256 harvestDate;      // 收获日期
        string plantationLocation;// 种植地点
        uint256 weight;           // 重量 (kg)
        string qualityGrade;      // 质量等级
        bool isQAPassed;          // 是否通过质检
        address currentHandler;   // 当前处理者
        uint256 currentPhase;     // 当前阶段
    }

    mapping(uint256 => DurianMetadata) public durianMetadata;
    mapping(uint256 => address[]) public ownershipHistory;
    mapping(uint256 => string[]) public phaseHistory;

    event DurianCreated(uint256 tokenId, string variety, address farmer);
    event OwnershipTransferred(uint256 tokenId, address from, address to, string phase);
    event PhaseUpdated(uint256 tokenId, uint256 phase, string phaseName);

    constructor(address _rolesContract) ERC721("DurianToken", "DURI") {
        rolesContract = Roles(_rolesContract);
        transferOwnership(msg.sender);
    }

    modifier onlySupplyChainMember() {
        require(rolesContract.hasSupplyChainRole(msg.sender), "Not a supply chain member");
        _;
    }

    // 种植阶段 - 创建榴莲NFT
    function plantDurian(
        string memory variety,
        string memory location,
        uint256 weight
    ) public onlySupplyChainMember returns (uint256) {
        require(rolesContract.hasRole(rolesContract.FARMER_ROLE(), msg.sender), "Only farmers can plant");
        
        _tokenIds.increment();
        uint256 newTokenId = _tokenIds.current();
        
        _mint(msg.sender, newTokenId);
        
        durianMetadata[newTokenId] = DurianMetadata({
            variety: variety,
            plantationDate: block.timestamp,
            harvestDate: 0,
            plantationLocation: location,
            weight: weight,
            qualityGrade: "",
            isQAPassed: false,
            currentHandler: msg.sender,
            currentPhase: 1
        });
        
        ownershipHistory[newTokenId].push(msg.sender);
        phaseHistory[newTokenId].push("Plantation");
        
        emit DurianCreated(newTokenId, variety, msg.sender);
        emit PhaseUpdated(newTokenId, 1, "Plantation");
        return newTokenId;
    }

    // 转移所有权（供应链环节转移）
    function transferOwnershipStep(
        uint256 tokenId, 
        address to, 
        string memory phaseName,
        uint256 newPhase
    ) public onlySupplyChainMember {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not owner of token");
        require(rolesContract.hasSupplyChainRole(to), "Recipient not in supply chain");

        address from = msg.sender;
        _transfer(from, to, tokenId);
        
        durianMetadata[tokenId].currentHandler = to;
        durianMetadata[tokenId].currentPhase = newPhase;
        ownershipHistory[tokenId].push(to);
        phaseHistory[tokenId].push(phaseName);
        
        emit OwnershipTransferred(tokenId, from, to, phaseName);
        emit PhaseUpdated(tokenId, newPhase, phaseName);
    }

    // 更新重量信息（收获后）
    function updateWeight(uint256 tokenId, uint256 newWeight) public {
        require(_exists(tokenId), "Token does not exist");
        require(ownerOf(tokenId) == msg.sender, "Not owner of token");
        require(rolesContract.hasRole(rolesContract.FARMER_ROLE(), msg.sender), "Only farmers can update weight");
        
        durianMetadata[tokenId].weight = newWeight;
        durianMetadata[tokenId].harvestDate = block.timestamp;
    }

    // 更新质检信息
    function updateQualityInfo(uint256 tokenId, string memory grade, bool passed) public {
        require(_exists(tokenId), "Token does not exist");
        require(rolesContract.hasRole(rolesContract.QA_ROLE(), msg.sender), "Only QA can update quality");
        
        durianMetadata[tokenId].qualityGrade = grade;
        durianMetadata[tokenId].isQAPassed = passed;
    }

    function getOwnershipHistory(uint256 tokenId) public view returns (address[] memory) {
        return ownershipHistory[tokenId];
    }

    function getPhaseHistory(uint256 tokenId) public view returns (string[] memory) {
        return phaseHistory[tokenId];
    }

    function getDurianMetadata(uint256 tokenId) public view returns (DurianMetadata memory) {
        require(_exists(tokenId), "Token does not exist");
        return durianMetadata[tokenId];
    }

    function getCurrentPhase(uint256 tokenId) public view returns (uint256) {
        require(_exists(tokenId), "Token does not exist");
        return durianMetadata[tokenId].currentPhase;
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        return _ownerOf(tokenId) != address(0);
    }
}