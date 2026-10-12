extends "res://scripts/npc.gd"

## Toma, the fisherman at the river. He introduces himself the first time;
## every talk then ends in his shop (FishShop). While Kiren is close enough
## to talk, "E — Talk" shows over his head.

const INTRO_FLAG := "toma_met"
const PROMPT := "E — Talk"
## Screen pixels from his feet to the prompt's bottom edge (camera zoom 8).
const PROMPT_RISE := 124.0

var _prompt: Label


func _ready() -> void:
	super._ready()
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)

	_prompt = Label.new()
	_prompt.text = PROMPT
	_prompt.size = Vector2(320, 44)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_prompt.add_theme_font_override("font", load("res://Assets/UI/Fabled_Font.ttf"))
	_prompt.add_theme_font_size_override("font_size", 30)
	_prompt.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_prompt.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_prompt.add_theme_constant_override("outline_size", 8)
	_prompt.hide()
	layer.add_child(_prompt)


func _process(_delta: float) -> void:
	var showing := talk.enabled and talk.is_player_in_range() and not GameState.input_locked \
		and not Dialogue.is_active() and not get_tree().paused
	_prompt.visible = showing

	if showing:
		var at := get_global_transform_with_canvas().origin
		_prompt.position = (at - Vector2(_prompt.size.x / 2.0, PROMPT_RISE + _prompt.size.y)).round()


func _on_talk() -> void:
	Dialogue.start(_greeting())
	await Dialogue.finished
	FishShop.open()


func _greeting() -> Array:
	if not GameState.has_flag(INTRO_FLAG):
		GameState.set_flag(INTRO_FLAG)
		return _spoken(first_lines)

	return _spoken(repeat_lines)
