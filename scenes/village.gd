extends Node2D

const OBJECTIVE_FIREPLACE := "Put the firewood by the fireplace."

@onready var woodpile: Node2D = $Props/Woodpile


func _ready() -> void:
	Music.fade_to("casual")
	_refresh_woodpile()


# The logs are the wood Kiren carries in, so once he has taken them the
# stack is gone. Re-checked on every entry because GameState outlives the
# scene and the player can walk in and out freely.
func _refresh_woodpile() -> void:
	var taken: bool = GameState.has_item("firewood_bundle") \
		or GameState.has_flag("eira_firewood_quest_completed")

	woodpile.visible = not taken
	woodpile.get_node("Interact").enabled = not taken


func _on_woodpile_interacted() -> void:
	# One pickup is "enough wood", so taking it twice does nothing.
	if GameState.has_flag("eira_firewood_quest_completed") \
	or GameState.has_item("firewood_bundle"):

		Dialogue.start([
			{ "speaker": "KIREN", "text": "Nothing else I need here." }
		])
		return

	GameState.add_item(Items.FIREWOOD_BUNDLE)
	_refresh_woodpile()

	Dialogue.start([
		{ "text": "Picked up: Firewood" }
	])
	await Dialogue.finished

	if GameState.has_flag("eira_firewood_quest_started"):
		GameState.set_objective(OBJECTIVE_FIREPLACE)
