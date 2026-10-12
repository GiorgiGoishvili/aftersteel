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
## while Kiren is within reach of using them. Also hidden over an NPC who is
## showing the question mark: in that NPC's map the mark already says where
## to go, and the hand returns to the exits everywhere else. And it never
## sits on Kiren: where he stands over its spot (arriving at a map beside
## the exit it marks, say) it stays hidden until he steps off it.

## What can be seen of the hand over its whole bob (measured on the art),
## pointing up/down and left/right, and of Kiren, around their centres.
const HAND_UPRIGHT := Vector2(16, 32)
const HAND_SIDEWAYS := Vector2(32, 16)
const KIREN := Vector2(16, 31)
## Edges that only touch (the hand's lowest bob against his hair) don't count.
const SLACK := 2.0

@onready var hand: AnimatedSprite2D = $HandPointer


func _ready() -> void:
	visible = false


func _process(_delta: float) -> void:
	var place := {}

	if not GameState.input_locked and GameState.objective_target != "":
		var map := get_tree().current_scene
		var target := QuestTargets.node_for(map, GameState.objective_target)

		if not (target != null and target.has_method("wants_attention") and target.wants_attention()):
			place = QuestTargets.marker(map, GameState.objective_target)

	if place.is_empty() or (place.get("hide_in_reach", false) and place["reach"] != null and place["reach"].is_player_in_range()):
		visible = false
		return

	# Whole pixels: the marker never shimmers between them.
	var at := (place["position"] as Vector2).round()

	if _covers_kiren(at, place["point"]):
		visible = false
		return

	if hand.direction != place["point"]:
		hand.direction = place["point"]

	global_position = at
	visible = true


func _covers_kiren(at: Vector2, point: String) -> bool:
	var kiren := get_tree().get_first_node_in_group("player") as Node2D

	if kiren == null:
		return false

	var size := HAND_UPRIGHT if point == "up" or point == "down" else HAND_SIDEWAYS
	return Rect2(at - size / 2.0, size).grow(-SLACK).intersects(Rect2(kiren.global_position - KIREN / 2.0, KIREN).grow(-SLACK))
