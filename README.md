#  Durianhah？ Project Runbook

---
## Project Overview
   This runbook describes how to implement a blockchain-based traceability system for durians, using ERC721 NFT Collection contracts deployed via ThirdWeb. 
   
   Each durian (or batch) is represented as a unique NFT that records its journey across six supply chain stages: Production, Collection, Packing, QA, Logistics, and Retail. IoT devices are integrated at key steps to provide trustworthy data.
   
## Step 1: Prerequisites

1. **BlockChain Tools**: ThirdWeb (contract deployment & SDK)
2. **Wallet**: Metamask
3. **Environment**: Node.js,Hardhat/Foundry(for local testing)
4. **IoT intergration**: Raspberry Pi, GPS, temperature/humidity sensors(for data collection).

---

## Step 2: Smart Contract Setup (ERC721 Collection)

- Deploy a **ThirdWeb ERC721 NFT Collection** contract. 
- Metadata structure:
   ```json
      {
     "name": "Durian #001",
     "origin": "Pahang, Malaysia",
     "stage": "Production",
     "iotData": {
       "temperature": "28°C",
       "humidity": "70%",
       "timestamp": "2025-09-18T10:00:00Z"
        }
      }
   ```
- Each NFT = 1 Durian

---

## Step 3: Supply Chain Workflow

1. 🏡 Production
2. 📥 Collection
3. 📦 Packing
4. 🔍 QA (Quality Assurance)
5. 🚚 Logistics
6. 🛒 Retail

---

## Step 4: IoT Integration Flow
1. IoT sensor collects raw data.
2. Data is signed & stored in database (e.g., IPFS).
3. Hash of data is pushed to blockchain via smart contract.
4. NFT metadata is updated with a new supply chain stage.

---

## Step 5: Frontend Integration
- Use ThirdWeb SDK in React/Next.js to:
   - Mint NFTs for new durians.
   - Update metadata as supply chain progresses.
   - Display QR scan results for consumers.

---

## Step 6: Github Repo Structure
   ```bash
   /durianhah
  ├── contracts/
  │     └── DurianNFT.sol
  ├── scripts/
  │     └── deploy.js
  │     └── updateStage.js
  ├── frontend/
  │     └── pages/
  │     └── components/
  ├── README.md
   ```
