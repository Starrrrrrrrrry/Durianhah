import { ThirdwebProvider, ConnectButton, useContract } from "thirdweb/react";
import { baseSepolia } from "thirdweb/chains";
import { client } from "./client";
import { useState } from "react";

const CONTRACT = import.meta.env.VITE_CONTRACT_ADDRESS || "0xYourDeployedContract";

export default function App() {
  return (
    <ThirdwebProvider client={client} activeChain={baseSepolia}>
      <div style={{ maxWidth: 720, margin: "40px auto", padding: 16 }}>
        <h1>Farm2Fork — Traceability</h1>
        <ConnectButton />
        <TraceCard />
      </div>
    </ThirdwebProvider>
  );
}

function TraceCard() {
  const [batchId, setBatchId] = useState("");
  const [info, setInfo] = useState<any>(null);
  const { contract } = useContract({ address: CONTRACT });

  async function query() {
    if (!contract || !batchId) return;
    const res = await contract.read("batches", [batchId]);
    setInfo(res);
  }

  return (
    <div style={{ marginTop: 24, padding: 16, border: "1px solid #ddd", borderRadius: 12 }}>
      <h2>Query Batch</h2>
      <input
        placeholder="0x... (bytes32 batchId)"
        value={batchId}
        onChange={(e) => setBatchId(e.target.value)}
        style={{ width: "100%", padding: 10, marginTop: 8 }}
      />
      <button onClick={query} style={{ marginTop: 12, padding: "8px 16px" }}>Query</button>
      {info && (
        <pre style={{ marginTop: 12, whiteSpace: "pre-wrap", wordBreak: "break-all" }}>
{JSON.stringify(info, null, 2)}
        </pre>
      )}
    </div>
  );
}
