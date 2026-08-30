extends CanvasLayer

## Temporary development display for the current objective and the
## one-time tutorial hint.
##
## It only mirrors GameState onto two plain Labels. When the real pixel-art
## UI exists, replace objective_label.tscn and leave this logic (and
## everything calling GameState.set_objective / set_tutorial) untouched.

@onready var label: Label = $ObjectiveText
@onready var tutorial: Label = $TutorialText


func _ready() -> void:
	GameState.objective_changed.connect(_on_objective_changed)
	GameState.tutorial_changed.connect(_on_tutorial_changed)

	_on_objective_changed(GameState.objective)
	_on_tutorial_changed(GameState.tutorial_hint)


func _on_objective_changed(text: String) -> void:
	label.text = text
	label.visible = text != ""


func _on_tutorial_changed(text: String) -> void:
	tutorial.text = text
	tutorial.visible = text != ""
