extends Area2D

## Where to put Kiren when the story refuses to let him leave yet.
## Sits just inside the bedroom, clear of this trigger, so he is never
## left standing in the doorway with nothing stopping him walking
## straight up out of the room.
@export var return_marker_path: NodePath = ^"../BlockedExitReturn"

@onready var return_marker: Node2D = get_node_or_null(return_marker_path)


func _on_go_to_living_room_body_entered(body):
	if body.name != "Player":
		return

	# Opening sequence only. Kiren stops himself rather than the game
	# showing an error. Cleared for good once the chest has been checked.
	if GameState.has_flag("intro_chest_gate_active"):
		# Step him back into the room BEFORE the thought appears, so the
		# box closes onto him already standing somewhere safe.
		if return_marker != null:
			body.velocity = Vector2.ZERO
			body.global_position = return_marker.global_position

		Dialogue.start([
			{
				"speaker": "KIREN",
				"text": "Right. The chest."
			}
		])
		return

	GameState.next_spawn = "from_bedroom"
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/kiren_eira_house_interior.tscn"
	)
