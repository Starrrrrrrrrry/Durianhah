// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./RewardSystem.sol";

/**
 * @title PackingPhase
 * @notice 记录并激励包装环节：
 *  - 仅 PACKER_ROLE 可执行包装记录；
 *  - 需要当前处于“包装阶段”(phase=3)；
 *  - 记录包装信息（箱号、等级、重量、封签、标签、照片/清单哈希等）；
 *  - 若满足基本准确性条件，则按策略发放 ERC-20 奖励；
 *  - 完成后把所有权/流转交接到物流（phase=4）。
 *
 * Assumptions（与 QualityCheckPhase 风格一致）：
 *  - DurianNFT 暴露 rolesContract()、getCurrentPhase(tokenId)、transferOwnershipStep(...)；
 *  - DurianNFT 提供 updatePackingInfo(tokenId, boxId, grade, passed)（如未实现，可按该签名新增）；
 *  - RewardSystem 提供 distributeReward(tokenId, phaseId, to, scoreOrWeight, memo)；
 */
contract PackingPhase {
    DurianNFT public durianNFT;
    RewardSystem public rewardSystem;

    /// @dev 包装信息结构体（字段设计与 “准确放入箱 + 正确记录特性” 目标对齐）
    struct PackingInfo {
        address packer;           // 记录人（包装工/打包员）
        uint256 timestamp;        // 记录时间
        string  boxId;            // 物理箱号/托盘号
        string  grade;            // 等级：如 "MSW AAA"、"MSW A"
        uint256 netWeightGrams;   // 净重（g）
        bytes32 manifestHash;     // 打包清单/照片集的哈希（IPFS CID 哈希或 keccak256）
        bool sealIntact;          // 封签完整
        bool labelApplied;        // 标签已贴（含二维码/追溯码）
        bool noDamage;            // 外观无明显损伤
        string notes;             // 备注（可选）
        bool passed;              // 简单通过判定（用作“准确性”的链上近似）
    }

    /// @notice tokenId => 包装记录
    mapping(uint256 => PackingInfo) public packingRecords;

    /// --------------------------- 事件 ---------------------------
    event Packed(
        uint256 indexed tokenId,
        address indexed packer,
        string boxId,
        string grade,
        uint256 netWeightGrams,
        bool sealIntact,
        bool labelApplied,
        bool noDamage
    );

    event PackingAlert(uint256 indexed tokenId, string alertType);

    event PackingRewarded(uint256 indexed tokenId, address indexed packer, uint256 amount, string memo);

    /// ------------------------- 构造函数 -------------------------
    constructor(address _nftContract, address _rewardContract) {
        durianNFT = DurianNFT(_nftContract);
        rewardSystem = RewardSystem(_rewardContract);
    }

    /**
     * @notice 执行包装记录（仅 PACKER 角色，且处于 phase=3）
     * @param tokenId          Durian NFT id
     * @param boxId            箱号/托盘号
     * @param grade            等级（示例：MSW AAA）
     * @param netWeightGrams   净重（g）
     * @param manifestHash     打包清单/照片等离链文件哈希（IPFS CID 哈希或 keccak256）
     * @param sealIntact       封签是否完整
     * @param labelApplied     是否已贴标签（含二维码/追溯码）
     * @param noDamage         外观是否无损伤
     * @param notes            备注
     */
    function performPacking(
        uint256 tokenId,
        string memory boxId,
        string memory grade,
        uint256 netWeightGrams,
        bytes32 manifestHash,
        bool sealIntact,
        bool labelApplied,
        bool noDamage,
        string memory notes
    ) public {
        // 角色校验：仅包装角色可操作（与 QualityCheckPhase 的 QA 角色校验同风格）
        require(
            durianNFT.rolesContract().hasRole(durianNFT.rolesContract().PACKER_ROLE(), msg.sender),
            "Only packers can record packing"
        );

        // 阶段校验：需处于“包装阶段”——与 QA 阶段转移的约定相衔接
        require(durianNFT.getCurrentPhase(tokenId) == 3, "Durian not ready for Packing (phase!=3)");

        // 基本准确性判定（链上近似）：重量>0 且 封签完整 且 已贴标签 且 无损伤
        bool passed = (netWeightGrams > 0) && sealIntact && labelApplied && noDamage;

        // 写入记录（覆盖式：一个 tokenId 仅保留最后一次包装记录；如需防重复可加 exists 标志）
        packingRecords[tokenId] = PackingInfo({
            packer: msg.sender,
            timestamp: block.timestamp,
            boxId: boxId,
            grade: grade,
            netWeightGrams: netWeightGrams,
            manifestHash: manifestHash,
            sealIntact: sealIntact,
            labelApplied: labelApplied,
            noDamage: noDamage,
            notes: notes,
            passed: passed
        });

        // 更新 NFT 的“包装信息”概览（保持与 QualityCheckPhase 的 updateQualityInfo 风格一致）
        // 需要在 DurianNFT 中提供对应函数签名：updatePackingInfo(tokenId, boxId, grade, passed)
        durianNFT.updatePackingInfo(tokenId, boxId, grade, passed);

        // 告警：若不通过，发出链上告警事件（供前端/风控订阅）
        if (!passed) {
            emit PackingAlert(tokenId, "PACKING_FAILED");
        }

        // 奖励策略（ERC-20）：通过则发放包装奖励
        // 这里复用 RewardSystem.distributeReward 的接口风格：
        // phaseId = 3（包装阶段）；scoreOrWeight 取净重或固定分值均可，这里用净重以示例
        if (passed) {
            uint256 paid = rewardSystem.distributeReward(
                tokenId,
                3,                // phaseId: Packing
                msg.sender,       // packer
                netWeightGrams,   // 作为分值或度量（你的 RewardSystem 可按内部规则换算）
                "Accurate packing recorded"
            );
            emit PackingRewarded(tokenId, msg.sender, paid, "Accurate packing recorded");
        }

        // 交接到物流：与 QualityCheckPhase 一致，调用 NFT 合约进行流转与阶段推进（phase=4）
        address logistics = _getLogistics(); // 这里简化：可替换为从角色合约或白名单读取真实物流地址
        durianNFT.transferOwnershipStep(tokenId, logistics, "Packing to Logistics", 4);

        emit Packed(tokenId, msg.sender, boxId, grade, netWeightGrams, sealIntact, labelApplied, noDamage);
    }

    /// @dev 获取物流地址（示例占位实现，按你的系统替换）
    function _getLogistics() private view returns (address) {
        // TODO: 可从 rolesContract() 查询一个 LOGISTICS_ROLE 默认地址，或从路由合约读取
        return msg.sender;
    }

    /// ---------------------------- 只读方法 ----------------------------
    function getPackingInfo(uint256 tokenId) public view returns (PackingInfo memory) {
        return packingRecords[tokenId];
    }

    function isPackingPassed(uint256 tokenId) public vi
