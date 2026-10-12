extends Node

## Everything the game needs to remember between scenes.
## Autoloaded as "GameState", so any script can read it directly.

signal objective_changed(text: String)
signal enemy_defeated(kind: String)
signal tutorial_changed(text: String)
signal inventory_changed
signal equipment_changed
signal gold_changed(amount: int)
signal player_health_changed(current: int, maximum: int)


# --- Scene transitions -------------------------------------------------

# Which spawn marker the next scene should place the player on.
var next_spawn := ""


# --- Input -------------------------------------------------------------

# True while a cutscene, dialogue or menu owns the input.
# player.gd checks this instead of anything calling
# set_physics_process() on the player from across the scene tree.
var input_locked := false


# --- Story flags -------------------------------------------------------

## Small named booleans the story can branch on. Add new keys here as the
## story grows; anything missing simply reads as false.
var story_flags := {
	# Opening sequence: blocks the bedroom door until the chest is checked.
	# Turned on when Eira's dialogue ends, off for good once the chest is
	# opened, so returning to the bedroom later behaves normally.
	"intro_chest_gate_active": false,

	"bedroom_chest_checked": false,
	"mom_letter_read": false,

	# One-time control hints (tutorials.gd). Each is set the first time
	# the player actually does the thing being taught, and that hint is
	# never shown again after.
	"move_tutorial_completed": false,
	"interaction_tutorial_completed": false,
	"equip_tutorial_completed": false,
	"attack_tutorial_completed": false,
	"cast_tutorial_completed": false,
	"reel_tutorial_completed": false,

	# Eira's firewood errand. Whether Kiren is carrying the wood is
	# read from the inventory instead of a duplicate flag.
	"eira_firewood_quest_started": false,
	"eira_firewood_quest_completed": false,

	# Eira sends Kiren round the village once the firewood is in. Who he
	# has met so far is villagers_met below.
	"village_intro_started": false,

	# The Blue Slime's job: put down ten red slimes in the west field.
	# Progress is slimes_defeated below.
	"slime_quest_started": false,
	"slime_quest_completed": false,

	# Toma, the fisherman at the river: his introduction plays once.
	"toma_met": false,

	# DEVELOPER KNOWLEDGE: the decoy amulet is still sitting in the bedroom
	# chest. Kiren has no idea there is anything unusual about it.
	"decoy_amulet_in_bedroom_chest": true,
}


# --- Objective ---------------------------------------------------------

# Current one-line objective. Empty string means "nothing active".
var objective := ""

# Where that objective is, as a key from quest_targets.gd. The quest pointer
# beside Kiren points there (or at the exit toward it). Empty = no pointer.
var objective_target := ""

# A smaller second line under the objective (the next step of it), or "".
var objective_detail := ""

## The Blue Slime's job: how many red slimes Kiren has put down since taking it.
const SLIME_QUEST_GOAL := 10
var slimes_defeated := 0

## Everyone Eira means by "go see them", in the order the objective suggests
## them: Welf first, since the Blue Slime's job needs his sword. Any order
## works and each counts once.
const VILLAGERS := {
	"welf": "Welf",
	"iroh": "Iroh",
	"blue_slime": "Blue Slime",
}

## Ids from VILLAGERS that Kiren has had his first talk with, used as a set.
var villagers_met := {}

## How many of each kind of enemy Kiren has put down, for the monster index.
var enemies_defeated := {}

# Current one-time tutorial hint, shown under the objective.
# Separate from the objective: it teaches a control, not a goal.
var tutorial_hint := ""


# --- Inventory ---------------------------------------------------------

## Items the player is carrying, as plain Dictionaries (see items.gd).
## A future inventory menu just reads this array.
var inventory: Array[Dictionary] = []

## Coin, from selling fish to Toma. Only add_gold changes it, and only
## upwards, so it can never go negative.
var gold := 0

## What Kiren currently has equipped, as item ids. An item stays in the
## inventory while equipped. Only "weapon" changes anything so far: with a
## sword equipped the overworld Kiren uses his sword animations.
var equipment := {
	"weapon": "",
	"head": "",
	"body": "",
	"legs": "",
	"feet": "",
	"accessory": "",
}

## Kiren's combat stats. Survives leaving the battle scene so damage
## taken in a fight still matters afterwards.
var player_stats := {
	"max_hp": 100,
	"current_hp": 100,
	"attack_damage": 20,
}

