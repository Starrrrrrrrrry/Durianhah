// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Farm2Fork is AccessControl {
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant DISTRIBUTOR_ROLE = keccak256("DISTRIBUTOR_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    enum Status { Created, Harvested, Processed, InTransit, Warehoused, OnShelf, Recalled }

    struct Batch {
        string productName;
        string farmId;
        uint256 createdAt;
        Status status;
        string metadataURI; // ipfs://...
        bytes32 dataHash;   // keccak256(raw)
        address owner;
        bool exists;
    }

    mapping(bytes32 => Batch) public batches;

    event BatchRegistered(bytes32 indexed batchId, string productName, string farmId, string metadataURI, bytes32 dataHash);
    event StatusUpdated(bytes32 indexed batchId, Status status, address indexed actor, string eventURI, bytes32 eventHash);
    event OwnershipTransferred(bytes32 indexed batchId, address from, address to);

    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(REGULATOR_ROLE, admin);
    }

    function registerBatch(
        bytes32 batchId,
        string calldata productName,
        string calldata farmId,
        string calldata metadataURI,
        bytes32 dataHash
    ) external onlyRole(FARMER_ROLE) {
        require(!batches[batchId].exists, "batch exists");
        batches[batchId] = Batch({
            productName: productName,
            farmId: farmId,
            createdAt: block.timestamp,
            status: Status.Created,
            metadataURI: metadataURI,
            dataHash: dataHash,
            owner: msg.sender,
            exists: true
        });
        emit BatchRegistered(batchId, productName, farmId, metadataURI, dataHash);
    }

    function updateStatus(
        bytes32 batchId,
        Status nextStatus,
        string calldata eventURI,
        bytes32 eventHash
    ) external {
        require(batches[batchId].exists, "no batch");
        require(hasRole(REGULATOR_ROLE, msg.sender) || msg.sender == batches[batchId].owner, "not permitted");
        require(uint(nextStatus) >= uint(batches[batchId].status), "invalid status");
        batches[batchId].status = nextStatus;
        emit StatusUpdated(batchId, nextStatus, msg.sender, eventURI, eventHash);
    }

    function transferOwnership(bytes32 batchId, address to) external {
        require(batches[batchId].exists, "no batch");
        require(msg.sender == batches[batchId].owner || hasRole(REGULATOR_ROLE, msg.sender), "not permitted");
        address from = batches[batchId].owner;
        batches[batchId].owner = to;
        emit OwnershipTransferred(batchId, from, to);
    }

    function grantSupplyRole(bytes32 role, address account) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            role == FARMER_ROLE || role == DISTRIBUTOR_ROLE || role == RETAILER_ROLE || role == REGULATOR_ROLE,
            "bad role"
        );
        _grantRole(role, account);
    }
}

