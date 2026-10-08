extends Node

## Everything the game needs to remember between scenes.
## Autoloaded as "GameState", so any script can read it directly.

signal objective_changed(text: String)
signal tutorial_changed(text: String)
signal inventory_changed
signal equipment_changed
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

	# One-time hints. Cleared the first time the player actually
	# succeeds at the thing being taught, never shown again after.
	"interaction_tutorial_completed": false,

	# Eira's firewood errand. Whether Kiren is carrying the wood is
	# read from the inventory instead of a duplicate flag.
	"eira_firewood_quest_started": false,
	"eira_firewood_quest_completed": false,

	# DEVELOPER KNOWLEDGE: the decoy amulet is still sitting in the bedroom
	# chest. Kiren has no idea there is anything unusual about it.
	"decoy_amulet_in_bedroom_chest": true,
}


# --- Objective ---------------------------------------------------------

# Current one-line objective. Empty string means "nothing active".
var objective := ""

# Current one-time tutorial hint, shown under the objective.
# Separate from the objective: it teaches a control, not a goal.
var tutorial_hint := ""


# --- Inventory ---------------------------------------------------------

## Items the player is carrying, as plain Dictionaries (see items.gd).
## A future inventory menu just reads this array.
var inventory: Array[Dictionary] = []

## What Kiren currently has equipped, as item ids. An item stays in the
## inventory while equipped. Only "weapon" changes anything so far: with a
## sword equipped the overworld Kiren uses his sword animations.
var equipment := {
	"weapon": "",
	"head": "",
	"body": "",
	"legs": "",
	"feet": "",
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


func set_flag(flag: String, value := true) -> void:
	story_flags[flag] = value


func has_flag(flag: String) -> bool:
	return story_flags.get(flag, false)


func set_objective(text: String) -> void:
	objective = text
	objective_changed.emit(text)


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


## Every weapon in the game is a sword, so this is "is the sword out".
func has_weapon_equipped() -> bool:
	return equipment.get("weapon", "") != ""


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
	story_flags["interaction_tutorial_completed"] = false
	story_flags["eira_firewood_quest_started"] = false
	story_flags["eira_firewood_quest_completed"] = false
	completed_encounters.clear()
	opened_containers.clear()
	inventory.clear()
	for slot in equipment:
		equipment[slot] = ""
	_starting_kit_given = false
	objective = ""
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
