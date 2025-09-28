// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DurianNFT.sol";
import "./RewardSystem.sol";

/**
 * @title RetailPhase
 * @notice 零售上架环节记录与 ERC-20 激励（与 QualityCheckPhase 模版同风格）：
 *  - 仅 RETAILER_ROLE 可记录零售信息；
 *  - 要求当前阶段为 5（Logistics -> Retail）；
 *  - 记录上架时间、门店/货架、价格（最小货币单位，如分）、促销标签、QR 可扫描、现场材料哈希等；
 *  - 只要完成有效“上架记录”（listedAt>0 且 QR 可扫描）即通过并发放奖励；
 *  - 完成后移交至消费者/售出阶段（phase=6）。
 *
 * 奖励接口：
 *  - RewardSystem.distributeReward(tokenId, phaseId, to, score, memo)
 *    这里将 score 固定传入 1（“每次上架一次性奖励”），你也可以改为 priceCents 或其它度量。
 */
contract RetailPhase {
    DurianNFT public durianNFT;
    RewardSystem public rewardSystem;

    struct RetailRecord {
        address retailer;       // 记录人（零售方）
        uint256 timestamp;      // 上链时间
        uint64  listedAt;       // 上架时间（Unix）
        string  storeId;        // 门店/摊位/渠道标识
        string  shelfId;        // 货架/位置标识（可选）
        uint256 priceCents;     // 价格（以最小法币单位，例如“分”）
        bool    promoLabel;     // 是否贴了促销/品质标签
        bool    qrScannable;    // QR/追溯码是否可扫描
        bytes32 retailProofHash;// 现场照片/收银联/陈列合规单等离链文件哈希（IPFS CID 哈希或 keccak256）
        string  notes;          // 备注
        bool    passed;         // 是否通过（上架有效且可扫码）
    }

    // 每个 tokenId 保存一条零售记录（与其他阶段保持单记录覆盖风格）
    mapping(uint256 => RetailRecord) public retailOf;

    /* ------------------------------- 事件 ------------------------------- */
    event RetailListed(
        uint256 indexed tokenId,
        address indexed retailer,
        uint64 listedAt,
        string storeId,
        uint256 priceCents,
        bool qrScannable,
        bool passed
    );

    event RetailAlert(uint256 indexed tokenId, string alertType);

    event RetailRewarded(
        uint256 indexed tokenId,
        address indexed to,
        uint256 amount,
        string memo
    );

    /* ----------------------------- 构造函数 ----------------------------- */
    constructor(
        address _nftContract,
        address _rewardContract
    ) {
        require(_nftContract != address(0) && _rewardContract != address(0), "ZERO_ADDR");
        durianNFT = DurianNFT(_nftContract);
        rewardSystem = RewardSystem(_rewardContract);
    }

    /**
     * @notice 记录一条零售上架（仅 RETAILER 角色；phase 必须为 5）
     * @param tokenId        Durian NFT id
     * @param listedAt       上架 Unix 时间戳（秒）
     * @param storeId        门店/摊位标识
     * @param shelfId        货架/位置标识（可选）
     * @param priceCents     价格（以最小法币单位，如分；若无可填 0）
     * @param promoLabel     是否贴促销/品质标签
     * @param qrScannable    QR/追溯码是否可扫描
     * @param retailProofHash 现场材料哈希（照片/陈列单/收银联等，IPFS CID 哈希或 keccak256）
     * @param notes          备注
     */
    function performRetailListing(
        uint256 tokenId,
        uint64 listedAt,
        string memory storeId,
        string memory shelfId,
        uint256 priceCents,
        bool promoLabel,
        bool qrScannable,
        bytes32 retailProofHash,
        string memory notes
    ) public {
        // 1) 角色校验：仅 RETAILER_ROLE
        require(
            durianNFT.rolesContract().hasRole(durianNFT.rolesContract().RETAILER_ROLE(), msg.sender),
            "Only retailers can record"
        );

        // 2) 阶段校验：必须是零售阶段（5）
        require(durianNFT.getCurrentPhase(tokenId) == 5, "Durian not in Retail phase (5)");

        // 3) 基本有效性：上架时间有效、二维码可扫
        require(listedAt > 0, "Invalid listedAt");
        bool passed = qrScannable; // 简化：可扫码即通过；你也可加入更多条件（如价格下限）

        // 4) 覆盖式写入记录
        retailOf[tokenId] = RetailRecord({
            retailer: msg.sender,
            timestamp: block.timestamp,
            listedAt: listedAt,
            storeId: storeId,
            shelfId: shelfId,
            priceCents: priceCents,
            promoLabel: promoLabel,
            qrScannable: qrScannable,
            retailProofHash: retailProofHash,
            notes: notes,
            passed: passed
        });

        // 5) 更新 NFT 的零售信息概要（建议在 DurianNFT 中实现该函数）
        // 形如：function updateRetailInfo(uint256 tokenId, string calldata storeId, bool passed, uint64 listedAt, uint256 priceCents) external;
        durianNFT.updateRetailInfo(tokenId, storeId, passed, listedAt, priceCents);

        // 6) 告警：若二维码不可扫或无证明材料，抛出告警事件供前端/风控订阅
        if (!qrScannable) {
            emit RetailAlert(tokenId, "QR_NOT_SCANNABLE");
        }
        if (retailProofHash == bytes32(0)) {
            emit RetailAlert(tokenId, "MISSING_RETAIL_PROOF");
        }

        // 7) 发放零售上架奖励（phaseId = 5；score 传 1 表示“一次上架一次奖励”）
        if (passed) {
            uint256 paid = rewardSystem.distributeReward(
                tokenId,
                5,               // phaseId: Retail
                msg.sender,      // 零售记录方
                1,               // 可改为 priceCents 或其它度量
                "Retail listing recorded"
            );
            emit RetailRewarded(tokenId, msg.sender, paid, "Retail listing recorded");
        }

        // 8) 零售 -> 消费者/售出阶段（phase=6）：按你的业务定义命名
        address consumer = _getConsumer(); // 占位：可替换为订单/收银系统对接地址
        durianNFT.transferOwnershipStep(tokenId, consumer, "Retail to Consumer", 6);

        // 9) 事件：记录上架详情
        emit RetailListed(tokenId, msg.sender, listedAt, storeId, priceCents, qrScannable, passed);
    }

    // 占位实现：按需替换为从订单/支付/会员系统获取真实消费者地址
    function _getConsumer() private view returns (address) {
        return msg.sender;
    }

    /* ------------------------------- 只读 ------------------------------- */
    function getRetailRecord(uint256 tokenId) public view returns (RetailRecord memory) {
        return retailOf[tokenId];
    }

    function isRetailPassed(uint256 tokenId) public view returns (bool) {
        return retailOf[tokenId].passed;
    }
}
