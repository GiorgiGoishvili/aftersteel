extends Area2D

func _on_go_to_living_room_body_entered(body):
	if body.name == "Player":
		GameState.next_spawn = "from_bedroom"
		get_tree().call_deferred(
			"change_scene_to_file",
			"res://scenes/kiren_eira_house_interior.tscn"
		)
