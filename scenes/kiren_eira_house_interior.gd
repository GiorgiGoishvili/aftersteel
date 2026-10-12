extends Node2D

const OBJECTIVE_FIREWOOD := "Bring in firewood"

const EIRA_INTRO_LINES := [
	{ "speaker": "EIRA", "text": "There you are." },
	{ "speaker": "EIRA", "text": "We're almost out of firewood." },
	{ "speaker": "EIRA", "text": "There should still be some stacked outside." },
	{ "speaker": "EIRA", "text": "Bring a few logs in for me?" },
	{ "speaker": "KIREN", "text": "Alright." }
]

# Then she sends him round the village (GameState.VILLAGERS).
const EIRA_DONE_LINES := [
	{ "speaker": "EIRA", "text": "Thanks." },
	{ "speaker": "KIREN", "text": "Anything else?" },
	{ "speaker": "EIRA", "text": "Kiren, everyone's been asking for you today." },
	{ "speaker": "EIRA", "text": "Why don't you go see them?" }
]


func _ready():
	call_deferred("_set_spawn")


func _set_spawn():
	Music.fade_to("casual")

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

	_maybe_start_eira_intro()


# Eira only flags Kiren down the first time. The flag lives in GameState, so
# walking back in from the village later does not replay the conversation.
func _maybe_start_eira_intro() -> void:
	if GameState.has_flag("eira_firewood_quest_started"):
		return

	if not GameState.has_flag("mom_letter_read"):
		return

	GameState.input_locked = true

	await get_tree().create_timer(0.4).timeout

	Dialogue.start(EIRA_INTRO_LINES)
	await Dialogue.finished

	GameState.set_flag("eira_firewood_quest_started", true)
	GameState.set_objective(OBJECTIVE_FIREWOOD, "woodpile")


func _on_eira_interacted() -> void:
	if GameState.has_flag("eira_firewood_quest_completed"):
		# Still people to see: a nudge rather than the thanks.
		var text := "Go on. They've been asking all morning." if GameState.next_villager() != "" else "Thanks again."
		Dialogue.start([
			{ "speaker": "EIRA", "text": text }
		])
		return

	if GameState.has_item("firewood_bundle"):
		Dialogue.start([
			{ "speaker": "EIRA", "text": "Just set it by the fire." }
		])
		return

	Dialogue.start([
		{ "speaker": "EIRA", "text": "The wood's outside." }
	])


func _on_fireplace_interacted() -> void:
	if not GameState.has_item("firewood_bundle"):
		Dialogue.start([
			{ "speaker": "KIREN", "text": "It's burning fine." }
		])
		return

	GameState.remove_item("firewood_bundle")
	GameState.set_flag("eira_firewood_quest_completed", true)

	Dialogue.start(EIRA_DONE_LINES)
	await Dialogue.finished

	GameState.set_flag("village_intro_started", true)
	GameState.refresh_objective()
