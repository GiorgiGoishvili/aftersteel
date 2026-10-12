extends CanvasLayer

## The overworld gameplay HUD: current objective, one-time tutorial hint
## and Kiren's health.
##
## The objective sits on a small wooden plate under the health bar (the plain
## plate from the inventory art, nine-sliced, at the bar's pixel scale), with
## an optional smaller step line, and slides in / flashes when it changes.
## Hints sit on the same plate at the bottom centre, clear of Kiren, and
## fade in and out; the keys are picked out in gold.
##
## This is an autoload, so it would otherwise sit on top of the main menu
## and the philosophical intro too. It keeps itself hidden unless the
## scene currently running is actual gameplay. Battle is excluded because
## the battle scene draws its own health panels.

## Scene ROOT NODE names that count as gameplay. Add a new overworld map
## here and its HUD works with no other changes.
const GAMEPLAY_SCENES := [
	"KirenEiraBedroom",
	"KirenEiraHouseInterior",
	"Village",
	"WesternOutskirts",
	"WesternRiver",
	"AutumnForest",
	"RockyHighlands",
	"SnowyRegion",
	"Beach",
	"DeadForest",
]

## The health bar art (AftersteelHealthBar.png): one 128x128 frame per health
## state, full first, the meter draining right to left. Not an animation -
## exactly one frame shows, picked from Kiren's health.
const HEALTH_FRAME_SIZE := 128
## The drawn part of each frame (the rest is empty canvas).
const HEALTH_FRAME_CROP := Rect2(7, 45, 119, 39)
## How full each frame's meter is drawn, frame by frame (red pixels across
## the 97 px meter, measured on the art: the steps are uneven, 4-6 px).
const HEALTH_FRAME_FILL := [
	1.0, 0.959, 0.897, 0.845, 0.784, 0.732, 0.670, 0.619, 0.557, 0.505,
	0.443, 0.392, 0.330, 0.278, 0.216, 0.165, 0.113, 0.052, 0.0,
]
## Gap between the bar and the screen's top-left corner.
const HEALTH_BAR_MARGIN := Vector2(24, 24)

## The Plate nodes are the plain wooden plate in Equipment.png (the inventory
## art), nine-sliced; its top and bottom edges are this many art pixels.
const PLATE_EDGES := { "top": 2, "bottom": 4 }
## Text inset from the plate's outer edge, in screen pixels.
const PLATE_PAD := Vector2(24, 10)
## The objective plate: this far right of the bar's left edge, and this far
## below it.
const OBJECTIVE_OFFSET := Vector2(16, 8)
const STEP_GAP := 2.0
## Hints: centred, this far above the bottom of the screen.
const HINT_BOTTOM := 96.0
## A hint's keys are drawn in gold, and "WASD — Move" draws its dash as a
## rule (the font has no em dash).
const KEY_COLOUR := Color(0.98, 0.78, 0.34)
const KEY_WORDS := ["J / Left Click"]
const DASH := " — "
const INK := Color(0.925, 0.835, 0.576)
const FLASH := Color(1.7, 1.55, 1.2)

## Screen pixels per art pixel. Whole numbers keep the pixel art crisp:
## 5 draws the bar 595x195 on the 1920x1080 view.
@export_range(1, 8) var health_bar_scale := 5:
	set(value):
		health_bar_scale = value
		if is_node_ready():
			_layout()

@onready var objective_box: Control = $ObjectiveBox
@onready var label: Label = $ObjectiveBox/ObjectiveText
@onready var step_label: Label = $ObjectiveBox/ObjectiveStep
@onready var tutorial_box: Control = $TutorialBox
@onready var tutorial: HBoxContainer = $TutorialBox/TutorialText
@onready var hp_bar: TextureRect = $HealthBox/HealthBar

## Set false to force the HUD off regardless of scene (used by cutscenes).
var allowed := true

var _last_scene := ""
var _shown_objective := ""
var _shown_step := ""
var _objective_tween: Tween
var _slide_tween: Tween
var _tutorial_tween: Tween


