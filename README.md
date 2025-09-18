#  Durianhah？ Project Runbook

---

## Step 1: Prerequisites

1. **Install required tools**
   - [Node.js (>=18)](https://nodejs.org/)  
   - [Git](https://git-scm.com/)  
   - [MetaMask Wallet](https://metamask.io/)  
   - [Thirdweb Account](https://thirdweb.com/)  

2. **Configure MetaMask**
   - Add the **Base Sepolia** test network.  
   - Get test ETH from a faucet.  
   - Copy your **wallet address**.  

3. **Configure Thirdweb**
   - Create a project in Thirdweb dashboard.  
   - Copy your **Client ID** (for frontend).  
   - Copy your **Secret Key** (for contract deployment & backend).  

---

## Step 2: GitHub / Code Setup

1. Create a new repository on GitHub called `FarmtoFork`.  
2. Add the following folder structure:  
   ```text
   FarmtoFork/
   ├─ contract/   # Smart contract
   ├─ web/        # React frontend dApp
   └─ server/     # Backend (IoT data anchoring, optional)
   ```
3. Place the provided code into the respective folders:

- contract/ → Solidity contract
- web/ → React frontend
- server/ → Node.js backend script

4. Clone repository locally(in terminal):
   ```bash
   git clone https://github.com/<github-username>/FarmtoFork.git
   cd FarmtoFork
   ```

---

## Step 3: Terminal Commands

1. deploy smart contract
    ```bash
    cd contract
    npm install
    npx thirdweb deploy --key <secretkey>
    ```
    - select **Base Sepolia**
    - constructor argument admin = MetaMask wallet address
    - copy the deployed **contract address(0x...)** in the output

2. Start frontend
   ```bash
    cd ../web
   npm install
   echo "VITE_CONTRACT_ADDRESS=0xYourContractAddress" > .env
   npm run dev
   ```
   - open http://localhost:5173
   - Click Connect Wallet to connect MetaMask (Base Sepolia)
   - Test querying a batch ID
  
3. Start Backend
   ```bash
   cd ../server
   npm install
   echo "THIRDWEB_SECRET_KEY=<your-SecretKey>" > .env
   echo "CONTRACT=0xYourContractAddress" >> .env
   npm run start -- --batch 0xBatchId32 --status 3 --eventURI ipfs://bafy... --eventHash 0xHash32
   ```

---

## Step 4: Thirdweb Dashboard
1. Go to thirdweb.com→ open your Dashboard.
2. Verify the deployed contract on Base Sepolia.
3. Use the Explorer to test contract functions (e.g. registerBatch, updateStatus).

---

## Step 5: MetaMask
1. Open MetaMask and switch to the Base Sepolia network.
2. Ensure you have test ETH (via faucet).
3. Connect your wallet in the frontend → approve transactions.

---

## Execution Summary
1. **Github**:Create repo → add code → clone locally.
2. **Terminal**:contract → web → server
3. **Thirdweb**: check deployed contract and test functions
4. **MetaMask**: Switch to Base Sepolia → get faucet ETH → connect frontend → approve tx.
