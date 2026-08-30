extends Node2D

## Shared behaviour for the outdoor western maps.
##
## Keeps the existing transition contract: GameState.next_spawn carries the
## NAME of a Marker2D in this scene, set by whichever MapExit was walked
## through. Anything unrecognised leaves the player at the editor position.

func _ready() -> void:
	Music.fade_to("casual")
	call_deferred("_set_spawn")


func _set_spawn() -> void:
	var player := find_child("Player", true, false)

	if player == null:
		return

	if GameState.next_spawn != "":
		var marker := find_child(GameState.next_spawn, true, false)

		if marker != null:
			player.global_position = marker.global_position

	GameState.next_spawn = ""
