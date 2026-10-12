extends Node

## One-time control hints, each shown only at the moment it is needed and
## gone for good once Kiren has done the thing - never two at once. The hint
## is picked every frame from the game's own state and handed to
## GameState.set_tutorial(); the HUD draws it at the bottom of the screen.
## Autoloaded as "Tutorials".
##
##   WASD - Move              first control (the bedroom), until he moves
##   E - Interact             in reach of something to use, until he uses one
##   I - Equip sword          a fight with the sword still in the pack
##   J / Left Click - Attack  a fight with the sword in hand, until he swings
##   J / Left Click - Cast    at the river with the rod in hand, until he casts
##   Hold J / Left Click ...  during the fishing minigame, until his first catch

const MOVE := "WASD — Move"
const INTERACT := "E — Interact"
const EQUIP := "I — Equip sword"
const ATTACK := "J / Left Click — Attack"
const CAST := "J / Left Click — Cast"
const REEL := "Hold J / Left Click to raise the bar. Release to lower it."

## Hints wait for this long of uninterrupted control, so none flashes up for
## a frame between a scene loading and its cutscene taking the input.
const SETTLE := 0.3
## An enemy this far past the screen's edge already makes it a fight.
const FIGHT_MARGIN := 16.0
## The map where the rod hint belongs.
const RIVER := "WesternRiver"

var _control := 0.0


func _ready() -> void:
	# The fishing minigame pauses the game, and its hint shows during it.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Fishing.finished.connect(_on_fishing_finished)
	GameState.equipment_changed.connect(_on_equipment_changed)


func _process(delta: float) -> void:
	var hint := _pick(delta)

	if hint != GameState.tutorial_hint:
		GameState.set_tutorial(hint)


func _pick(delta: float) -> String:
	# The minigame holds the input and pauses everything, so it goes first.
	if Fishing.state == Fishing.State.PLAYING:
		return "" if GameState.has_flag("reel_tutorial_completed") else REEL

	if Fishing.state != Fishing.State.IDLE:
		GameState.set_flag("cast_tutorial_completed")

	var player := _player()

	if player == null or not ObjectiveHUD.visible or GameState.input_locked \
			or get_tree().paused or Dialogue.is_active():
		_control = 0.0
		return ""

	# Doing the thing counts even before its hint has had time to show.
	if Input.get_vector("move_left", "move_right", "move_up", "move_down") != Vector2.ZERO:
		GameState.set_flag("move_tutorial_completed")

	if Input.is_action_just_pressed("attack") and GameState.has_weapon_equipped():
		GameState.set_flag("attack_tutorial_completed")

	_control += delta

	if _control < SETTLE:
		return ""

	if not GameState.has_flag("move_tutorial_completed"):
		return MOVE

	if not GameState.has_flag("interaction_tutorial_completed") and _in_reach():
		return INTERACT

	if _in_fight(player):
		if GameState.has_weapon_equipped():
			if not GameState.has_flag("attack_tutorial_completed"):
				return ATTACK
		elif _carries_sword() and not GameState.has_flag("equip_tutorial_completed"):
			return EQUIP

	if GameState.has_rod_equipped() and get_tree().current_scene.name == RIVER \
			and not GameState.has_flag("cast_tutorial_completed"):
		return CAST

	return ""


func _player() -> Node2D:
	var scene := get_tree().current_scene
	return null if scene == null else scene.find_child("Player", true, false) as Node2D


## Standing where E would do something.
func _in_reach() -> bool:
	for thing in get_tree().get_nodes_in_group("interactables"):
		if thing.enabled and thing.is_player_in_range():
			return true
	return false


## A live enemy on screen (or just off it).
func _in_fight(player: Node2D) -> bool:
	var viewport := player.get_viewport()
	var view := (viewport.get_canvas_transform().affine_inverse() * viewport.get_visible_rect()).grow(FIGHT_MARGIN)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is Node2D and int(enemy.get("health")) > 0 and view.has_point(enemy.global_position):
			return true

	return false


func _carries_sword() -> bool:
	for entry in GameState.inventory:
		if entry.get("type", "") == "weapon":
			return true
	return false


func _on_equipment_changed() -> void:
	if GameState.has_weapon_equipped():
		GameState.set_flag("equip_tutorial_completed")


func _on_fishing_finished(result: String) -> void:
	if result.begins_with("caught:"):
		GameState.set_flag("reel_tutorial_completed")