## Which encounter the battle scene should run, and where to put Kiren
## back afterwards. Empty means "no battle queued".
var battle_enemy_id := ""
var battle_encounter_id := ""
var battle_return_scene := ""
var battle_return_position := Vector2.ZERO

## Encounters already won this session, so a cleared fight stays cleared.
var completed_encounters := {}

## Demo convenience: Kiren starts with a couple of herbs so healing can
## be tested without hunting for a pickup first.
var _starting_kit_given := false

## Ids of containers already searched, used as a set. Lives here rather
## than in the scene so a barrel stays empty after a scene change.
var opened_containers := {}

## Ids of NPC gifts already handed over, used as a set, so talking again
## or coming back to the map never gives the same thing twice.
var received_gifts := {}


func set_flag(flag: String, value := true) -> void:
	story_flags[flag] = value


func has_flag(flag: String) -> bool:
	return story_flags.get(flag, false)


func set_objective(text: String, target := "", detail := "") -> void:
	objective = text
	objective_target = target
	objective_detail = detail
	objective_changed.emit(text)


## The objective once Eira has sent Kiren round the village, worked out from
## the quest state: the Blue Slime's job while it is on, then whoever is
## still to meet, then nothing. Called after each conversation and each
## counted kill. Before Eira's request the rooms set the objective themselves.
func refresh_objective() -> void:
	if slime_quest_active():
		if slimes_defeated >= SLIME_QUEST_GOAL:
			set_objective("Return to Blue Slime", "blue_slime")
		else:
			set_objective(slime_quest_objective(), "slime_clearing")
		return

	if not has_flag("village_intro_started"):
		return

	var next := next_villager()

	if next != "":
		set_objective("Talk to the villagers", next, "Visit %s" % VILLAGERS[next])
	elif VILLAGERS.has(objective_target) or objective_target == "slime_clearing":
		# That was the last of it. Anything else set since is left alone.
		set_objective("")


func meet_villager(id: String) -> void:
	if VILLAGERS.has(id):
		villagers_met[id] = true


func has_met_villager(id: String) -> bool:
	return villagers_met.has(id)


## The first villager Kiren hasn't talked to yet, or "" once he has met them all.
func next_villager() -> String:
	for id in VILLAGERS:
		if not has_met_villager(id):
			return id
	return ""


## Every enemy Kiren puts down reports here exactly once (on its death).
## Friendly creatures never do, so only real kills count.
func record_enemy_defeated(kind: String) -> void:
	enemies_defeated[kind] = int(enemies_defeated.get(kind, 0)) + 1
	enemy_defeated.emit(kind)

	if kind != "red_slime" or not slime_quest_active() or slimes_defeated >= SLIME_QUEST_GOAL:
		return

	slimes_defeated += 1
	refresh_objective()


func slime_quest_active() -> bool:
	return has_flag("slime_quest_started") and not has_flag("slime_quest_completed")


func slime_quest_objective() -> String:
	return "Defeat Red Slimes: %d/%d" % [slimes_defeated, SLIME_QUEST_GOAL]


func set_tutorial(text: String) -> void:
	tutorial_hint = text
	tutorial_changed.emit(text)


## Adds an item, stacking onto an existing entry. Entries carry a "count"
## so the inventory screen can show quantities; has_item()/remove_item()
## keep the same meaning they always had.
func add_item(item: Dictionary, amount := 1) -> void:
	var id: String = item.get("id", "")

	for entry in inventory:
		if entry.get("id", "") == id:
			entry["count"] = int(entry.get("count", 1)) + amount
			inventory_changed.emit()
			return

	# Copied so the constants in items.gd can never be modified by accident.
	var fresh: Dictionary = item.duplicate(true)
	fresh["count"] = amount
	inventory.append(fresh)
	inventory_changed.emit()


func add_gold(amount: int) -> void:
	if amount <= 0:
		return

	gold += amount
	gold_changed.emit(gold)


func grant_starting_kit() -> void:
	if _starting_kit_given:
		return

	_starting_kit_given = true
	add_item(Items.HEALING_HERB, 2)


## Equips an item Kiren is carrying into its slot ("weapon" for weapons,
## the item's own "slot" for armour).
func equip(id: String) -> void:
	var item := Items.by_id(id)

	if item.is_empty() or not has_item(id):
		return

	var slot: String = "weapon" if item.get("type", "") == "weapon" else str(item.get("slot", ""))

	if not equipment.has(slot):
		return

	equipment[slot] = id
	equipment_changed.emit()


