// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./RewardSystem.sol";

/**
 * @title LogisticsPhase
 * @notice 物流环节记录与激励（与 QualityCheckPhase 模版同风格）：
 *  - 仅 LOGISTICS_ROLE 可记录物流信息；
 *  - 要求当前阶段为 4（Packing -> Logistics）；
 *  - 记录起运/到达时间、温度摘要（min/max/avg，单位：0.1℃）、传感器哈希、车辆ID、备注；
 *  - 温度在阈值内则“通过”，可发放 ERC-20 奖励（通过 RewardSystem）；
 *  - 完成后移交至零售阶段（phase=5）。
 *
 * 说明：
 *  - 温度阈值以 0.1℃ 存储：例如 -50 表示 -5.0℃，100 表示 10.0℃；
 *  - RewardSystem.distributeReward(tokenId, phaseId, to, score, memo)：
 *      这里将 score 设为运输时长（秒），便于你在 RewardSystem 中按“时长 × 系数”或其它规则换算。
 */
contract LogisticsPhase {
    DurianNFT public durianNFT;
    RewardSystem public rewardSystem;

    // 温度阈值（单位：0.1℃）
    int16 public minAllowedTemp;  // 例如 -50 => -5.0℃
    int16 public maxAllowedTemp;  // 例如  100 => 10.0℃

    struct LogisticsRecord {
        address operator;       // 记录人（物流方）
        uint256 timestamp;      // 上链时间（记录时间）
        uint64  startTime;      // 起运时间（Unix）
        uint64  endTime;        // 到达时间（Unix）
        int16   minTemp;        // 最低温（0.1℃）
        int16   maxTemp;        // 最高温（0.1℃）
        int16   avgTemp;        // 平均温（0.1℃）
        bytes32 tempProofHash;  // 传感器原始数据文件哈希（如 IPFS CID 哈希或 keccak256）
        string  vehicleId;      // 车辆/箱号等标识
        string  notes;          // 备注
        bool    passed;         // 是否通过（温度在阈值内）
    }

    // 每个 tokenId 保存一次物流记录（与 QA/Packing 单记录风格一致）
    mapping(uint256 => LogisticsRecord) public logisticsOf;

    /* ------------------------------- 事件 ------------------------------- */
    event LogisticsRecorded(
        uint256 indexed tokenId,
        address indexed operator,
        uint64 startTime,
        uint64 endTime,
        int16 minTemp,
        int16 maxTemp,
        int16 avgTemp,
        bool passed
    );

    event LogisticsAlert(uint256 indexed tokenId, string alertType);

    event LogisticsRewarded(
        uint256 indexed tokenId,
        address indexed to,
        uint256 amount,
        string memo
    );

    /* ----------------------------- 构造函数 ----------------------------- */
    constructor(
        address _nftContract,
        address _rewardContract,
        int16 _minAllowedTemp,
        int16 _maxAllowedTemp
    ) {
        require(_nftContract != address(0) && _rewardContract != address(0), "ZERO_ADDR");
        require(_minAllowedTemp < _maxAllowedTemp, "BAD_THRESHOLDS");
        durianNFT = DurianNFT(_nftContract);
        rewardSystem = RewardSystem(_rewardContract);
        minAllowedTemp = _minAllowedTemp;
        maxAllowedTemp = _maxAllowedTemp;
    }

    /* ------------------------------ 管理员 ------------------------------ */
    function setTempThresholds(int16 minT, int16 maxT) external {
        // 简化：沿用 NFT 的 DEFAULT_ADMIN 体系（与项目一致时可单独做 Ownable）
        require(
            durianNFT.rolesContract().hasRole(durianNFT.rolesContract().DEFAULT_ADMIN_ROLE(), msg.sender),
            "Only admin can set thresholds"
        );
        require(minT < maxT, "BAD_THRESHOLDS");
        minAllowedTemp = minT;
        maxAllowedTemp = maxT;
    }

    /**
     * @notice 记录一条物流信息（仅 LOGISTICS 角色；phase 必须为 4）
     * @param tokenId       Durian NFT id
     * @param startTime     起运 Unix 时间戳（秒）
     * @param endTime       到达 Unix 时间戳（秒），必须 >= startTime
     * @param minTemp       最低温（单位：0.1℃）
     * @param maxTemp       最高温（单位：0.1℃）
     * @param avgTemp       平均温（单位：0.1℃）
     * @param tempProofHash 传感器原始文件哈希（IPFS CID 哈希或 keccak256）
     * @param vehicleId     车辆/箱号
     * @param notes         备注
     */
    function performLogisticsRecord(
        uint256 tokenId,
        uint64 startTime,
        uint64 endTime,
        int16 minTemp,
        int16 maxTemp,
        int16 avgTemp,
        bytes32 tempProofHash,
        string memory vehicleId,
        string memory notes
    ) public {
        // 1) 角色校验：仅 LOGISTICS_ROLE
        require(
            durianNFT.rolesContract().hasRole(durianNFT.rolesContract().LOGISTICS_ROLE(), msg.sender),
            "Only logistics can record"
        );

        // 2) 阶段校验：必须是物流阶段（4）
        require(durianNFT.getCurrentPhase(tokenId) == 4, "Durian not in Logistics phase (4)");

        // 3) 基本时间有效性
        require(endTime >= startTime && endTime > 0 && startTime > 0, "Bad time range");

        // 4) 是否通过：温度在阈值内
        bool passed = (minTemp >= minAllowedTemp && maxTemp <= maxAllowedTemp);

        // 5) 记录入库（与 QA / Packing 一致：覆盖式保存最新记录）
        logisticsOf[tokenId] = LogisticsRecord({
            operator: msg.sender,
            timestamp: block.timestamp,
            startTime: startTime,
            endTime: endTime,
            minTemp: minTemp,
            maxTemp: maxTemp,
            avgTemp: avgTemp,
            tempProofHash: tempProofHash,
            vehicleId: vehicleId,
            notes: notes,
            passed: passed
        });

        // 6) 更新 NFT 的物流信息概要（建议与 QA/Packing 同风格）
        // 在 DurianNFT 中补充：updateLogisticsInfo(tokenId, passed, minTemp, maxTemp)
        durianNFT.updateLogisticsInfo(tokenId, passed, minTemp, maxTemp);

        // 7) 告警分支
        if (!passed) {
            emit LogisticsAlert(tokenId, "TEMP_BREACH");
        }
        if (tempProofHash == bytes32(0)) {
            emit LogisticsAlert(tokenId, "MISSING_TEMP_PROOF");
        }

        // 8) 计算奖励并发放（phaseId = 4，score 取运输时长秒数）
        uint256 durationSec = uint256(endTime - startTime);
        if (passed) {
            uint256 paid = rewardSystem.distributeReward(
                tokenId,
                4,                 // phaseId: Logistics
                msg.sender,        // 物流操作方
                durationSec,       // 作为得分/权重交给 RewardSystem
                "Cold-chain compliant logistics"
            );
            emit LogisticsRewarded(tokenId, msg.sender, paid, "Cold-chain compliant logistics");
        }

        // 9) 物流 -> 零售：移交所有权/阶段推进到 5（Retail）
        address retailer = _getRetailer();
        durianNFT.transferOwnershipStep(tokenId, retailer, "Logistics to Retail", 5);

        // 10) 事件
        emit LogisticsRecorded(tokenId, msg.sender, startTime, endTime, minTemp, maxTemp, avgTemp, passed);
    }

    // 占位实现：可替换为从角色合约/路由合约/白名单读取实际零售地址
    function _getRetailer() private view returns (address) {
        return msg.sender;
    }

    /* ------------------------------- 只读 ------------------------------- */
    function getLogisticsRecord(uint256 tokenId) public view returns (LogisticsRecord memory) {
        return logisticsOf[tokenId];
    }

    function isLogisticsPassed(uint256 tokenId) public view returns (bool) {
        return logisticsOf[tokenId].passed;
    }
}
