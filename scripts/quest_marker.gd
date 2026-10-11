extends Node2D

## The objective marker: the hand, placed by QuestTargets at the current
## objective - over a character's head pointing down, beside a target
## pointing at it, or at the exit toward a target in another map pointing the
## way through. It stays put in the world while Kiren moves; nothing to
## touch, no collision. One marker for the whole game (an autoload), so there
## are never two.
##
## Hidden when there is no objective target, inside a quest area's own map
## (the slime field), while dialogue, menus or cutscenes hold the input - so
## it goes the moment Kiren interacts - and, for targets that ask for it,
## while Kiren is within reach of using them.

@onready var hand: AnimatedSprite2D = $HandPointer


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var place := {}

	if not GameState.input_locked and GameState.objective_target != "":
		place = QuestTargets.marker(get_tree().current_scene, GameState.objective_target)

	if place.is_empty() or (place.get("hide_in_reach", false) and place["reach"] != null and place["reach"].is_player_in_range()):
		visible = false
		return

	if hand.direction != place["point"]:
		hand.direction = place["point"]

	# Whole pixels: the marker never shimmers between them.
	global_position = (place["position"] as Vector2).round()
	visible = true
