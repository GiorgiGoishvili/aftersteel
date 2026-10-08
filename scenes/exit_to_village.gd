extends Area2D


func _on_exit_to_village_body_entered(body):
	# The room's own wall body ("Collisions") overlaps this area too; only
	# Kiren leaves through the door.
	if not body.is_in_group("player"):
		return

	print("EXIT TRIGGERED: ", body.name)
	get_tree().call_deferred(
		"change_scene_to_file",
		"res://scenes/Village.tscn"
	)


func _on_body_entered(_body: Node2D) -> void:
	pass
