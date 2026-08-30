class_name EncounterPoint
extends Marker2D

## A place where a fight is meant to happen, chosen by hand.
##
## Still a Marker2D so the map scenes did not have to change shape. When
## it is enabled and not already cleared it builds its own trigger area
## at runtime; when it is dormant it does nothing at all.
##
## There is no randomness, no respawn timer and no roaming AI.

@export var encounter_id: String = ""
@export var enemy_id: String = ""

## Off until a combat system exists to switch it on.
@export var enabled: bool = false

## Whether this fight should happen only once per playthrough.
@export var one_time: bool = true

## How close Kiren has to get. Kept small so it reads as walking into
## something rather than a screen-wide trap.
@export var trigger_size: Vector2 = Vector2(34, 26)

## Overworld art for the enemy. None exists yet, so when this is empty a
## clearly-temporary development marker is drawn instead.
@export var overworld_texture: Texture2D = null

var _area: Area2D


func _ready() -> void:
	if not enabled or is_cleared():
		return

	_area = Area2D.new()
	_area.name = "Trigger"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = trigger_size
	shape.shape = rect
	_area.add_child(shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)

	if overworld_texture != null:
		var sp := Sprite2D.new()
		sp.name = "OverworldVisual"
		sp.texture = overworld_texture
		add_child(sp)
	else:
		# TEMPORARY development marker - replace by assigning
		# overworld_texture once a 32x32 enemy sprite exists.
		var mark := ColorRect.new()
		mark.name = "DevMarker"
		mark.color = Color(0.85, 0.15, 0.15, 0.55)
		mark.size = Vector2(16, 16)
		mark.position = Vector2(-8, -16)
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(mark)


func is_cleared() -> bool:
	return one_time and GameState.is_encounter_cleared(encounter_id)


func _on_body_entered(body: Node2D) -> void:
	if body.name != "Player" or is_cleared():
		return

	GameState.battle_enemy_id = enemy_id
	GameState.battle_encounter_id = encounter_id
	GameState.battle_return_scene = get_tree().current_scene.scene_file_path
	GameState.battle_return_position = global_position

	get_tree().call_deferred("change_scene_to_file", "res://scenes/combat/battle.tscn")
