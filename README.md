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
```bash
cd contract && npm install && cd ..
cd server   && npm install && cd ..
cd web      && npm install && cd ..
```
---
### 3. Configure environment variables
**contract**
```env
DEPLOYER_ADDRESS=0x<YourMetamaskAddress>
PRIVATE_KEY=your_metamask_private_key
BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY>

```
**web**
```env
VITE_THIRDWEB_CLIENT_ID=49f43f440b2e72aefa1ccb0af33dbf78
VITE_CONTRACT_ADDRESS=0x<YourFarm2ForkContract>
VITE_CHAIN_ID=84532
```

**server**
```env
THIRDWEB_SECRET_KEY=<your_thirdweb_secret_key>
CONTRACT=0xYourFarm2ForkContract
CHAIN_ID=84532
BASE_SEPOLIA_RPC_URL=https://base-sepolia.g.alchemy.com/v2/<YOUR_ALCHEMY_KEY>
```

### 4. Deploy the smart contracts
```bash
cd contract
npm run deploy -- --k <your_thirdweb_secret_key>
```

### 5. Run the frontend
```bash
cd web
npm run dev
```
