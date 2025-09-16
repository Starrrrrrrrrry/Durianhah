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

## Installation

### 1. Clone the repository
```bash
git clone https://github.com/Starrrrrrrrrry/FarmtoFork.git
cd FarmtoFork
```
---
### 2. Install dependencies
**contract**
```bash
cd contract
npm install
```
**web**
```bash
cd ../web
npm install
```
**server**
```bash
cd ../server
npm install
```
---
### 3. Configure environment variables
**web**
```env
VITE_THIRDWEB_CLIENT_ID=49f43f440b2e72aefa1ccb0af33dbf78
VITE_CONTRACT_ADDRESS=0xYourFarm2ForkContract
VITE_CHAIN_ID=84532  # Base Sepolia
```

**server**
```env
THIRDWEB_SECRET_KEY=<secret key>   
CONTRACT=0xYourFarm2ForkContract
CHAIN_ID=84532
```

### 4. Deploy contracts
```bash
npm run deploy -- --k <your-secret-key>
```
