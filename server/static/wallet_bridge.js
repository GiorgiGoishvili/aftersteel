// Aftersteel <-> Phantom bridge (Solana Devnet). Loaded by the web build's
// HTML; the game reaches it through Godot's JavaScriptBridge as
// window.AftersteelWallet.
//
// It uses Phantom's own provider API: connect(), then signMessage() for a
// one-time sign-in that the exchange server verifies. The wallet is never
// asked to sign a transaction - payouts come from the server's Devnet
// treasury. No keys live here; the session token stays in page memory.
//
// Every call takes a callback last and answers it with one JSON string.
(function () {
  "use strict";

  let token = null;
  let wallet = null;
  let balance = null;

  function provider() {
    const p = window.phantom && window.phantom.solana;
    if (p && p.isPhantom) return p;
    if (window.solana && window.solana.isPhantom) return window.solana;
    return null;
  }

  function reply(cb, obj) {
    try { cb(JSON.stringify(obj)); } catch (e) { console.error("[AftersteelWallet] callback failed", e); }
  }

  async function api(path, body) {
    const headers = { "Content-Type": "application/json" };
    if (token) headers.Authorization = "Bearer " + token;
    let res;
    try {
      res = await fetch(path, { method: body === undefined ? "GET" : "POST", headers, body: body === undefined ? undefined : JSON.stringify(body) });
    } catch (e) {
      return { ok: false, error: "server_unreachable" };
    }
    let data = null;
    try { data = await res.json(); } catch (e) { data = null; }
    if (!data) data = { ok: false, error: "http_" + res.status };
    if (res.status === 401 && data.error === "not_signed_in") { token = null; }
    return data;
  }

  function base64(bytes) {
    let s = "";
    for (let i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]);
    return btoa(s);
  }

  function forget() {
    token = null; wallet = null; balance = null;
  }

  async function refresh() {
    const b = await api("/api/balance");
    if (b.ok) balance = b.sol;
    return b;
  }

  // The step a call is on, so a failure says where it happened.
  let step = "";

  function run(cb, fn) {
    step = "";
    fn().then((out) => reply(cb, out)).catch((e) => {
      const detail = String((e && (e.message || e.error)) || e).slice(0, 160);
      const cancelled = e && (e.code === 4001 || /reject|cancel|denied|closed/i.test(detail));
      console.error("[AftersteelWallet] failed at '" + step + "':", e && e.code, detail, e);
      reply(cb, { ok: false, error: cancelled ? "cancelled" : "wallet_error", step: step, code: e && e.code, detail: detail });
    });
  }

  function watch(p) {
    if (watch.done || !p || !p.on) return;
    watch.done = true;
    p.on("accountChanged", () => { forget(); });
    p.on("disconnect", () => { forget(); });
  }

  window.AftersteelWallet = {
    hasPhantom: function () { return !!provider(); },

    status: function () {
      return JSON.stringify({ phantom: !!provider(), connected: !!token, wallet: wallet, balance: balance, network: "devnet" });
    },

    // Phantom's connect prompt, then its sign-message prompt for the sign-in.
    connectWallet: function (cb) {
      run(cb, async function () {
        const p = provider();
        if (!p) return { ok: false, error: "no_phantom" };
        watch(p);
        step = "connect";
        const conn = await p.connect();
        const address = (conn && conn.publicKey ? conn.publicKey : p.publicKey).toString();
        step = "challenge";
        const challenge = await api("/api/auth/challenge", { wallet: address });
        if (!challenge.ok) return challenge;
        step = "signMessage";
        const signed = await p.signMessage(new TextEncoder().encode(challenge.message), "utf8");
        const signature = signed && signed.signature ? signed.signature : signed;
        step = "verify";
        const verified = await api("/api/auth/verify", { wallet: address, nonce: challenge.nonce, signature: base64(signature) });
        if (!verified.ok) return verified;
        token = verified.token;
        wallet = verified.wallet;
        await refresh();
        return { ok: true, wallet: wallet, balance: balance, network: "devnet" };
      });
    },

    disconnectWallet: function (cb) {
      run(cb, async function () {
        const p = provider();
        forget();
        if (p && p.disconnect) await p.disconnect();
        return { ok: true };
      });
    },

    refreshBalance: function (cb) {
      run(cb, async function () {
        if (!token) return { ok: false, error: "not_signed_in" };
        const b = await refresh();
        return b.ok ? { ok: true, wallet: wallet, balance: balance, network: "devnet" } : b;
      });
    },

    rollCatch: function (cb) { run(cb, function () { return api("/api/catch/roll", {}); }); },
    landCatch: function (claimId, cb) { run(cb, function () { return api("/api/catch/land", { claimId: String(claimId) }); }); },
    escapeCatch: function (claimId, cb) { run(cb, function () { return api("/api/catch/escape", { claimId: String(claimId) }); }); },
    redeemClaim: function (claimId, cb) { run(cb, function () { return api("/api/redeem", { claimId: String(claimId) }); }); },

    // Only Solana Explorer links, in a new tab.
    openExplorer: function (url) {
      if (/^https:\/\/explorer\.solana\.com\/tx\/[1-9A-HJ-NP-Za-km-z]+\?cluster=devnet$/.test(String(url))) {
        window.open(String(url), "_blank", "noopener");
        return true;
      }
      return false;
    },
  };
})();
