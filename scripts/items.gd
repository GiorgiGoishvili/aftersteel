class_name Items
extends RefCounted

## Item definitions used by GameState.inventory.
##
## "id"          internal, safe to branch on in code
## "name"        shown to the player
## "description" shown to the player, written from KIREN'S point of view
## "key_item"    story item, should never be droppable/sellable
##
## RULE: player-facing "name" and "description" must never reveal story
## secrets. Kiren does not know what this object really is, so neither
## does anything the player can read.


# The genuine family Amulet. Kiren carries this one out of the house.
const FAMILY_AMULET_TRUE := {
	"id": "family_amulet_true",
	"name": "Family Amulet",
	"description": "An old amulet Mother insists I keep close.",
	"key_item": true,
}

# DEVELOPER KNOWLEDGE: this is the decoy left behind in the bedroom chest.
# Kiren believes it is simply an older, spare amulet. Never surface the
# words "fake" or "decoy" in player-facing text.
const FAMILY_AMULET_DECOY := {
	"id": "family_amulet_decoy",
	"name": "Old Family Amulet",
	"description": "Another one, older still. It has always been in the chest.",
	"key_item": true,
}

# Ordinary quest item. One pickup is "enough wood" - no stack counting.
const FIREWOOD_BUNDLE := {
	"id": "firewood_bundle",
	"name": "Firewood",
	"description": "A few dry logs from outside the house.",
	"key_item": false,
}