func unequip(slot: String) -> void:
	if equipment.get(slot, "") == "":
		return

	equipment[slot] = ""
	equipment_changed.emit()


func is_equipped(id: String) -> bool:
	return id != "" and equipment.values().has(id)


## Every weapon in the game is a sword, so this is "is the sword out". The
## fishing rod shares the slot but is a tool, not a weapon.
func has_weapon_equipped() -> bool:
	return Items.by_id(str(equipment.get("weapon", ""))).get("type", "") == "weapon"


## With the rod out, J and left click fish instead of swinging.
func has_rod_equipped() -> bool:
	return equipment.get("weapon", "") == Items.FISHING_ROD["id"]


func reset_player_hp() -> void:
	player_stats["current_hp"] = player_stats["max_hp"]
	player_health_changed.emit(get_player_hp(), get_player_max_hp())


func get_player_hp() -> int:
	return int(player_stats["current_hp"])


func get_player_max_hp() -> int:
	return int(player_stats["max_hp"])


func set_player_hp(value: int) -> void:
	player_stats["current_hp"] = clampi(value, 0, get_player_max_hp())
	player_health_changed.emit(get_player_hp(), get_player_max_hp())


func damage_player(amount: int) -> void:
	set_player_hp(get_player_hp() - amount)


## Returns how much was actually restored, so callers can tell whether
## the item was worth consuming.
func heal_player(amount: int) -> int:
	var before := get_player_hp()
	set_player_hp(before + amount)
	return get_player_hp() - before


func is_encounter_cleared(id: String) -> bool:
	return completed_encounters.has(id)


func mark_encounter_cleared(id: String) -> void:
	if id != "":
		completed_encounters[id] = true


## Wipes the run so returning to the menu starts a fresh playthrough.
func reset_run() -> void:
	story_flags["intro_chest_gate_active"] = false
	story_flags["bedroom_chest_checked"] = false
	story_flags["mom_letter_read"] = false
	story_flags["move_tutorial_completed"] = false
	story_flags["interaction_tutorial_completed"] = false
	story_flags["equip_tutorial_completed"] = false
	story_flags["attack_tutorial_completed"] = false
	story_flags["cast_tutorial_completed"] = false
	story_flags["reel_tutorial_completed"] = false
	story_flags["eira_firewood_quest_started"] = false
	story_flags["eira_firewood_quest_completed"] = false
	story_flags["village_intro_started"] = false
	story_flags["slime_quest_started"] = false
	story_flags["slime_quest_completed"] = false
	story_flags["toma_met"] = false
	slimes_defeated = 0
	villagers_met.clear()
	enemies_defeated.clear()
	completed_encounters.clear()
	opened_containers.clear()
	received_gifts.clear()
	inventory.clear()
	gold = 0
	for slot in equipment:
		equipment[slot] = ""
	_starting_kit_given = false
	objective = ""
	objective_target = ""
	objective_detail = ""
	tutorial_hint = ""
	next_spawn = ""
	input_locked = false
	reset_player_hp()
	clear_battle_context()


func clear_battle_context() -> void:
	battle_enemy_id = ""
	battle_encounter_id = ""
	battle_return_scene = ""
	battle_return_position = Vector2.ZERO


func has_received_gift(id: String) -> bool:
	return received_gifts.has(id)


func mark_gift_received(id: String) -> void:
	received_gifts[id] = true


func is_container_opened(id: String) -> bool:
	return opened_containers.has(id)


func mark_container_opened(id: String) -> void:
	opened_containers[id] = true


func remove_item(id: String, amount := 1) -> void:
	for i in inventory.size():
		if inventory[i].get("id", "") == id:
			var left: int = int(inventory[i].get("count", 1)) - amount

			if left > 0:
				inventory[i]["count"] = left
			else:
				inventory.remove_at(i)

				# Can't keep wearing something that's no longer carried.
				for slot in equipment:
					if equipment[slot] == id:
						unequip(slot)

			inventory_changed.emit()
			return


func get_item_count(id: String) -> int:
	for entry in inventory:
		if entry.get("id", "") == id:
			return int(entry.get("count", 1))
	return 0


func has_item(id: String) -> bool:
	for item in inventory:
		if item.get("id", "") == id:
			return true
	return false
