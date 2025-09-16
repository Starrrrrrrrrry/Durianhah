# Farm2Fork – Web3 Supply Chain Traceability

---

## Implementation

### Prerequisites
- Node.js (version ≥ 20.x)
- npm (version ≥ 10.x)
- Metamask
- Thirdweb
- Go to [Base Sepolia Faucet](https://www.alchemy.com/faucets/base-sepolia) and claim some test tokens with your Metamask wallet address
- **Client ID**
- **Secret Key** from Thirdweb (backend/IoT use)

---

## Installation (run in Terminal)

### 1. Clone the repository
```bash
git clone https://github.com/Starrrrrrrrrry/FarmtoFork.git
cd FarmtoFork
```
---
### 2. Contract part
```bash
cd contract
npm install
npx thirdweb deploy --key <SecretKey>
```
- when deploy, choosing Base Sepolia
- Creat function 'admin' with your MetaMask wallet address
- after deploying success,recording outputs' **contract address (0x...)**
---
### 3. Web part
```bash
cd ../web
npm install
echo "VITE_CONTRACT_ADDRESS=0xcontract address" > .env
npm run dev
```
- open: http://localhost:5173
- connect with MetaMask, using Base Sepolia network

### 4. Server part
```bash
cd ../server
npm install
echo "THIRDWEB_SECRET_KEY=<SecretKey>" > .env
echo "CONTRACT=0xcontract address" >> .env
npm run start -- --batch 0xBatchId32 --status 3 --eventURI ipfs://bafy... --eventHash 0xHash32
```

### 5. Termination
press Ctrl+C to stop
