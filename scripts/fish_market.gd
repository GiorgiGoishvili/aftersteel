class_name FishMarket
extends RefCounted

## What Toma pays for fish, and the selling itself. The prices live here and
## nowhere else, so balancing is one table.
##
## Divine fish have no price: they go to the Divine Exchange
## (divine_exchange.gd), never for gold, so neither sell() nor sell_all()
## ever takes one.

## Gold for one fish, by rarity. Demo values, for balancing later.
const PRICES := {
	"common": 5,
	"uncommon": 15,
	"rare": 50,
}


## Gold for one of this fish; 0 when Toma doesn't buy it.
static func price_of(id: String) -> int:
	var item := Items.by_id(id)

	if not item.get("fish", false):
		return 0

	return int(PRICES.get(str(item.get("rarity", "")), 0))


static func can_sell(id: String) -> bool:
	return price_of(id) > 0


## Sells up to `amount` of one fish - never more than Kiren is carrying.
## Returns the gold paid, 0 when nothing was sold.
static func sell(id: String, amount := 1) -> int:
	var price := price_of(id)
	var count := mini(amount, GameState.get_item_count(id))

	if price <= 0 or count <= 0:
		return 0

	# The fish leave the pack before the gold comes in, so a fish already
	# sold is no longer there to be sold again.
	GameState.remove_item(id, count)
	var paid := price * count
	GameState.add_gold(paid)
	return paid


## Every fish Toma buys, in one go; Divine fish stay in the pack.
## Returns {"fish": how many were sold, "gold": what they paid}.
static func sell_all() -> Dictionary:
	var sold := 0
	var paid := 0
	# Read first: selling changes the inventory.
	var ids: Array = GameState.inventory.map(func(entry: Dictionary) -> String: return str(entry.get("id", "")))

	for id in ids:
		if can_sell(id):
			var count := GameState.get_item_count(id)
			paid += sell(id, count)
			sold += count

	return {"fish": sold, "gold": paid}
