class_name DivineExchange
extends RefCounted

## Toma's Divine Exchange: Divine fish (Voidfin, Celestail) for Solana
## Devnet SOL.
##
## NOT CONNECTED YET. There is no wallet connection and no backend, so
## request() always answers that the exchange is unavailable and changes
## nothing: no fish is taken, no SOL is credited and no transaction is
## reported. The real flow goes here: connect a wallet (public address
## only - the game never sees a private key or seed phrase), have a secure
## backend send the Devnet transfer, verify the confirmed signature, and
## only then take the fish.
##
## Devnet SOL is test currency with no real-world value.

const NETWORK := "devnet"
const OFFER := "Exchange for Devnet SOL"
const TEST_NOTE := "Devnet SOL is test currency."
const UNAVAILABLE := "Wallet connection required - not available yet."


## Whether this fish goes to the exchange rather than for gold.
static func accepts(id: String) -> bool:
	var item := Items.by_id(id)
	return item.get("fish", false) and str(item.get("rarity", "")) == "divine"


## True once a wallet and a backend are connected. Not yet.
static func is_available() -> bool:
	return false


## Asks to exchange one Divine fish. Until is_available(), it only says
## why not - it never takes the fish or reports a transfer.
static func request(id: String) -> Dictionary:
	if not accepts(id):
		return {"ok": false, "reason": "not_divine", "message": "Only Divine fish go to the exchange."}

	if not GameState.has_item(id):
		return {"ok": false, "reason": "not_carried", "message": "Kiren isn't carrying one."}

	return {"ok": false, "reason": "unavailable", "network": NETWORK, "message": UNAVAILABLE}
