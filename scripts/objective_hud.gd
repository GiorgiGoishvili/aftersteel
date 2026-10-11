extends CanvasLayer

## The overworld gameplay HUD: current objective, one-time tutorial hint
## and Kiren's health.
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

## Screen pixels per art pixel. Whole numbers keep the pixel art crisp:
## 5 draws the bar 595x195 on the 1920x1080 view.
@export_range(1, 8) var health_bar_scale := 5:
	set(value):
		health_bar_scale = value
		if is_node_ready():
			_layout()

@onready var label: Label = $ObjectiveText
@onready var tutorial: Label = $TutorialText
@onready var hp_bar: TextureRect = $HealthBox/HealthBar

## Set false to force the HUD off regardless of scene (used by cutscenes).
var allowed := true

var _last_scene := ""


func _ready() -> void:
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


## The bar at its scale in the top-left corner, with the objective and the
## hint stacked under it so a bigger bar never covers them.
func _layout() -> void:
	var drawn := HEALTH_FRAME_CROP.size * health_bar_scale
	var box: Control = $HealthBox
	box.position = HEALTH_BAR_MARGIN
	box.size = drawn
	hp_bar.position = Vector2.ZERO
	hp_bar.size = drawn
	label.position.y = box.position.y + drawn.y + 11.0
	tutorial.position.y = label.position.y + 56.0


func _on_objective_changed(text: String) -> void:
	label.text = text
	label.visible = text != ""


func _on_tutorial_changed(text: String) -> void:
	tutorial.text = text
	tutorial.visible = text != ""


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
