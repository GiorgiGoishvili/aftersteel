extends Node2D

## The hand that floats beside Kiren and points toward his current objective
## (GameState.objective_target, placed by QuestTargets: the target itself or
## the exit toward it). It sits on that side of him - right, left, above or
## below - and points the same way. A child of the player, so it follows him;
## nothing to touch: no collision, no input.
##
## Hidden when there is no target, while dialogue, menus or cutscenes hold
## the input, and once Kiren has arrived.

## Where the hand sits, from Kiren's centre, for each direction. Clear of
## his body and the sword he holds.
const OFFSETS := {
	"right": Vector2(26, 0),
	"left": Vector2(-26, 0),
	"up": Vector2(0, -32),
	"down": Vector2(0, 30),
}

## Hidden once Kiren is this close to the target: he's there.
@export var arrive_distance := 40.0
## A new direction has to win by this much (ratio of the two axes) before
## the hand turns, so it doesn't flicker along a diagonal.
@export var switch_ratio := 1.3
## How fast the hand glides to a new side (higher = quicker).
@export var glide := 12.0

@onready var hand: AnimatedSprite2D = $HandPointer

var direction := ""


func _ready() -> void:
	visible = false


func _process(delta: float) -> void:
	var goal: Variant = _goal()

	if goal == null:
		visible = false
		direction = ""
		return

	var kiren := get_parent() as Node2D
	var turn := _direction_for(goal - kiren.global_position)

	if direction == "" or not visible:
		# Appearing: start on the right side at once.
		position = OFFSETS[turn]

	direction = turn
	hand.direction = turn
	position = position.lerp(OFFSETS[turn], 1.0 - exp(-glide * delta))

	if position.distance_to(OFFSETS[turn]) < 0.25:
		position = OFFSETS[turn]

	visible = true


func _goal() -> Variant:
	var kiren := get_parent()

	if GameState.input_locked or GameState.objective_target == "" or kiren.get("_defeated"):
		return null

	var goal: Variant = QuestTargets.locate(get_tree().current_scene, GameState.objective_target)

	if goal == null or (goal as Vector2).distance_to(kiren.global_position) < arrive_distance:
		return null

	return goal


## Four ways only; the current one holds until the other axis clearly wins.
func _direction_for(to_goal: Vector2) -> String:
	var across := absf(to_goal.x)
	var along := absf(to_goal.y)
	var sideways := "right" if to_goal.x > 0.0 else "left"
	var updown := "down" if to_goal.y > 0.0 else "up"

	if direction in ["left", "right"]:
		return updown if along > across * switch_ratio else sideways

	if direction in ["up", "down"]:
		return sideways if across > along * switch_ratio else updown

	return sideways if across >= along else updown
