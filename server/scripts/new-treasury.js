// Creates the Devnet treasury keypair and stores its secret in server/.env
// (git-ignored). Prints only the public key. Refuses to replace an existing
// TREASURY_SECRET_KEY.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { Keypair } from "@solana/web3.js";
import bs58 from "bs58";

const envFile = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", ".env");
const current = fs.existsSync(envFile) ? fs.readFileSync(envFile, "utf8") : "";

if (/^TREASURY_SECRET_KEY=.+/m.test(current)) {
  console.log("server/.env already has a TREASURY_SECRET_KEY - left unchanged.");
  process.exit(0);
}

const kp = Keypair.generate();
const lines = [
  "# Aftersteel Divine Exchange - LOCAL ONLY, never commit (git-ignored).",
  "# Devnet treasury that pays the Divine Exchange. Fund it at https://faucet.solana.com",
  `TREASURY_SECRET_KEY=${bs58.encode(kp.secretKey)}`,
  "SOLANA_RPC_URL=https://api.devnet.solana.com",
  "PORT=8787",
  "",
];
fs.writeFileSync(envFile, (current ? current.trimEnd() + "\n" : "") + lines.join("\n"), { mode: 0o600 });
console.log("Treasury created (secret written to server/.env).");
console.log(`Treasury public key: ${kp.publicKey.toBase58()}`);
console.log("Fund it with Devnet SOL: npm run treasury:fund  (or https://faucet.solana.com)");