func _ready() -> void:
	# The fishing minigame pauses the game; its hint still fades in.
	process_mode = Node.PROCESS_MODE_ALWAYS
	objective_box.visible = false
	tutorial_box.visible = false

	GameState.objective_changed.connect(_on_objective_changed)
	GameState.tutorial_changed.connect(_on_tutorial_changed)
	GameState.player_health_changed.connect(_on_health_changed)

	_layout()
	_on_objective_changed(GameState.objective)
	_on_tutorial_changed(GameState.tutorial_hint)
	_on_health_changed(GameState.get_player_hp(), GameState.get_player_max_hp())

	visible = false
	get_tree().tree_changed.connect(_refresh_visibility)
	_refresh_visibility()


## Explicit overrides, for anything that needs the HUD gone during a
## scene that is otherwise gameplay.
func show_gameplay_hud() -> void:
	allowed = true
	_refresh_visibility()


func hide_gameplay_hud() -> void:
	allowed = false
	visible = false


func _refresh_visibility() -> void:
	# tree_changed also fires while the tree is being torn down.
	if not is_inside_tree():
		return

	var tree := get_tree()

	if tree == null:
		return

	var scene := tree.current_scene

	if scene == null:
		visible = false
		return

	if scene.name == _last_scene and not allowed:
		return

	_last_scene = scene.name
	visible = allowed and GAMEPLAY_SCENES.has(scene.name)


## The bar at its scale in the top-left corner, with the objective plate
## under it so a bigger bar never covers it, and the hint plate centred at
## the bottom.
func _layout() -> void:
	var drawn := HEALTH_FRAME_CROP.size * health_bar_scale
	var box: Control = $HealthBox
	box.position = HEALTH_BAR_MARGIN
	box.size = drawn
	hp_bar.position = Vector2.ZERO
	hp_bar.size = drawn

	# The objective's text, then its plate around it.
	label.size = label.get_minimum_size()
	step_label.size = step_label.get_minimum_size()
	label.position = PLATE_PAD
	step_label.position = Vector2(PLATE_PAD.x, label.position.y + label.size.y + STEP_GAP)
	var inner := Vector2(maxf(label.size.x, step_label.size.x if step_label.visible else 0.0),
		label.size.y + (STEP_GAP + step_label.size.y if step_label.visible else 0.0))
	objective_box.size = _fit_plate(objective_box.get_node("Plate"), inner)
	objective_box.position = (HEALTH_BAR_MARGIN + Vector2(OBJECTIVE_OFFSET.x, drawn.y + OBJECTIVE_OFFSET.y)).round()

	tutorial.size = tutorial.get_combined_minimum_size()
	tutorial.position = PLATE_PAD
	tutorial_box.size = _fit_plate(tutorial_box.get_node("Plate"), tutorial.size)
	var view := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"),
		ProjectSettings.get_setting("display/window/size/viewport_height"))
	tutorial_box.position = Vector2((view.x - tutorial_box.size.x) / 2.0, view.y - HINT_BOTTOM - tutorial_box.size.y).round()


## Sizes a plate around `inner` (plus the padding) on whole art pixels, so
## its edges stay crisp at the bar's scale. Returns the plate's screen size.
func _fit_plate(plate: NinePatchRect, inner: Vector2) -> Vector2:
	var k := float(health_bar_scale)
	var art := ((inner + PLATE_PAD * 2.0) / k).ceil()
	art.y += PLATE_EDGES["bottom"] - PLATE_EDGES["top"]   # the plate's thicker bottom edge
	plate.scale = Vector2(k, k)
	plate.size = art
	return art * k


