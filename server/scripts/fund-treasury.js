// Asks the Devnet faucet for SOL for the treasury and prints its balance.
// Devnet only; the public faucet is rate-limited, so this may be refused -
// then use https://faucet.solana.com with the printed address.
import { Connection, LAMPORTS_PER_SOL } from "@solana/web3.js";
import { parseSecret, DEVNET_GENESIS } from "../server.js";

const rpc = process.env.SOLANA_RPC_URL || "https://api.devnet.solana.com";
const conn = new Connection(rpc, "confirmed");
if ((await conn.getGenesisHash()) !== DEVNET_GENESIS) {
  console.error(`${rpc} is not Solana Devnet - refusing.`);
  process.exit(1);
}
const kp = parseSecret(process.env.TREASURY_SECRET_KEY);
const who = kp.publicKey.toBase58();
console.log(`Treasury: ${who}`);
try {
  const sig = await conn.requestAirdrop(kp.publicKey, Number(process.argv[2] || 1) * LAMPORTS_PER_SOL);
  const bh = await conn.getLatestBlockhash("confirmed");
  await conn.confirmTransaction({ signature: sig, ...bh }, "confirmed");
  console.log(`Airdrop confirmed: https://explorer.solana.com/tx/${sig}?cluster=devnet`);
} catch (e) {
  console.log(`Airdrop refused (${String(e.message || e).slice(0, 120)}).`);
  console.log(`Fund it by hand at https://faucet.solana.com - address ${who}, network Devnet.`);
}
console.log(`Balance: ${(await conn.getBalance(kp.publicKey, "confirmed")) / LAMPORTS_PER_SOL} Devnet SOL`);
