// Toma's Divine Exchange - Aftersteel's Solana Devnet backend.
//
// Serves the web build and the wallet bridge from one localhost origin, and
// pays Devnet SOL from a server-held treasury for Divine fish that the server
// itself recorded:
//
//   1. Sign-in: the wallet signs a one-time message (no transaction); the
//      server verifies the ed25519 signature and issues a session token.
//   2. Catch: when Kiren casts with a wallet connected, the server rolls the
//      catch. A Divine result creates a claim record (unique id, owned by
//      that wallet). The client reports the landing; the server only accepts
//      it within a time window after the roll.
//   3. Redeem: one payout per landed claim. The transaction is signed and its
//      signature stored *before* it is sent, so a retry looks that signature
//      up on chain instead of paying again. The game removes the fish only
//      after the server reports the transfer confirmed.
//
// Devnet only: at start-up the RPC's genesis hash must be Solana Devnet's.
// The treasury secret comes from the environment and never leaves the server.

import http from "node:http";
import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import {
  Connection, Keypair, PublicKey, SystemProgram, Transaction, TransactionInstruction, LAMPORTS_PER_SOL,
} from "@solana/web3.js";
import bs58 from "bs58";
import nacl from "tweetnacl";

const HERE = path.dirname(fileURLToPath(import.meta.url));

export const DEVNET_GENESIS = "EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG";
const MEMO_PROGRAM = new PublicKey("MemoSq4gqABAXKb96qnH8TysNcWxMyWCqXgDLGmfcHr");
// What each Divine fish pays. The server's table is the one that counts.
export const PRICES_SOL = { voidfin: 0.01, celestail: 0.02 };
const DIVINE = Object.keys(PRICES_SOL);
const EXPLORER = (sig) => `https://explorer.solana.com/tx/${sig}?cluster=devnet`;

function env(name, fallback) {
  const v = process.env[name];
  return v === undefined || v === "" ? fallback : v;
}

export function loadConfig(overrides = {}) {
  const port = Number(overrides.port ?? env("PORT", "8787"));
  return {
    port,
    host: overrides.host ?? env("HOST", "127.0.0.1"),
    rpcUrl: overrides.rpcUrl ?? env("SOLANA_RPC_URL", "https://api.devnet.solana.com"),
    treasurySecret: overrides.treasurySecret ?? env("TREASURY_SECRET_KEY", ""),
    webRoot: path.resolve(HERE, overrides.webRoot ?? env("WEB_ROOT", "../build/web")),
    dataDir: path.resolve(HERE, overrides.dataDir ?? env("DATA_DIR", "./data")),
    publicOrigin: overrides.publicOrigin ?? env("PUBLIC_ORIGIN", `http://localhost:${port}`),
    demoMode: (overrides.demoMode ?? env("DEVNET_DEMO_MODE", "true")).toString() !== "false",
    maxPayoutsPerWallet: Number(overrides.maxPayoutsPerWallet ?? env("MAX_PAYOUTS_PER_WALLET", "5")),
    dailyBudgetSol: Number(overrides.dailyBudgetSol ?? env("DAILY_BUDGET_SOL", "1")),
    minLandMs: Number(overrides.minLandMs ?? env("MIN_LAND_MS", "3000")),
    maxLandMs: Number(overrides.maxLandMs ?? env("MAX_LAND_MS", String(15 * 60 * 1000))),
    rollCooldownMs: Number(overrides.rollCooldownMs ?? env("ROLL_COOLDOWN_MS", "2000")),
  };
}

export function parseSecret(secret) {
  if (!secret) throw new Error("TREASURY_SECRET_KEY is not set (run `npm run treasury:new`).");
  const s = secret.trim();
  const bytes = s.startsWith("[") ? Uint8Array.from(JSON.parse(s)) : bs58.decode(s);
  return Keypair.fromSecretKey(bytes);
}

