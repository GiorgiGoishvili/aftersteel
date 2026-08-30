extends Control

## Closing card for the vertical slice, straight into the credits.
##
## Reuses the menu's typewriter feel and the Fabled font rather than
## introducing a second credits system.

@onready var line_one: Label = $LineOne
@onready var line_two: Label = $LineTwo
@onready var credits: Label = $Credits
@onready var thanks: Label = $Thanks
@onready var hint: Label = $Hint

var _finished := false


func _ready() -> void:
	Music.fade_out(2.0)
	ObjectiveHUD.hide_gameplay_hud()

	for l in [line_one, line_two, credits, thanks, hint]:
		l.modulate.a = 0.0

	await get_tree().create_timer(0.7).timeout
	await _fade_in(line_one, 1.5)
	await get_tree().create_timer(1.0).timeout
	await _fade_in(line_two, 1.3)
	await get_tree().create_timer(1.2).timeout

	# The two title cards step aside for the credits.
	await _fade_out(line_one, 0.8)
	await _fade_in(credits, 1.2)
	await get_tree().create_timer(1.8).timeout
	await _fade_in(thanks, 1.2)
	await _fade_in(hint, 0.8)

	_finished = true


func _fade_in(node: Label, time: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", 1.0, time)
	await t.finished


func _fade_out(node: Label, time: float) -> void:
	var t := create_tween()
	t.tween_property(node, "modulate:a", 0.0, time)
	await t.finished


func _unhandled_input(event: InputEvent) -> void:
	if not _finished:
		return

	var go := false

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		go = true

	if event is InputEventMouseButton and event.pressed:
		go = true

	if not go:
		return

	get_viewport().set_input_as_handled()

	# Fresh run next time.
	GameState.reset_run()
	ObjectiveHUD.show_gameplay_hud()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/main_menu.tscn")
