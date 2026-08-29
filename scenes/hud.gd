extends Control

@onready var dialogue_box = $DialogueBox
@onready var dialogue_text = $DialogueBox/DialogueText
@onready var player = $"../../Player"

var lines = [
	"KIRIN! HOW LONG ARE YOU GONNA BE ASLEEP FOR?!",
	"GET YOUR ASS UP AND HELP ME ALREADY!",
	"THE FIREWOOD IS ALMOST OUT!"
]

var line_index := 0
var dialogue_active := false
var typing := false

var typing_speed := 0.025


func _ready():
	dialogue_box.hide()

	dialogue_text.visible_characters_behavior = \
		TextServer.VC_CHARS_AFTER_SHAPING


func start_dialogue():
	if dialogue_active:
		return

	dialogue_active = true
	line_index = 0

	dialogue_box.show()

	player.set_physics_process(false)

	show_line()


func show_line():
	typing = true

	dialogue_text.text = lines[line_index]
	dialogue_text.visible_characters = 0

	for i in range(lines[line_index].length()):

		if not typing:
			break

		dialogue_text.visible_characters += 1

		await get_tree().create_timer(
			typing_speed
		).timeout

	if typing:
		dialogue_text.visible_characters = -1

	typing = false


func _unhandled_input(event):
	if not dialogue_active:
		return

	var advance := false

	# E KEY
	if event is InputEventKey:
		if event.pressed \
		and not event.echo \
		and event.keycode == KEY_E:

			advance = true

	# RIGHT MOUSE BUTTON
	if event is InputEventMouseButton:
		if event.pressed \
		and event.button_index == MOUSE_BUTTON_RIGHT:

			advance = true

	if not advance:
		return

	get_viewport().set_input_as_handled()

	# If sentence is still typing:
	# first press reveals the whole sentence.
	if typing:
		typing = false
		dialogue_text.visible_characters = -1
		return

	# Otherwise move to next sentence.
	line_index += 1

	if line_index >= lines.size():
		end_dialogue()
	else:
		show_line()


func end_dialogue():
	dialogue_active = false

	dialogue_box.hide()

	player.set_physics_process(true)
