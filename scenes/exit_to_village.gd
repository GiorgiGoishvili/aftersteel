extends Area2D


func _on_exit_to_village_body_entered(body):
	print("EXIT TRIGGERED: ", body.name)

	if body.name == "Player":
		get_tree().call_deferred(
			"change_scene_to_file",
			"res://scenes/Village.tscn"
		)


func _on_body_entered(_body: Node2D) -> void:
	pass
