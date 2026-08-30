class_name Items
extends RefCounted

## Item definitions used by GameState.inventory.
##
## "id"          internal, safe to branch on in code
## "name"        shown to the player
## "description" shown to the player, written from KIREN'S point of view
## "key_item"    story item, should never be droppable/sellable
## "type"        optional: "weapon" / "armor" - absent means a plain item
## "slot"        armor only: head / body / legs / feet
## "icon"        optional res:// path for a future inventory UI
##
## RULE: player-facing "name" and "description" must never reveal story
## secrets. Kiren does not know what this object really is, so neither
## does anything the player can read.
##
## NOTE: no damage/defence numbers yet. They get added when combat exists,
## so nothing here has to be guessed twice.


# --- Story items ------------------------------------------------------

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


# --- Materials --------------------------------------------------------

const FIREWOOD_BUNDLE := {
	"id": "firewood_bundle",
	"name": "Firewood",
	"description": "A few dry logs from outside the house.",
	"key_item": false,
	"icon": "res://Assets/Materials/Log1.png",
}

# TEMPORARY. Only exists so the barrel/container system has something
# harmless to hand out during testing. Delete once real consumables exist.
const TEST_RATION := {
	"id": "test_ration",
	"name": "Dried Meat",
	"description": "Something to eat later.",
	"key_item": false,
}


# --- Weapons ----------------------------------------------------------
# Art exists for three colourways of two blade shapes. Where Kiren
# actually obtains any of these is still an open story decision.

const SHORT_SWORD := {
	"id": "short_sword", "name": "Short Sword", "type": "weapon",
	"description": "A plain, serviceable blade.", "key_item": false,
	"icon": "res://Assets/Weapons/NormalShortSword.png",
}
const LONG_SWORD := {
	"id": "long_sword", "name": "Long Sword", "type": "weapon",
	"description": "Longer than it looks. Heavier, too.", "key_item": false,
	"icon": "res://Assets/Weapons/NormalLongSword.png",
}
const GRAY_SHORT_SWORD := {
	"id": "gray_short_sword", "name": "Grey Short Sword", "type": "weapon",
	"description": "Dull grey steel, well used.", "key_item": false,
	"icon": "res://Assets/Weapons/GrayShortSword.png",
}
const GRAY_LONG_SWORD := {
	"id": "gray_long_sword", "name": "Grey Long Sword", "type": "weapon",
	"description": "Dull grey steel, well used.", "key_item": false,
	"icon": "res://Assets/Weapons/GrayLongSword.png",
}
const RED_SHORT_SWORD := {
	"id": "red_short_sword", "name": "Red Short Sword", "type": "weapon",
	"description": "The blade has been stained red.", "key_item": false,
	"icon": "res://Assets/Weapons/RedShortSword.png",
}
const RED_LONG_SWORD := {
	"id": "red_long_sword", "name": "Red Long Sword", "type": "weapon",
	"description": "The blade has been stained red.", "key_item": false,
	"icon": "res://Assets/Weapons/RedLongSword.png",
}


# --- Armour -----------------------------------------------------------
# Two full sets of four pieces. Icons only - there is no worn-armour
# character art, so equipping does not change Kiren's overworld sprite.

const STEEL_HELMET := {
	"id": "steel_helmet", "name": "Steel Helmet", "type": "armor", "slot": "head",
	"description": "Plain steel. Dented on one side.", "key_item": false,
	"icon": "res://Assets/Armour/SteelHelmet.png",
}
const STEEL_CHESTPLATE := {
	"id": "steel_chestplate", "name": "Steel Chestplate", "type": "armor", "slot": "body",
	"description": "Heavy, but it turns a blade.", "key_item": false,
	"icon": "res://Assets/Armour/SteelChestpalate.png",
}
const STEEL_LEGGINGS := {
	"id": "steel_leggings", "name": "Steel Leggings", "type": "armor", "slot": "legs",
	"description": "Steel plate, worn over cloth.", "key_item": false,
	"icon": "res://Assets/Armour/SteelLeggings.png",
}
const STEEL_BOOTS := {
	"id": "steel_boots", "name": "Steel Boots", "type": "armor", "slot": "feet",
	"description": "Loud on stone.", "key_item": false,
	"icon": "res://Assets/Armour/SteelBoots.png",
}
const GOLDEN_HELMET := {
	"id": "golden_helmet", "name": "Golden Helmet", "type": "armor", "slot": "head",
	"description": "Too fine for anyone who has to fight in it.", "key_item": false,
	"icon": "res://Assets/Armour/GoldenHelmet.png",
}
const GOLDEN_CHESTPLATE := {
	"id": "golden_chestplate", "name": "Golden Chestplate", "type": "armor", "slot": "body",
	"description": "Too fine for anyone who has to fight in it.", "key_item": false,
	"icon": "res://Assets/Armour/GoldenChestplate.png",
}
const GOLDEN_LEGGINGS := {
	"id": "golden_leggings", "name": "Golden Leggings", "type": "armor", "slot": "legs",
	"description": "Too fine for anyone who has to fight in it.", "key_item": false,
	"icon": "res://Assets/Armour/GoldenLeggings.png",
}
const GOLDEN_BOOTS := {
	"id": "golden_boots", "name": "Golden Boots", "type": "armor", "slot": "feet",
	"description": "Too fine for anyone who has to fight in it.", "key_item": false,
	"icon": "res://Assets/Armour/GoldenBoots.png",
}


## Every item by id, so containers can be filled with plain strings in the
## editor instead of wiring resources up by hand.
const ALL := {
	"family_amulet_true": FAMILY_AMULET_TRUE,
	"family_amulet_decoy": FAMILY_AMULET_DECOY,
	"firewood_bundle": FIREWOOD_BUNDLE,
	"test_ration": TEST_RATION,
	"short_sword": SHORT_SWORD,
	"long_sword": LONG_SWORD,
	"gray_short_sword": GRAY_SHORT_SWORD,
	"gray_long_sword": GRAY_LONG_SWORD,
	"red_short_sword": RED_SHORT_SWORD,
	"red_long_sword": RED_LONG_SWORD,
	"steel_helmet": STEEL_HELMET,
	"steel_chestplate": STEEL_CHESTPLATE,
	"steel_leggings": STEEL_LEGGINGS,
	"steel_boots": STEEL_BOOTS,
	"golden_helmet": GOLDEN_HELMET,
	"golden_chestplate": GOLDEN_CHESTPLATE,
	"golden_leggings": GOLDEN_LEGGINGS,
	"golden_boots": GOLDEN_BOOTS,
}


static func by_id(id: String) -> Dictionary:
	return ALL.get(id, {})
