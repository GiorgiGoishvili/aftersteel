class_name Items
extends RefCounted

## Item definitions used by GameState.inventory.
##
## "id"          internal, safe to branch on in code
## "name"        shown to the player
## "description" shown to the player, written from KIREN'S point of view
## "key_item"    story item, should never be droppable/sellable
## "type"        optional: "weapon" / "armor" / "tool" / "accessory" -
##               absent means a plain item
## "slot"        armour: head / body / legs / feet; the rod: weapon;
##               accessories: accessory
## "icon"        optional res:// path for a future inventory UI
## "fish"        true for fish: fishing.gd draws its catches from these
## "rarity"      optional: one of RARITIES
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

const HEALING_HERB := {
	"id": "healing_herb",
	"name": "Healing Herb",
	"description": "Bitter, but it closes a wound. Restores 30 health.",
	"key_item": false,
	"use": "heal",
	"power": 30,
	"icon": "res://Assets/GameUI/Icons.png",
}

# Iroh's gift. Heals through the same inventory "use" as the herb.
const HEALTH_POTION := {
	"id": "health_potion",
	"name": "Health Potion",
	"description": "A small corked bottle. Restores 40 health.",
	"key_item": false,
	"use": "heal",
	"power": 40,
	"icon": "res://Assets/GameUI/Icons.png",
}

const STEEL_FRAGMENT := {
	"id": "steel_fragment",
	"name": "Steel Fragment",
	"description": "A fragment of worked steel. Valuable to the right hands.",
	"key_item": false,
	"icon": "res://Assets/GameUI/Icons.png",
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
# Welf's sword, the starter. Its icon is the AftersteelSwords export.
const GRAY_SHORT_SWORD := {
	"id": "gray_short_sword", "name": "Grey Short Sword", "type": "weapon",
	"description": "Dull grey steel, well used.", "key_item": false,
	"icon": "res://Assets/Weapons/AftersteelSwords.png",
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


# --- Tools ------------------------------------------------------------
# Goes in the weapon slot in place of the sword; with it out, J and left
# click fish instead of swinging.

const FISHING_ROD := {
	"id": "fishing_rod", "name": "Fishing Rod", "type": "tool", "slot": "weapon",
	"description": "A plain rod and line.", "key_item": false,
	"icon": "res://Assets/Tools/FishingrodIcon.png",
}


# --- Rarity -----------------------------------------------------------
# Lowest first. Only common and uncommon are used so far; the rest are here
# so a new item can simply name one.

const RARITIES := ["common", "uncommon", "rare", "epic", "divine"]


# --- Fish -------------------------------------------------------------
# Every fish has a rarity. fishing.gd catches from all the fish of the
# rarity it rolls, so a new fish only needs adding here (and to ALL).

const SILVER_MINNOW := {
	"id": "silver_minnow", "name": "Silver Minnow", "fish": true, "rarity": "common",
	"description": "Small and quick. Barely a mouthful.", "key_item": false,
	"icon": "res://Assets/Fish/Common/Silverfin_Common.png",
}
const MUD_CARP := {
	"id": "mud_carp", "name": "Mud Carp", "fish": true, "rarity": "common",
	"description": "Tastes a bit like the riverbed.", "key_item": false,
	"icon": "res://Assets/Fish/Common/Mudfin_Common.png",
}
const CREEK_BREAM := {
	"id": "creek_bream", "name": "Creek Bream", "fish": true, "rarity": "common",
	"description": "Flat and bony, but it fries well.", "key_item": false,
	"icon": "res://Assets/Fish/Common/Stonefin_Common.png",
}
const SPECKLED_RIVERFISH := {
	"id": "speckled_riverfish", "name": "Speckled Riverfish", "fish": true, "rarity": "common",
	"description": "Spotted all over. There are plenty of these.", "key_item": false,
	"icon": "res://Assets/Fish/Common/Mossback_Common.png",
}
const COPPER_PERCH := {
	"id": "copper_perch", "name": "Copper Perch", "fish": true, "rarity": "uncommon",
	"description": "Its belly shines like an old coin.", "key_item": false,
	"icon": "res://Assets/Fish/Uncommon/Copperbelly.png",
}
const BLUEGILL_PERCH := {
	"id": "bluegill_perch", "name": "Bluegill Perch", "fish": true, "rarity": "uncommon",
	"description": "Blue on top, orange underneath.", "key_item": false,
	"icon": "res://Assets/Fish/Uncommon/Rustgill.png",
}
const EMBERFIN := {
	"id": "emberfin", "name": "Emberfin", "fish": true, "rarity": "uncommon",
	"description": "Red fins, as if it swam too near a fire.", "key_item": false,
	"icon": "res://Assets/Fish/Uncommon/Emberfin.png",
}
const SUNSCALE_FISH := {
	"id": "sunscale_fish", "name": "Sunscale Fish", "fish": true, "rarity": "uncommon",
	"description": "Golden scales. It looks warm, somehow.", "key_item": false,
	"icon": "res://Assets/Fish/Uncommon/Amberfin.png",
}
const RIVER_CATFISH := {
	"id": "river_catfish", "name": "River Catfish", "fish": true, "rarity": "uncommon",
	"description": "Whiskers and a sour look.", "key_item": false,
	"icon": "res://Assets/Fish/Uncommon/Duskgill.png",
}


# --- Other catches -------------------------------------------------------
# What the river gives up besides fish (chances live in fishing.gd).

# Junk: what comes up when it isn't a fish.
const DRIFTWOOD := {
	"id": "driftwood", "name": "Driftwood",
	"description": "A branch the river has had for a while.", "key_item": false,
	"icon": "res://Assets/Materials/Log2.png",
}

# The rare catch. Worn in the accessory slot; it does nothing yet.
const OLD_RING := {
	"id": "old_ring", "name": "Old Ring", "type": "accessory", "slot": "accessory",
	"description": "Someone lost this in the river a long time ago.", "key_item": false,
	"icon": "res://Assets/Accessories/OldRing.tres",
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
	"healing_herb": HEALING_HERB,
	"health_potion": HEALTH_POTION,
	"steel_fragment": STEEL_FRAGMENT,
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
	"fishing_rod": FISHING_ROD,
	"silver_minnow": SILVER_MINNOW,
	"mud_carp": MUD_CARP,
	"creek_bream": CREEK_BREAM,
	"speckled_riverfish": SPECKLED_RIVERFISH,
	"copper_perch": COPPER_PERCH,
	"bluegill_perch": BLUEGILL_PERCH,
	"emberfin": EMBERFIN,
	"sunscale_fish": SUNSCALE_FISH,
	"river_catfish": RIVER_CATFISH,
	"driftwood": DRIFTWOOD,
	"old_ring": OLD_RING,
}


static func by_id(id: String) -> Dictionary:
	return ALL.get(id, {})


## Every fish of a rarity, by id, in the order above.
static func fish_of(rarity: String) -> Array:
	var ids := []

	for id in ALL:
		if ALL[id].get("fish", false) and ALL[id].get("rarity", "") == rarity:
			ids.append(id)

	return ids


## The item's name, with its rarity when it has one: "Emberfin (Uncommon)".
static func label_of(item: Dictionary) -> String:
	var rarity := str(item.get("rarity", ""))
	return str(item.get("name", "")) + (" (%s)" % rarity.capitalize() if rarity != "" else "")
