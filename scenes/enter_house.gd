extends Area2D


func _on_enter_house_body_entered(body):
	if body.name == "Player":
		GameState.next_spawn = "from_village"

		get_tree().call_deferred(
			"change_scene_to_file",
			"res://scenes/kiren_eira_house_interior.tscn"
		)
