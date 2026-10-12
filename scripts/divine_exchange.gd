class_name DivineExchange
extends RefCounted

## Toma's Divine Exchange: Divine fish (Voidfin, Celestail) for Solana
## Devnet SOL, paid by the exchange server's treasury (server/ - see its
## server.js). Devnet SOL is test currency with no real-world value.
##
## A fish can be exchanged when it was caught with the wallet connected: the
## server rolled that catch and holds a claim for it (GameState.divine_claims).
## The wallet only signs a sign-in message; the server sends the transfer.
## The shop takes the fish out of the pack only after the server reports the
## transfer confirmed, with its signature - so a failed or cancelled exchange
## keeps the fish, and asking again for a claim that was already paid just
## returns the same signature.

const NETWORK := "devnet"
## What each fish pays, for showing in the shop. The server's own table is
## the one that pays (server.js PRICES_SOL).
const PRICES_SOL := {"voidfin": 0.01, "celestail": 0.02}
const TEST_NOTE := "Devnet SOL is test currency."
const NEEDS_BROWSER := "The exchange runs in the browser build, with Phantom."
const NEEDS_PHANTOM := "Install Phantom to use the exchange."
const NEEDS_WALLET := "Connect your Phantom wallet first (Devnet)."
const NO_CLAIM := "Caught without a wallet connected - there's no claim to redeem for this one."

## Why a redeem didn't pay, in the shop's words.
const ERRORS := {
	"cancelled": "Cancelled in Phantom. The fish is still yours.",
	"unknown_claim": "The exchange has no record of this catch.",
	"not_landed": "The exchange hasn't seen this catch landed yet.",
	"not_redeemable": "This catch can't be exchanged.",
	"wallet_limit": "This wallet has reached the exchange's demo limit.",
	"daily_budget": "The exchange has paid out its budget for today.",
	"treasury_rejected": "The treasury couldn't pay just now. The fish is still yours.",
	"transaction_failed": "The transfer failed. The fish is still yours.",
	"expired_retry": "The transfer timed out. Nothing was paid - try again.",
	"not_signed_in": "The wallet session ended. Connect again.",
	"server_unreachable": "Toma's exchange server isn't running.",
}


## Whether this fish goes to the exchange rather than for gold.
static func accepts(id: String) -> bool:
	var item := Items.by_id(id)
	return item.get("fish", false) and str(item.get("rarity", "")) == "divine"


static func price_of(id: String) -> float:
	return float(PRICES_SOL.get(id, 0.0))


static func offer(id: String) -> String:
	return "Exchange for %s Devnet SOL" % _sol(price_of(id))


## Whether this fish can be exchanged right now: {"ok": true, "claim": id},
## or {"ok": false, "message": why not}.
static func check(id: String) -> Dictionary:
	if not accepts(id):
		return {"ok": false, "message": "Only Divine fish go to the exchange."}

	Wallet.refresh_flags()

	if not Wallet.available:
		return {"ok": false, "message": NEEDS_BROWSER}
	if not Wallet.phantom:
		return {"ok": false, "message": NEEDS_PHANTOM}
	if not Wallet.connected:
		return {"ok": false, "message": NEEDS_WALLET}

	var claim := GameState.next_divine_claim(id)

	if claim == "":
		return {"ok": false, "message": NO_CLAIM}

	return {"ok": true, "claim": claim}


static func error_text(result: Dictionary) -> String:
	return str(ERRORS.get(str(result.get("error", "")), "The exchange failed (%s). The fish is still yours." % result.get("error", "unknown")))


static func _sol(amount: float) -> String:
	return ("%.4f" % amount).rstrip("0").rstrip(".")
