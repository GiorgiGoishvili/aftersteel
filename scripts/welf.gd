extends "res://scripts/npc.gd"

## Welf: the sword (npc.gd's gift), then a small job - three slimes in the
## west field. He offers it when he is Kiren's objective (or nothing else is
## on), since the HUD carries one objective at a time; until then he is the
## usual Welf.
##
## Progress lives in GameState (slimes_defeated, counted as slimes die), so
## it survives the walk to the outskirts and back.

const OFFER_LINES := [
	"Slimes keep coming in from the west field.",
	"Put three of them down for me.",
]

const REMINDER_LINES := [
	"West of here, past the road.",
]

const DONE_LINES := [
	"Good. That'll keep them off the road for a while.",
]


func _on_talk() -> void:
	if GameState.has_flag("welf_slime_quest_completed"):
		super._on_talk()
		return

	if GameState.slime_quest_active():
		if GameState.slimes_defeated < GameState.SLIME_QUEST_GOAL:
			Dialogue.start(_spoken(REMINDER_LINES))
			return

		Dialogue.start(_spoken(DONE_LINES))
		await Dialogue.finished
		GameState.set_flag("welf_slime_quest_completed", true)
		GameState.set_objective("")
		return

	# Kiren is busy with something else: the sword and the usual line only.
	if GameState.objective != "" and GameState.objective_target != "welf":
		super._on_talk()
		return

	var lines := _greeting() if _gift_due() else []
	lines += _spoken(OFFER_LINES)
	lines.append({ "speaker": "KIREN", "text": "Alright." })

	Dialogue.start(lines)
	await Dialogue.finished

	GameState.set_flag("welf_slime_quest_started", true)
	GameState.slimes_defeated = 0
	GameState.set_objective(GameState.slime_quest_objective(), "slime_clearing")
