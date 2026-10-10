class_name Interactable
extends Area2D

## Put this script on an Area2D to make something the player can examine
## with E. It carries no story logic of its own - it only reports that the
## player pressed E while standing close enough.
##
## Whatever owns the object (the room script, an NPC script, ...) connects
## to the "interacted" signal and decides what actually happens. That keeps
## doors, chests, signs and NPCs sharing one small script instead of an
## inheritance tree.

signal interacted

## Shown by a future "E - Examine" prompt. Unused for now.
@export var prompt: String = "Examine"

## Lets a room switch an object off without removing the node.
@export var enabled: bool = true

var _player_in_range := false


func _ready() -> void:
	# Connected here rather than in the editor so that dropping this script
	# onto any Area2D just works, with nothing else to wire up.
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func is_player_in_range() -> bool:
	return _player_in_range


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = true


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		_player_in_range = false


func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not _player_in_range:
		return

	# Dialogue holds this lock while it is open. Without this check the same
	# E press that advances a sentence would also re-trigger the object.
	if GameState.input_locked:
		return

	if event is InputEventKey \
	and event.pressed \
	and not event.echo \
	and event.keycode == KEY_E:

		# Marked handled BEFORE emitting, so the very same E press cannot
		# also reach the dialogue box and skip the first line it opens.
		get_viewport().set_input_as_handled()

		# Every interactable in the game funnels through here, so this is
		# the one place that knows an interaction actually succeeded.
		if not GameState.has_flag("interaction_tutorial_completed"):
			GameState.set_flag("interaction_tutorial_completed", true)
			GameState.set_tutorial("")

		interacted.emit()
