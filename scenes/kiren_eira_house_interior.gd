extends Node2D

func _ready():
	call_deferred("_set_spawn")

func _set_spawn():
	var player = find_child("Player", true, false)
	var spawn_from_village = find_child("SpawnFromVillage", true, false)
	var spawn_from_bedroom = find_child("SpawnFromBedroom", true, false)

	if player == null:
		print("ERROR: Player not found")
		return

	if GameState.next_spawn == "from_village" and spawn_from_village != null:
		player.global_position = spawn_from_village.global_position

	elif GameState.next_spawn == "from_bedroom" and spawn_from_bedroom != null:
		player.global_position = spawn_from_bedroom.global_position
