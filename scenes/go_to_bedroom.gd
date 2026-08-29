extends Area2D

func _on_go_to_bedroom_body_entered(body):
	if body.name == "Player":
		get_tree().call_deferred(
	"change_scene_to_file",
	"res://scenes/kiren_eira_bedroom.tscn"
)
