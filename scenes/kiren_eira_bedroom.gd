extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var chest: Interactable = $Chest

const OBJECTIVE_CHEST := "Check the chest."
const OBJECTIVE_DOWNSTAIRS := "Go downstairs and help Eira."

const TUTORIAL_INTERACT := "Press E to interact"

# How gently ordinary-morning music arrives after the intro.
const CASUAL_FADE_IN_TIME := 3.0

# Eira waking Kiren up. Only "text" is required on a line; a known speaker
# gets their portrait automatically (see DEFAULT_PORTRAITS in dialogue.gd).
const INTRO_LINES := [
	{ "speaker": "EIRA", "text": "Kiren." },
	{ "speaker": "EIRA", "text": "Could you get up already." },
	{ "speaker": "EIRA", "text": "I've been calling you for ages." },
	{ "speaker": "EIRA", "text": "Come downstairs. I need a hand." }
]

# One entry per page of the letter. Split for the size of the text box,
# not for drama - resize freely if the box art changes.
const MOM_LETTER := [
	"Kiren,",
	"I left before sunrise.",
	"There's food downstairs. Help Eira with whatever she needs before you disappear for the day.",
	"Take the amulet with you.",
	"The one I told you to keep close.",
	"I know you've asked me why and i haven't given you much of an answer yet.",
	"You don't need one yet.",
	"Just keep it with you.",
	"- Mother"
]

const AFTER_LETTER_LINES := [
	{ "speaker": "KIREN", "text": "Again with the amulet..." },
	{ "speaker": "KIREN", "text": "She never tells me anything about it." },
	{ "text": "Obtained: Family Amulet" }
]


func _ready():
	call_deferred("_set_spawn")


func _set_spawn():
	# Coming from the philosophical / ZZZ intro
	if GameState.next_spawn == "from_intro":
		GameState.next_spawn = ""

		var spawn_from_intro = find_child("SpawnFromIntro", true, false)

		if spawn_from_intro != null:
			player.global_position = spawn_from_intro.global_position

		# Small cinematic pause after cutting into the bedroom
		GameState.input_locked = true

		await get_tree().create_timer(0.5).timeout

		# Ordinary life begins here, under Eira's first line.
		Music.fade_to("casual", 0.0, CASUAL_FADE_IN_TIME)

		Dialogue.start(INTRO_LINES)
		await Dialogue.finished

		# Hold the bedroom door shut until Kiren has read the letter.
		# go_to_living_room.gd checks this flag.
		GameState.set_flag("intro_chest_gate_active", true)
		GameState.set_objective(OBJECTIVE_CHEST)

		# Player gets control for the first time here, so this is where the
		# interaction hint belongs. Interactable clears it on first success.
		if not GameState.has_flag("interaction_tutorial_completed"):
			GameState.set_tutorial(TUTORIAL_INTERACT)
		return


	# Any other way into the bedroom: the casual track is already running,
	# so this call does nothing and the playhead is left alone.
	Music.fade_to("casual")

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


func _on_chest_interacted() -> void:
	# Already read it once - short reminder instead of the whole letter.
	if GameState.has_flag("bedroom_chest_checked"):
		Dialogue.start([
			{ "speaker": "KIREN", "text": "Mother's letter. And the amulet." }
		])
		return

	Dialogue.start_letter(MOM_LETTER, "MOM'S LETTER")
	await Dialogue.finished

	GameState.set_flag("mom_letter_read", true)
	GameState.set_flag("bedroom_chest_checked", true)
	GameState.add_item(Items.FAMILY_AMULET_TRUE)

	# Opening beat is done, so the door gate switches off permanently.
	GameState.set_flag("intro_chest_gate_active", false)

	Dialogue.start(AFTER_LETTER_LINES)
	await Dialogue.finished

	GameState.set_objective(OBJECTIVE_DOWNSTAIRS)