// --- Claim records: one JSON file, written atomically --------------------
class ClaimStore {
  constructor(dir) {
    this.file = path.join(dir, "claims.json");
    fs.mkdirSync(dir, { recursive: true });
    this.data = fs.existsSync(this.file) ? JSON.parse(fs.readFileSync(this.file, "utf8")) : { claims: {} };
  }
  get(id) { return this.data.claims[id]; }
  put(record) {
    this.data.claims[record.id] = record;
    const tmp = this.file + ".tmp";
    fs.writeFileSync(tmp, JSON.stringify(this.data, null, 2));
    fs.renameSync(tmp, this.file);
  }
  all() { return Object.values(this.data.claims); }
}

export async function createServer(overrides = {}) {
  const cfg = loadConfig(overrides);
  const treasury = parseSecret(cfg.treasurySecret);
  const connection = new Connection(cfg.rpcUrl, "confirmed");

  // Never Mainnet: the cluster has to prove it is Devnet.
  const genesis = await connection.getGenesisHash();
  if (genesis !== DEVNET_GENESIS) {
    throw new Error(`Refusing to start: ${cfg.rpcUrl} is not Solana Devnet (genesis ${genesis}).`);
  }

  const store = new ClaimStore(cfg.dataDir);
  const nonces = new Map();      // nonce -> { wallet, message, expires }
  const sessions = new Map();    // token -> { wallet, expires }
  const lastRoll = new Map();    // wallet -> ms
  let queue = Promise.resolve(); // payouts run one at a time

  const allowedOrigins = new Set([cfg.publicOrigin, `http://localhost:${cfg.port}`, `http://127.0.0.1:${cfg.port}`]);

  function rollFish() {
    if (cfg.demoMode) return DIVINE[crypto.randomInt(DIVINE.length)];
    // The game's table: Divine is 2% of catches; the rest the game rolls itself.
    return crypto.randomInt(100) < 2 ? DIVINE[crypto.randomInt(DIVINE.length)] : "";
  }

  function paidToday() {
    const since = Date.now() - 24 * 3600 * 1000;
    return store.all().filter((c) => c.status === "paid" && c.paidAt >= since).reduce((s, c) => s + c.amountSol, 0);
  }

  async function settlePending(rec) {
    // A payout that was sent but not yet confirmed: look it up, never resend
    // while its blockhash could still land.
    const st = (await connection.getSignatureStatuses([rec.signature], { searchTransactionHistory: true })).value[0];
    if (st && !st.err && (st.confirmationStatus === "confirmed" || st.confirmationStatus === "finalized")) {
      Object.assign(rec, { status: "paid", paidAt: Date.now() });
      store.put(rec);
      return rec;
    }
    if (st && st.err) {
      Object.assign(rec, { status: "landed", signature: null, lastError: JSON.stringify(st.err) });
      store.put(rec);
      return rec;
    }
    const height = await connection.getBlockHeight("confirmed");
    if (!st && height > rec.lastValidBlockHeight) {
      Object.assign(rec, { status: "landed", signature: null, lastError: "expired" });
      store.put(rec);
    }
    return rec;
  }

  async function pay(rec) {
    const lamports = Math.round(rec.amountSol * LAMPORTS_PER_SOL);
    const to = new PublicKey(rec.wallet);
    const memo = `Aftersteel Divine Exchange: ${rec.fish} claim ${rec.id}`;
    const { blockhash, lastValidBlockHeight } = await connection.getLatestBlockhash("confirmed");
    const tx = new Transaction({ feePayer: treasury.publicKey, blockhash, lastValidBlockHeight }).add(
      SystemProgram.transfer({ fromPubkey: treasury.publicKey, toPubkey: to, lamports }),
      new TransactionInstruction({ programId: MEMO_PROGRAM, keys: [{ pubkey: treasury.publicKey, isSigner: true, isWritable: false }], data: Buffer.from(memo, "utf8") }),
    );
    tx.sign(treasury);
    const signature = bs58.encode(tx.signature);
    // Recorded before sending: from here on a retry checks this signature.
    Object.assign(rec, { status: "paying", signature, lastValidBlockHeight, attemptAt: Date.now() });
    store.put(rec);
    try {
      await connection.sendRawTransaction(tx.serialize(), { preflightCommitment: "confirmed", maxRetries: 5 });
    } catch (e) {
      const msg = String(e && e.message || e);
      if (/simulation failed|insufficient|no record of a prior credit/i.test(msg)) {
        // Preflight rejected it, so it was never broadcast.
        Object.assign(rec, { status: "landed", signature: null, lastError: msg.slice(0, 300) });
        store.put(rec);
        return { ok: false, error: "treasury_rejected", detail: msg.slice(0, 200) };
      }
      return { ok: true, status: "pending", signature };
    }
    try {
      const res = await connection.confirmTransaction({ signature, blockhash, lastValidBlockHeight }, "confirmed");
      if (res.value.err) {
        Object.assign(rec, { status: "landed", signature: null, lastError: JSON.stringify(res.value.err) });
        store.put(rec);
        return { ok: false, error: "transaction_failed" };
      }
    } catch (e) {
      await settlePending(rec);
      if (rec.status === "paying") return { ok: true, status: "pending", signature: rec.signature, explorer: EXPLORER(rec.signature) };
      // Expired without landing: nothing was paid, and the claim is open again.
      if (rec.status !== "paid") return { ok: false, error: "expired_retry" };
    }
    Object.assign(rec, { status: "paid", paidAt: Date.now() });
    store.put(rec);
    return null;
  }

  function paidReply(rec, already) {
    return { ok: true, status: "paid", already, claimId: rec.id, fish: rec.fish, amountSol: rec.amountSol, signature: rec.signature, explorer: EXPLORER(rec.signature), network: "devnet" };
  }

  async function redeem(wallet, claimId) {
    const rec = store.get(claimId);
    if (!rec || rec.wallet !== wallet) return { ok: false, error: "unknown_claim" };
    if (rec.status === "paid") return paidReply(rec, true);
    if (rec.status === "paying") {
      await settlePending(rec);
      if (rec.status === "paid") return paidReply(rec, true);
      if (rec.status === "paying") return { ok: true, status: "pending", signature: rec.signature, explorer: EXPLORER(rec.signature) };
    }
    if (rec.status !== "landed") return { ok: false, error: rec.status === "rolled" ? "not_landed" : "not_redeemable" };
    const paidCount = store.all().filter((c) => c.wallet === wallet && c.status === "paid").length;
    if (paidCount >= cfg.maxPayoutsPerWallet) return { ok: false, error: "wallet_limit" };
    if (paidToday() + rec.amountSol > cfg.dailyBudgetSol) return { ok: false, error: "daily_budget" };
    const failure = await pay(rec);
    if (failure) return failure;
    return paidReply(rec, false);
  }

  // --- HTTP ------------------------------------------------------------
  const MIME = { ".html": "text/html; charset=utf-8", ".js": "application/javascript", ".wasm": "application/wasm", ".pck": "application/octet-stream", ".png": "image/png", ".ico": "image/x-icon", ".json": "application/json", ".svg": "image/svg+xml" };

  function send(res, code, obj) {
    const body = JSON.stringify(obj);
    res.writeHead(code, { "Content-Type": "application/json", "Cache-Control": "no-store" });
    res.end(body);
  }

  function serveFile(res, file) {
    fs.stat(file, (err, st) => {
      if (err || !st.isFile()) { res.writeHead(404); res.end("Not found"); return; }
      const ext = path.extname(file).toLowerCase();
      res.writeHead(200, { "Content-Type": MIME[ext] || "application/octet-stream", "Content-Length": st.size, "Cache-Control": ext === ".html" || ext === ".js" ? "no-cache" : "public, max-age=60" });
      fs.createReadStream(file).pipe(res);
    });
  }

  function readJson(req) {
    return new Promise((resolve) => {
      let raw = "";
      req.on("data", (c) => { raw += c; if (raw.length > 16384) req.destroy(); });
      req.on("end", () => { try { resolve(raw ? JSON.parse(raw) : {}); } catch { resolve(null); } });
    });
  }

  function session(req) {
    const m = /^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization || "");
    const s = m && sessions.get(m[1]);
    if (!s || s.expires < Date.now()) return null;
    return s;
  }

  function validWallet(w) {
    try { return typeof w === "string" && PublicKey.isOnCurve(new PublicKey(w).toBytes()) ? new PublicKey(w).toBase58() : null; } catch { return null; }
  }

  const routes = {
    "GET /api/config": async () => ({ ok: true, network: "devnet", genesis, treasury: treasury.publicKey.toBase58(), pricesSol: PRICES_SOL, demoMode: cfg.demoMode }),

    "POST /api/auth/challenge": async (req, body) => {
      const wallet = validWallet(body.wallet);
      if (!wallet) return [400, { ok: false, error: "bad_wallet" }];
      const nonce = crypto.randomBytes(16).toString("hex");
      // Plain text on purpose: a message opening "<domain> wants you to sign in
      // with your Solana account:" is parsed by Phantom as Sign-In-With-Solana
      // and refused unless it follows that spec to the letter.
      const message = [
        "Aftersteel - Toma's Divine Exchange (Solana Devnet)", "",
        "Sign in with this wallet. This only proves you own it: it is not a transaction and costs nothing.", "",
        `Wallet: ${wallet}`, `Site: ${cfg.publicOrigin}`, "Network: devnet", `Nonce: ${nonce}`, `Issued: ${new Date().toISOString()}`,
      ].join("\n");
      nonces.set(nonce, { wallet, message, expires: Date.now() + 5 * 60 * 1000 });
      return { ok: true, nonce, message };
    },

    "POST /api/auth/verify": async (req, body) => {
      const n = nonces.get(body.nonce);
      nonces.delete(body.nonce);  // single use, pass or fail
      if (!n || n.expires < Date.now() || n.wallet !== body.wallet) return [401, { ok: false, error: "bad_nonce" }];
      let sig;
      try { sig = Buffer.from(String(body.signature), "base64"); } catch { sig = null; }
      const okSig = sig && sig.length === 64 && nacl.sign.detached.verify(new TextEncoder().encode(n.message), sig, new PublicKey(n.wallet).toBytes());
      if (!okSig) return [401, { ok: false, error: "bad_signature" }];
      const token = crypto.randomBytes(32).toString("hex");
      sessions.set(token, { wallet: n.wallet, expires: Date.now() + 2 * 3600 * 1000 });
      return { ok: true, token, wallet: n.wallet };
    },

    "GET /api/balance": async (req, body, s) => {
      const lamports = await connection.getBalance(new PublicKey(s.wallet), "confirmed");
      return { ok: true, wallet: s.wallet, sol: lamports / LAMPORTS_PER_SOL, network: "devnet" };
    },

    "POST /api/catch/roll": async (req, body, s) => {
      const now = Date.now();
      if (now - (lastRoll.get(s.wallet) || 0) < cfg.rollCooldownMs) return [429, { ok: false, error: "too_fast" }];
      lastRoll.set(s.wallet, now);
      const open = store.all().filter((c) => c.wallet === s.wallet && c.status === "rolled" && now - c.rolledAt < cfg.maxLandMs).length;
      if (open >= 3) return [429, { ok: false, error: "too_many_open_casts" }];
      const fish = rollFish();
      if (!fish) return { ok: true, divine: false };
      const rec = { id: crypto.randomUUID(), wallet: s.wallet, fish, amountSol: PRICES_SOL[fish], status: "rolled", rolledAt: now };
      store.put(rec);
      return { ok: true, divine: true, fish, claimId: rec.id };
    },

    "POST /api/catch/land": async (req, body, s) => {
      const rec = store.get(String(body.claimId));
      if (!rec || rec.wallet !== s.wallet) return [404, { ok: false, error: "unknown_claim" }];
      if (rec.status !== "rolled") return [409, { ok: false, error: "not_open" }];
      const held = Date.now() - rec.rolledAt;
      if (held < cfg.minLandMs) return [409, { ok: false, error: "too_quick" }];
      if (held > cfg.maxLandMs) return [409, { ok: false, error: "expired" }];
      Object.assign(rec, { status: "landed", landedAt: Date.now() });
      store.put(rec);
      return { ok: true, claimId: rec.id, fish: rec.fish, amountSol: rec.amountSol };
    },

    "POST /api/catch/escape": async (req, body, s) => {
      const rec = store.get(String(body.claimId));
      if (rec && rec.wallet === s.wallet && rec.status === "rolled") {
        Object.assign(rec, { status: "escaped", escapedAt: Date.now() });
        store.put(rec);
      }
      return { ok: true };
    },

    "POST /api/redeem": async (req, body, s) => {
      const claimId = String(body.claimId || "");
      const run = queue.then(() => redeem(s.wallet, claimId));
      queue = run.catch(() => {});
      return run;
    },
  };
  const OPEN = new Set(["GET /api/config", "POST /api/auth/challenge", "POST /api/auth/verify"]);

  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, cfg.publicOrigin);
    if (url.pathname.startsWith("/api/")) {
      const origin = req.headers.origin;
      if (req.method !== "GET" && origin && !allowedOrigins.has(origin)) return send(res, 403, { ok: false, error: "origin" });
      const key = `${req.method} ${url.pathname}`;
      const handler = routes[key];
      if (!handler) return send(res, 404, { ok: false, error: "not_found" });
      const body = req.method === "POST" ? await readJson(req) : {};
      if (body === null) return send(res, 400, { ok: false, error: "bad_json" });
      const s = session(req);
      if (!OPEN.has(key) && !s) return send(res, 401, { ok: false, error: "not_signed_in" });
      try {
        const out = await handler(req, body, s);
        const [code, reply] = Array.isArray(out) ? out : [200, out];
        // One line per call - never tokens, signatures or keys.
        console.log(`[api] ${key} -> ${code}${reply.error ? " " + reply.error : ""}${reply.status ? " " + reply.status : ""}${s ? " " + s.wallet.slice(0, 6) : ""}`);
        return send(res, code, reply);
      } catch (e) {
        console.error(key, e);
        return send(res, 500, { ok: false, error: "server_error" });
      }
    }
    if (url.pathname === "/wallet_bridge.js") return serveFile(res, path.join(HERE, "static", "wallet_bridge.js"));
    const rel = decodeURIComponent(url.pathname === "/" ? "/index.html" : url.pathname);
    const file = path.resolve(cfg.webRoot, "." + rel);
    if (!file.startsWith(cfg.webRoot + path.sep)) { res.writeHead(403); return res.end(); }
    serveFile(res, file);
  });

  return { server, cfg, treasury, connection, store, sessions, genesis };
}

// Started directly: `npm start`.
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    const app = await createServer();
    const bal = await app.connection.getBalance(app.treasury.publicKey, "confirmed");
    app.server.listen(app.cfg.port, app.cfg.host, () => {
      console.log(`Aftersteel Divine Exchange (Solana Devnet, genesis ${app.genesis.slice(0, 8)}...)`);
      console.log(`  game:     ${app.cfg.publicOrigin}/`);
      console.log(`  treasury: ${app.treasury.publicKey.toBase58()}  (${bal / LAMPORTS_PER_SOL} Devnet SOL)`);
      console.log(`  web root: ${app.cfg.webRoot}${fs.existsSync(path.join(app.cfg.webRoot, "index.html")) ? "" : "  (MISSING - export the game first)"}`);
      console.log(`  demo mode (every catch Divine): ${app.cfg.demoMode}`);
    });
  } catch (e) {
    console.error(String(e.message || e));
    process.exit(1);
  }
}
