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
	"WesternWoods",
	"WesternRuins",
]

@onready var label: Label = $ObjectiveText
@onready var tutorial: Label = $TutorialText
@onready var hp_text: Label = $HealthBox/HealthText
@onready var hp_bar: ProgressBar = $HealthBox/HealthBar

## Set false to force the HUD off regardless of scene (used by cutscenes).
var allowed := true

var _last_scene := ""


func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.tutorial_changed.connect(_on_tutorial_changed)
	GameState.player_health_changed.connect(_on_health_changed)

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


func _on_objective_changed(text: String) -> void:
	label.text = text
	label.visible = text != ""


func _on_tutorial_changed(text: String) -> void:
	tutorial.text = text
	tutorial.visible = text != ""


## Small persistent health readout. Sits under the objective lines so it
## never covers the dialogue box, which owns the bottom of the screen.
func _on_health_changed(current: int, maximum: int) -> void:
	hp_text.text = "KIREN   %d / %d" % [current, maximum]
	hp_bar.max_value = maximum
	hp_bar.value = current
