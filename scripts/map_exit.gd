class_name MapExit
extends Area2D

## Walk-through doorway between two overworld maps.
##
## Same pattern the house/bedroom transitions already use - an Area2D that
## records where the player should appear, then swaps the scene. The only
## difference is that the destination is configured in the editor instead
## of hard-coded, because the western route needs six of these.
##
## "spawn_name" is the NAME of a Marker2D in the target scene. The target
## map script looks that node up and puts the player on it.

@export_file("*.tscn") var target_scene: String = ""
@export var spawn_name: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	# Slimes and other bodies brush exits too; only Kiren may leave a map.
	if not body.is_in_group("player"):
		return

	if target_scene == "":
		push_warning("MapExit with no target_scene: %s" % get_path())
		return

	GameState.next_spawn = spawn_name
	get_tree().call_deferred("change_scene_to_file", target_scene)
