extends Node

## Everything the game needs to remember between scenes.
## Autoloaded as "GameState", so any script can read it directly.

signal objective_changed(text: String)
signal tutorial_changed(text: String)
signal inventory_changed


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

## What Kiren currently has equipped, as item ids. Data only for now -
## nothing reads these yet, and equipping does not change his sprite.
var equipment := {
	"weapon": "",
	"head": "",
	"body": "",
	"legs": "",
	"feet": "",
}

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


func add_item(item: Dictionary) -> void:
	if has_item(item.get("id", "")):
		return

	# Copied so the constants in items.gd can never be modified by accident.
	inventory.append(item.duplicate(true))
	inventory_changed.emit()


func is_container_opened(id: String) -> bool:
	return opened_containers.has(id)


func mark_container_opened(id: String) -> void:
	opened_containers[id] = true


func remove_item(id: String) -> void:
	for i in inventory.size():
		if inventory[i].get("id", "") == id:
			inventory.remove_at(i)
			inventory_changed.emit()
			return


func has_item(id: String) -> bool:
	for item in inventory:
		if item.get("id", "") == id:
			return true
	return false
