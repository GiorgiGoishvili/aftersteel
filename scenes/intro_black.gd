extends Control

@onready var intro_text: Label = $IntroText
@onready var sleep_zzz: AnimatedSprite2D = get_node_or_null("SleepZzz") as AnimatedSprite2D

var lines = [
	"A MAN CAN SPEND HIS WHOLE LIFE CHASING STRENGTH...",
	"ONLY TO DISCOVER THAT STRENGTH COULD NOT SAVE WHAT HE HAD LOVED.",
	"STEEL REMEMBERS EVERY BLOW THAT SHAPED IT.",
	"SO DOES A MAN."
]

var typing := false

const TYPE_SPEED := 0.060
const HOLD_TIME := 1.9
const FADE_TIME := 0.45
const SLEEP_SCREEN_TIME := 6.0

# Audio timing. The menu track fades out while the black screen appears,
# then the intro track fades down during the pause before the bedroom.
const MUSIC_FADE_OUT_TIME := 1.2
const MUSIC_FADE_IN_TIME := 2.0
const INTRO_MUSIC_FADE_OUT_TIME := 3.0


func _ready():
	intro_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	intro_text.modulate.a = 0.0

	if sleep_zzz != null:
		sleep_zzz.hide()

	Music.fade_to("intro", MUSIC_FADE_OUT_TIME, MUSIC_FADE_IN_TIME)

	run_intro()


func run_intro():
	# Philosophical text sequence
	for line in lines:
		await show_line(line)
		await get_tree().create_timer(HOLD_TIME).timeout
		await fade_text_out()

	# Philosophical text is finished
	intro_text.hide()

	# Let the track fall away across the black pause instead of cutting it.
	Music.fade_out(INTRO_MUSIC_FADE_OUT_TIME)

	# White ZZZ animation on the SAME black screen
	if sleep_zzz != null:
		sleep_zzz.show()
		sleep_zzz.play("sleep_zzz")

	await get_tree().create_timer(SLEEP_SCREEN_TIME).timeout

	if sleep_zzz != null:
		sleep_zzz.stop()
		sleep_zzz.hide()

	# Bedroom knows this is the first-game intro
	GameState.next_spawn = "from_intro"

	get_tree().change_scene_to_file(
		"res://scenes/kiren_eira_bedroom.tscn"
	)


func show_line(line: String):
	intro_text.show()
	intro_text.text = line
	intro_text.visible_characters = 0
	intro_text.modulate.a = 1.0

	typing = true

	for i in range(line.length()):
		if not typing:
			break

		intro_text.visible_characters += 1
		await get_tree().create_timer(TYPE_SPEED).timeout

	intro_text.visible_characters = -1
	typing = false


func fade_text_out():
	var tween = create_tween()

	tween.tween_property(
		intro_text,
		"modulate:a",
		0.0,
		FADE_TIME
	)

	await tween.finished


func _unhandled_input(event):
	if event.is_action_pressed("ui_accept") and typing:
		typing = false
		intro_text.visible_characters = -1
