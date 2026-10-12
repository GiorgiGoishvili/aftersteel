// End-to-end tests of the Divine Exchange server against real Solana Devnet.
// A locally generated keypair plays the wallet: it signs the same sign-in
// message Phantom would. Payout tests need a funded treasury (server/.env);
// without funds they check the refusal path instead.
//   npm test
import { test, before, after } from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import nacl from "tweetnacl";
import { Keypair, LAMPORTS_PER_SOL, PublicKey } from "@solana/web3.js";
import { createServer } from "../server.js";

let app, base, funded;
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

before(async () => {
  const dataDir = fs.mkdtempSync(path.join(os.tmpdir(), "aftersteel-claims-"));
  app = await createServer({ port: 0, dataDir, minLandMs: 400, rollCooldownMs: 0 });
  await new Promise((r) => app.server.listen(0, "127.0.0.1", r));
  base = `http://127.0.0.1:${app.server.address().port}`;
  funded = (await app.connection.getBalance(app.treasury.publicKey, "confirmed")) >= 0.05 * LAMPORTS_PER_SOL;
});

after(() => app && app.server.close());

async function call(pathname, body, token, origin) {
  const headers = { "Content-Type": "application/json" };
  if (token) headers.Authorization = `Bearer ${token}`;
  if (origin) headers.Origin = origin;
  const res = await fetch(base + pathname, { method: body === undefined ? "GET" : "POST", headers, body: body === undefined ? undefined : JSON.stringify(body) });
  return { ...(await res.json()), http: res.status };
}

async function signIn(kp = Keypair.generate()) {
  const wallet = kp.publicKey.toBase58();
  const ch = await call("/api/auth/challenge", { wallet });
  assert.equal(ch.ok, true);
  const sig = nacl.sign.detached(new TextEncoder().encode(ch.message), kp.secretKey);
  const v = await call("/api/auth/verify", { wallet, nonce: ch.nonce, signature: Buffer.from(sig).toString("base64") });
  assert.equal(v.ok, true, JSON.stringify(v));
  return { kp, wallet, token: v.token };
}

async function landedClaim(token) {
  const roll = await call("/api/catch/roll", {}, token);
  assert.equal(roll.ok, true);
  assert.equal(roll.divine, true, "demo mode: every server roll is Divine");
  await sleep(450);
  const land = await call("/api/catch/land", { claimId: roll.claimId }, token);
  assert.equal(land.ok, true, JSON.stringify(land));
  return roll;
}

test("config says Devnet, with the demo prices", async () => {
  const c = await call("/api/config");
  assert.equal(c.network, "devnet");
  assert.equal(c.genesis, "EtWTRABZaYq6iMfeYKouRu166VU2xqa1wcaWoxPkrZBG");
  assert.deepEqual(c.pricesSol, { voidfin: 0.01, celestail: 0.02 });
});

test("sign-in needs a valid signature over a fresh, single-use nonce", async () => {
  const kp = Keypair.generate();
  const wallet = kp.publicKey.toBase58();
  const ch = await call("/api/auth/challenge", { wallet });
  assert.match(ch.message, /Network: devnet/);
  assert.match(ch.message, /not a transaction/);
  const other = Keypair.generate();
  const bad = nacl.sign.detached(new TextEncoder().encode(ch.message), other.secretKey);
  const r1 = await call("/api/auth/verify", { wallet, nonce: ch.nonce, signature: Buffer.from(bad).toString("base64") });
  assert.equal(r1.http, 401);
  // The nonce died with the failed attempt.
  const good = nacl.sign.detached(new TextEncoder().encode(ch.message), kp.secretKey);
  const r2 = await call("/api/auth/verify", { wallet, nonce: ch.nonce, signature: Buffer.from(good).toString("base64") });
  assert.equal(r2.http, 401);
  assert.equal((await call("/api/auth/challenge", { wallet: "not-a-wallet" })).http, 400);
});

test("everything but sign-in needs a session; other sites are refused", async () => {
  assert.equal((await call("/api/catch/roll", {})).http, 401);
  assert.equal((await call("/api/redeem", { claimId: "x" })).http, 401);
  assert.equal((await call("/api/balance")).http, 401);
  assert.equal((await call("/api/auth/challenge", { wallet: Keypair.generate().publicKey.toBase58() }, null, "https://evil.example")).http, 403);
});

