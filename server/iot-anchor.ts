import { createThirdwebClient, getContract } from "thirdweb";
import { baseSepolia } from "thirdweb/chains";
import yargs from "yargs";
import { hideBin } from "yargs/helpers";

// from .env 
const SECRET = process.env.THIRDWEB_SECRET_KEY!;
const CONTRACT_ADDR = process.env.CONTRACT!;
if (!SECRET || !CONTRACT_ADDR) {
  console.error("Missing THIRDWEB_SECRET_KEY or CONTRACT in environment.");
  process.exit(1);
}

const argv = yargs(hideBin(process.argv))
  .option("batch", { type: "string", demandOption: true })
  .option("status", { type: "number", default: 3 }) // InTransit
  .option("eventURI", { type: "string", demandOption: true })
  .option("eventHash", { type: "string", demandOption: true })
  .parseSync();

const client = createThirdwebClient({ secretKey: SECRET });

const contract = getContract({
  client,
  address: CONTRACT_ADDR,
  chain: baseSepolia
});

async function main() {
  const tx = await contract.write({
    method: "updateStatus",
    params: [argv.batch, argv.status, argv.eventURI, argv.eventHash]
  });
  console.log("Anchored tx:", tx.transactionHash);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
