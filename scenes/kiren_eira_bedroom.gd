extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud = $UI/HUD


func _ready():
	call_deferred("_set_spawn")


func _set_spawn():
	# Coming from the philosophical / ZZZ intro
	if GameState.next_spawn == "from_intro":
		var spawn_from_intro = find_child("SpawnFromIntro", true, false)

		if spawn_from_intro != null:
			player.global_position = spawn_from_intro.global_position

		# Small cinematic pause after cutting into the bedroom
		player.set_physics_process(false)

		await get_tree().create_timer(0.5).timeout

		hud.start_dialogue()

		GameState.next_spawn = ""
		return


	# Coming upstairs from the living room
	if GameState.next_spawn == "from_living_room":
		var spawn_from_living_room = find_child(
			"SpawnFromLivingRoom",
			true,
			false
		)

		if spawn_from_living_room != null:
			player.global_position = spawn_from_living_room.global_position

		GameState.next_spawn = ""
