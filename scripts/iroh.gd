extends "res://scripts/npc.gd"

## Iroh: the potions (npc.gd's gift), then his old fishing rod - a second
## one-time gift in the same first conversation. The rod goes into the pack;
## Kiren equips it himself from the Equipment screen. Saves from before he
## gave it get it on their next visit, unless Kiren already has a rod.

const ROD_GIFT_ID := "iroh_rod"

const ROD_LINES := [
	"One more thing.",
	"My old rod. I don't get down to the river much these days.",
	"They bite close to the bank. Give it a try.",
]

## Kiren already had a rod of his own by the time Iroh offered his.
const HAS_ROD_LINES := [
	"You've a rod already, I see. Good.",
	"They bite close to the bank.",
]

## Every visit once the rod is his.
const AFTER_ROD_LINES := [
	"Any luck at the river?",
]


func _greeting() -> Array:
	var rod_given_before := GameState.has_received_gift(ROD_GIFT_ID)
	var lines := super._greeting()

	if rod_given_before:
		return _spoken(AFTER_ROD_LINES) + lines

	# Recorded before anything else, so nothing can hand it over twice.
	GameState.mark_gift_received(ROD_GIFT_ID)

	if GameState.has_item(Items.FISHING_ROD["id"]):
		return lines + _spoken(HAS_ROD_LINES)

	GameState.add_item(Items.FISHING_ROD)
	return lines + _spoken(ROD_LINES) + [{ "text": "Received: %s" % Items.FISHING_ROD["name"] }]
