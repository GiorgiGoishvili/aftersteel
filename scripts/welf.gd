extends "res://scripts/npc.gd"

## Welf: Kiren's first sword (npc.gd's gift, handed over on the first talk).
## It goes into the pack; Kiren equips it himself. If he already carries the
## sword, Welf says so and gives nothing, so there is never a second one.
##
## The red slime job is the Blue Slime's now (blue_slime.gd); Welf neither
## starts nor finishes it.

## Kiren already had the sword by the time Welf offered it.
const HAS_SWORD_LINES := [
	"You've got it already, I see.",
	"Bring it back if it chips.",
]


func _greeting() -> Array:
	if _gift_due() and GameState.has_item(gift_item_id):
		# Recorded, so this is said once and the usual line follows after.
		GameState.mark_gift_received(gift_id)
		_meet()
		return _spoken(HAS_SWORD_LINES)

	return super._greeting()
