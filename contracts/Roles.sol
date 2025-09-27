// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Roles is AccessControl {
    bytes32 public constant FARMER_ROLE = keccak256("FARMER_ROLE");
    bytes32 public constant PACKER_ROLE = keccak256("PACKER_ROLE");
    bytes32 public constant QA_ROLE = keccak256("QA_ROLE");
    bytes32 public constant LOGISTICS_ROLE = keccak256("LOGISTICS_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    event RoleGranted(bytes32 role, address account);
    event RoleRevoked(bytes32 role, address account);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        
        // 为部署者授予所有角色以便测试
        _grantRole(FARMER_ROLE, msg.sender);
        _grantRole(PACKER_ROLE, msg.sender);
        _grantRole(QA_ROLE, msg.sender);
        _grantRole(LOGISTICS_ROLE, msg.sender);
        _grantRole(RETAILER_ROLE, msg.sender);
    }

    function grantFarmerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(FARMER_ROLE, account);
        emit RoleGranted(FARMER_ROLE, account);
    }

    function grantPackerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(PACKER_ROLE, account);
        emit RoleGranted(PACKER_ROLE, account);
    }

    function grantQARole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(QA_ROLE, account);
        emit RoleGranted(QA_ROLE, account);
    }

    function grantLogisticsRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(LOGISTICS_ROLE, account);
        emit RoleGranted(LOGISTICS_ROLE, account);
    }

    function grantRetailerRole(address account) public onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(RETAILER_ROLE, account);
        emit RoleGranted(RETAILER_ROLE, account);
    }

    function hasSupplyChainRole(address account) public view returns (bool) {
        return hasRole(FARMER_ROLE, account) ||
               hasRole(PACKER_ROLE, account) ||
               hasRole(QA_ROLE, account) ||
               hasRole(LOGISTICS_ROLE, account) ||
               hasRole(RETAILER_ROLE, account);
    }

    function getRoleForAddress(address account) public view returns (string memory) {
        if (hasRole(FARMER_ROLE, account)) return "FARMER";
        if (hasRole(PACKER_ROLE, account)) return "PACKER";
        if (hasRole(QA_ROLE, account)) return "QA";
        if (hasRole(LOGISTICS_ROLE, account)) return "LOGISTICS";
        if (hasRole(RETAILER_ROLE, account)) return "RETAILER";
        if (hasRole(DEFAULT_ADMIN_ROLE, account)) return "ADMIN";
        return "NONE";
    }
}