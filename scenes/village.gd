extends Node2D

const OBJECTIVE_FIREPLACE := "Put the firewood by the fireplace."


func _ready() -> void:
	Music.fade_to("casual")


func _on_woodpile_interacted() -> void:
	# One pickup is "enough wood", so taking it twice does nothing.
	if GameState.has_flag("eira_firewood_quest_completed") \
	or GameState.has_item("firewood_bundle"):

		Dialogue.start([
			{ "speaker": "KIREN", "text": "Nothing else I need here." }
		])
		return

	GameState.add_item(Items.FIREWOOD_BUNDLE)

	Dialogue.start([
		{ "text": "Picked up: Firewood" }
	])
	await Dialogue.finished

	if GameState.has_flag("eira_firewood_quest_started"):
		GameState.set_objective(OBJECTIVE_FIREPLACE)