func _on_objective_changed(_text: String) -> void:
	var text := GameState.objective
	var step := GameState.objective_detail if text != "" else ""

	if text == _shown_objective and step == _shown_step:
		return

	# The same objective moving on ("Defeat Red Slimes: 3/10" -> "4/10", or
	# the next villager to visit) flashes in place; a new one slides in.
	var new_one := _shown_objective == "" or text.get_slice(":", 0) != _shown_objective.get_slice(":", 0)
	_shown_objective = text
	_shown_step = step

	for tween in [_objective_tween, _slide_tween]:
		if tween != null:
			tween.kill()

	if text == "":
		_slide_tween = create_tween()
		_slide_tween.tween_property(objective_box, "modulate:a", 0.0, 0.2)
		_slide_tween.tween_callback(objective_box.hide)
		return

	label.text = text
	step_label.text = step
	step_label.visible = step != ""
	_layout()
	objective_box.visible = true
	objective_box.modulate.a = 1.0

	if new_one:
		# Sideways only, so a re-layout meanwhile (a new bar scale) still
		# moves it down.
		var x := objective_box.position.x
		objective_box.position.x = x - 48.0
		objective_box.modulate.a = 0.0
		_slide_tween = create_tween().set_parallel()
		_slide_tween.tween_property(objective_box, "position:x", x, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_slide_tween.tween_property(objective_box, "modulate:a", 1.0, 0.25)

	# Two quick brightenings of the text, so the change catches the eye.
	_objective_tween = create_tween()

	for i in 2:
		_objective_tween.tween_property(label, "modulate", FLASH, 0.12)
		_objective_tween.parallel().tween_property(step_label, "modulate", FLASH, 0.12)
		_objective_tween.tween_property(label, "modulate", Color.WHITE, 0.45)
		_objective_tween.parallel().tween_property(step_label, "modulate", Color.WHITE, 0.45)


func _on_tutorial_changed(text: String) -> void:
	if _tutorial_tween != null:
		_tutorial_tween.kill()

	_tutorial_tween = create_tween()

	if text == "":
		_tutorial_tween.tween_property(tutorial_box, "modulate:a", 0.0, 0.25)
		_tutorial_tween.tween_callback(tutorial_box.hide)
		return

	_fill_hint(text)
	_layout()
	tutorial_box.visible = true
	tutorial_box.modulate.a = 0.0
	_tutorial_tween.tween_property(tutorial_box, "modulate:a", 1.0, 0.25)


## The hint as a row of labels: keys in gold, the rest in the plate's ink.
## "Keys — Action" draws its dash as a short rule.
func _fill_hint(text: String) -> void:
	for child in tutorial.get_children():
		tutorial.remove_child(child)
		child.queue_free()

	if text.contains(DASH):
		tutorial.add_child(_hint_label(text.get_slice(DASH, 0), KEY_COLOUR))
		var dash := ColorRect.new()
		dash.color = INK
		dash.custom_minimum_size = Vector2(6, 1) * health_bar_scale
		dash.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tutorial.add_child(dash)
		tutorial.add_child(_hint_label(text.get_slice(DASH, 1), INK))
		return

	var rest := text

	for key in KEY_WORDS:
		var at := rest.find(key)
		if at == -1:
			continue
		if at > 0:
			tutorial.add_child(_hint_label(rest.substr(0, at).strip_edges(), INK))
		tutorial.add_child(_hint_label(key, KEY_COLOUR))
		rest = rest.substr(at + key.length()).strip_edges()

	if rest != "":
		tutorial.add_child(_hint_label(rest, INK))


func _hint_label(text: String, colour: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Kiren's health bar, top left, no numbers: shows the frame for his health.
## Clear of the dialogue box, which owns the bottom of the screen.
func _on_health_changed(current: int, maximum: int) -> void:
	var frame := health_frame(current, maximum)
	var region := HEALTH_FRAME_CROP
	region.position.x += frame * HEALTH_FRAME_SIZE
	(hp_bar.texture as AtlasTexture).region = region


## The frame whose drawn fill is closest to current / maximum - except that
## only full health shows the full bar and only zero shows the empty one, so
## any hit visibly drains it and a living Kiren never looks dead. Always a
## valid frame, even with no maximum yet.
static func health_frame(current: int, maximum: int) -> int:
	var empty := HEALTH_FRAME_FILL.size() - 1

	if maximum <= 0 or current >= maximum:
		return 0

	if current <= 0:
		return empty

	var share := float(current) / float(maximum)
	var best := 1

	for i in range(1, empty):
		if absf(HEALTH_FRAME_FILL[i] - share) < absf(HEALTH_FRAME_FILL[best] - share):
			best = i

	return best
