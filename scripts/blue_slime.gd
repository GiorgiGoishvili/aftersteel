extends "res://scripts/npc.gd"

## The friendly Blue Slime by Welf's yard. It lives in the village like the
## other villagers: it stands and idles (front idle only), talks, and that
## is all. No AI, no attacks, no hurtbox - Kiren's sword only finds enemy
## hurtboxes - and it is never in the "enemies" group, so it can't be hit
## and never counts as a kill.
##
## Its job for Kiren, moved here from Welf: put down ten red slimes in the
## west field. It offers it once Eira has sent Kiren round the village and
## he has a sword to do it with; before that it only says hello, and the
## job is still there when he comes back. Progress is
## GameState.slimes_defeated, counted as red slimes die. Kiren hands it in
## here, and the question mark comes back over it when he can.
##
## Its talk area (blue_slime.tscn) is centred on it rather than below it,
## so a creature this small can be talked to from any side.

const HELLO_LINES := [
	"Morning, Kiren.",
]

## Eira's errand is done but Kiren has no sword yet.
const NO_SWORD_LINES := [
	"Kiren. The red ones are back in the west field.",
	"You'll want a sword for them. Welf was asking after you.",
]

const OFFER_LINES := [
	"Kiren. The red ones keep coming in from the west field.",
	"They don't listen to me. They never have.",
	"Could you put ten of them down?",
]

const REMINDER_LINES := [
	"West of here, past the road.",
]

const DONE_LINES := [
	"Good. That'll keep them off the road for a while.",
]

const AFTER_LINES := [
	"It's been quiet out west.",
]


func _on_talk() -> void:
	if GameState.has_flag("slime_quest_completed"):
		Dialogue.start(_spoken(AFTER_LINES))
		return

	if GameState.slime_quest_active():
		if GameState.slimes_defeated < GameState.SLIME_QUEST_GOAL:
			Dialogue.start(_spoken(REMINDER_LINES))
			return

		# Recorded first, so the job can't be handed in twice.
		GameState.set_flag("slime_quest_completed")
		Dialogue.start(_spoken(DONE_LINES))
		await Dialogue.finished
		GameState.refresh_objective()
		return

	if not GameState.has_flag("village_intro_started"):
		Dialogue.start(_spoken(HELLO_LINES))
		return

	if not _has_sword():
		Dialogue.start(_spoken(NO_SWORD_LINES))
		return

	# Taken as it is offered: one start, counted from zero.
	GameState.set_flag("slime_quest_started")
	GameState.slimes_defeated = 0
	_meet()

	var lines := _spoken(OFFER_LINES)
	lines.append({ "speaker": "KIREN", "text": "Alright." })
	Dialogue.start(lines)
	await Dialogue.finished
	GameState.refresh_objective()


## The question mark: the job to take (npc.gd: not met yet), or to hand in.
func wants_attention() -> bool:
	if GameState.slime_quest_active():
		return GameState.slimes_defeated >= GameState.SLIME_QUEST_GOAL

	return super.wants_attention()


## Carrying a sword, held or in the pack.
func _has_sword() -> bool:
	for entry in GameState.inventory:
		if entry.get("type", "") == "weapon":
			return true
	return false
