class_name BattleRig
extends Node2D

## Draws one layered character from this project's sprite sheets.
##
## Every sheet here uses the same layout: 128x128 cells, one ROW per
## facing (0 down, 1 right, 2 left, 3 up) and one COLUMN per frame.
##
## All layers are driven from a single state + frame held here, so the
## body, armour, gloves and sword physically cannot drift apart - there
## is only ever one frame counter for the whole character.

signal animation_finished(finished_state: String)

const CELL := 128

const DIR_DOWN := 0
const DIR_RIGHT := 1
const DIR_LEFT := 2
const DIR_UP := 3

## The character art sits at the bottom-middle of its cell, so this puts
## the node's origin on the character's feet.
const FOOT_OFFSET := Vector2(-64, -80)

## Some sheets sit their character on the bottom of the cell instead.
var foot_y := -80.0

var state := ""
var direction := DIR_DOWN
var frame := 0

var _states: Dictionary = {}
var _layers: Array[Sprite2D] = []
var _time := 0.0
var _done := false


## states = { name: { "frames": int, "speed": float, "loop": bool,
##                    "layers": [texture paths, back to front] } }
func configure(states: Dictionary) -> void:
	_states = states

	var most := 0
	for s in _states.values():
		most = max(most, (s["layers"] as Array).size())

	for i in most:
		var sp := Sprite2D.new()
		sp.centered = false
		sp.offset = Vector2(-64, foot_y)
		sp.region_enabled = true
		add_child(sp)
		_layers.append(sp)


func play(new_state: String, restart := false) -> void:
	if new_state == state and not restart:
		return

	if not _states.has(new_state):
		push_warning("BattleRig: unknown state '%s'" % new_state)
		return

	state = new_state
	frame = 0
	_time = 0.0
	_done = false
	_apply()


func is_finished() -> bool:
	return _done


func _process(delta: float) -> void:
	if state == "" or _done:
		return

	var info: Dictionary = _states[state]
	_time += delta

	if _time < float(info["speed"]):
		return

	_time -= float(info["speed"])
	var count := int(info["frames"])

	if frame + 1 < count:
		frame += 1
	elif bool(info["loop"]):
		frame = 0
	else:
		_done = true
		animation_finished.emit(state)
		return

	_apply()


func _apply() -> void:
	var info: Dictionary = _states[state]
	var textures: Array = info["layers"]
	var region := Rect2(frame * CELL, direction * CELL, CELL, CELL)

	for i in _layers.size():
		var sp := _layers[i]

		if i < textures.size():
			sp.texture = load(textures[i])
			sp.region_rect = region
			sp.visible = true
		else:
			# e.g. Death has no equipment sheets - hide those layers.
			sp.visible = false


func set_direction(dir: int) -> void:
	if dir == direction:
		return

	direction = dir
	if state != "":
		_apply()


## Facing from a vector, snapped to the four rows the art actually has.
static func dir_from_vector(v: Vector2) -> int:
	if abs(v.x) >= abs(v.y):
		return DIR_RIGHT if v.x >= 0.0 else DIR_LEFT

	return DIR_DOWN if v.y >= 0.0 else DIR_UP
