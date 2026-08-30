extends CanvasLayer

## Global dialogue box. Registered as the "Dialogue" autoload, so any
## script in any scene can call it without needing a node path:
##
##     Dialogue.start([
##         { "speaker": "EIRA", "text": "KIREN! GET UP!" },
##     ])
##     await Dialogue.finished
##
## A line is a Dictionary. Only "text" is required:
##     text     - the sentence to type out
##     speaker  - optional name shown above the sentence
##     portrait - optional res:// path to a portrait image
##
## A plain String is also accepted as shorthand for { "text": ... }.

signal finished

const TYPE_SPEED := 0.025

## Portrait shown automatically when a line names one of these speakers,
## so ordinary lines never have to repeat the path. Any line that supplies
## its own "portrait" overrides this - that is how alternate expressions
## (angry, wounded, ...) will work later.
##
## A speaker that is not listed here simply gets no portrait, which is why
## "MOM'S LETTER" and unnamed system lines stay portrait-free.
const DEFAULT_PORTRAITS := {
	"KIREN": "res://Assets/UI/KirenDetailedFaces.png",
	"EIRA": "res://Assets/UI/EiraDetailedFaces.png",
}

@onready var box: TextureRect = $Box
@onready var speaker_label: Label = $Box/SpeakerName
@onready var text_label: Label = $Box/DialogueText
@onready var portrait: TextureRect = $Box/Portrait
@onready var continue_hint: Label = $Box/ContinueHint

var _lines: Array = []
var _line_index := 0
var _active := false
var _typing := false

# Bumped every time a new line starts or a line is revealed early.
# A running type loop abandons itself as soon as this no longer matches
# the id it started with, which is what stops two loops from typing the
# same label at once.
var _type_id := 0


func _ready() -> void:
	box.hide()

	# Stops words from jumping around while the typewriter runs.
	text_label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING


func is_active() -> bool:
	return _active


func start(lines: Array) -> void:
	if _active or lines.is_empty():
		return

	_lines = lines
	_line_index = 0
	_active = true

	GameState.input_locked = true

	box.show()
	_show_current_line()


## Reading something written down, rather than someone speaking.
## Shares all the typing/advancing logic - this exists so letters, books
## and signs have one place to grow their own visuals later without
## touching spoken dialogue.
func start_letter(pages: Array, title := "LETTER") -> void:
	var lines: Array = []

	for page in pages:
		lines.append({ "speaker": title, "text": str(page) })

	start(lines)


func _show_current_line() -> void:
	var line: Variant = _lines[_line_index]

	var speaker := ""
	var body := ""
	var portrait_path := ""

	if line is Dictionary:
		speaker = str(line.get("speaker", ""))
		body = str(line.get("text", ""))
		portrait_path = str(line.get("portrait", ""))
	else:
		body = str(line)

	speaker_label.text = speaker
	speaker_label.visible = speaker != ""

	# Explicit portrait wins; otherwise fall back to the speaker's default.
	if portrait_path == "":
		portrait_path = str(DEFAULT_PORTRAITS.get(speaker, ""))

	if portrait_path != "" and ResourceLoader.exists(portrait_path):
		portrait.texture = load(portrait_path)
		portrait.show()
	else:
		portrait.texture = null
		portrait.hide()

	_type_line(body)


func _type_line(body: String) -> void:
	_type_id += 1
	var my_id := _type_id

	_typing = true

	# Hidden while the sentence types itself out, shown once it is done.
	# E still reveals early - _reveal_current_line() brings it back.
	continue_hint.hide()

	text_label.text = body
	text_label.visible_characters = 0

	for i in body.length():
		text_label.visible_characters = i + 1

		await get_tree().create_timer(TYPE_SPEED).timeout

		# Another line started, or the player revealed this one early.
		if my_id != _type_id:
			return

	text_label.visible_characters = -1
	_typing = false
	continue_hint.show()


func _reveal_current_line() -> void:
	# Invalidates whatever loop is running, so it cannot keep typing.
	_type_id += 1
	_typing = false
	text_label.visible_characters = -1
	continue_hint.show()


func _advance() -> void:
	_line_index += 1

	if _line_index >= _lines.size():
		_end()
	else:
		_show_current_line()


func _end() -> void:
	_type_id += 1
	_typing = false
	_active = false

	box.hide()

	GameState.input_locked = false

	finished.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return

	# E only. One key interacts, confirms and advances, so the opening
	# teaches a single rule. No mouse input.
	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo or event.keycode != KEY_E:
		return

	get_viewport().set_input_as_handled()

	# First press while typing reveals the whole sentence.
	if _typing:
		_reveal_current_line()
		return

	_advance()