test("balance is read from Devnet for the signed-in wallet", async () => {
  const s = await signIn();
  const b = await call("/api/balance", undefined, s.token);
  assert.equal(b.ok, true);
  assert.equal(b.network, "devnet");
  assert.equal(b.sol, 0);
});

test("a claim lands only after a real wait, once, and only for its wallet", async () => {
  const s = await signIn();
  const roll = await call("/api/catch/roll", {}, s.token);
  assert.ok(["voidfin", "celestail"].includes(roll.fish));
  const quick = await call("/api/catch/land", { claimId: roll.claimId }, s.token);
  assert.equal(quick.error, "too_quick");
  const thief = await signIn();
  assert.equal((await call("/api/catch/land", { claimId: roll.claimId }, thief.token)).error, "unknown_claim");
  assert.equal((await call("/api/redeem", { claimId: roll.claimId }, s.token)).error, "not_landed");
  await sleep(450);
  assert.equal((await call("/api/catch/land", { claimId: roll.claimId }, s.token)).ok, true);
  assert.equal((await call("/api/catch/land", { claimId: roll.claimId }, s.token)).error, "not_open");
  assert.equal((await call("/api/redeem", { claimId: roll.claimId }, thief.token)).error, "unknown_claim");
  assert.equal((await call("/api/redeem", { claimId: "made-up-claim" }, s.token)).error, "unknown_claim");
});

test("an escaped fish can't be landed or redeemed", async () => {
  const s = await signIn();
  const roll = await call("/api/catch/roll", {}, s.token);
  await call("/api/catch/escape", { claimId: roll.claimId }, s.token);
  await sleep(450);
  assert.equal((await call("/api/catch/land", { claimId: roll.claimId }, s.token)).error, "not_open");
  assert.equal((await call("/api/redeem", { claimId: roll.claimId }, s.token)).error, "not_redeemable");
});

test("redeem pays once, idempotently, with a real Devnet signature (or refuses cleanly unfunded)", async (t) => {
  const s = await signIn();
  const roll = await landedClaim(s.token);
  if (!funded) {
    const r = await call("/api/redeem", { claimId: roll.claimId }, s.token);
    assert.equal(r.ok, false);
    assert.equal(r.error, "treasury_rejected");
    assert.equal(app.store.get(roll.claimId).status, "landed", "nothing paid: the claim stays redeemable");
    t.diagnostic("treasury unfunded: checked the refusal path only");
    return;
  }
  const [a, b] = await Promise.all([
    call("/api/redeem", { claimId: roll.claimId }, s.token),
    call("/api/redeem", { claimId: roll.claimId }, s.token),
  ]);
  assert.equal(a.http, 200);
  assert.equal(a.status, "paid");
  assert.equal(b.status, "paid");
  assert.equal(a.ok && b.ok, true, JSON.stringify([a, b]));
  assert.equal(a.signature, b.signature, "two concurrent requests, one payout");
  assert.equal([a.already, b.already].filter(Boolean).length, 1);
  assert.match(a.explorer, /^https:\/\/explorer\.solana\.com\/tx\/[1-9A-HJ-NP-Za-km-z]+\?cluster=devnet$/);
  const again = await call("/api/redeem", { claimId: roll.claimId }, s.token);
  assert.equal(again.signature, a.signature);
  const tx = await app.connection.getTransaction(a.signature, { commitment: "confirmed", maxSupportedTransactionVersion: 0 });
  assert.ok(tx && !tx.meta.err, "confirmed on Devnet");
  const keys = tx.transaction.message.staticAccountKeys.map((k) => k.toBase58());
  const i = keys.indexOf(s.wallet);
  const got = tx.meta.postBalances[i] - tx.meta.preBalances[i];
  assert.equal(got, Math.round(roll.fish === "voidfin" ? 0.01 * LAMPORTS_PER_SOL : 0.02 * LAMPORTS_PER_SOL));
  assert.ok(tx.meta.logMessages.some((l) => l.includes(roll.claimId)), "the memo names the claim");
  t.diagnostic(`paid ${got / LAMPORTS_PER_SOL} SOL: ${a.explorer}`);
});

test("refuses to start on anything but Devnet", async () => {
  await assert.rejects(
    createServer({ port: 0, rpcUrl: "https://api.mainnet-beta.solana.com", dataDir: fs.mkdtempSync(path.join(os.tmpdir(), "aftersteel-x-")) }),
    /not Solana Devnet/,
  );
});
