extends CanvasLayer

## The pause menu (Esc). Freezes the game underneath, dims it a little and
## shows the menu art with real buttons laid over its wooden buttons.
##
## Opens only in ordinary play: not on the title or during a cutscene, and
## never over a conversation or the inventory, which keep Esc for
## themselves. Everything else pauses with the tree; this layer keeps
## running so the menu still answers.
##
## There is no settings screen yet, so SETTINGS shows as unavailable.
## Nothing is saved, so MAIN MENU asks twice.

## A spot of plain paper in the art: that colour is "not a button".
const PAPER_AT := Vector2i(30, 100)
## The empty paper under the buttons, in art pixels, for the leave prompt.
const NOTE_AREA := Rect2i(24, 91, 80, 22)

const TITLE_SCENE := "res://scenes/main_menu.tscn"

## Screen pixels per art pixel. Whole numbers keep the pixel art crisp:
## 6 draws the 128 px art 768 px tall on the 1920x1080 view.
@export_range(1, 8) var menu_scale := 6:
	set(value):
		menu_scale = value
		if is_node_ready():
			_layout()

@onready var menu: TextureRect = $Menu
@onready var resume_button: Button = $Menu/Resume
@onready var settings_button: Button = $Menu/Settings
@onready var main_menu_button: Button = $Menu/MainMenu
@onready var note: Label = $Menu/Note

var is_open := false

# True after the first press of MAIN MENU, until the second or a change of mind.
var _leaving := false


func _ready() -> void:
	var art := menu.texture.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)

	for b in [resume_button, settings_button, main_menu_button]:
		b.cut_from(art, art.get_pixelv(PAPER_AT))

	resume_button.pressed.connect(close)
	main_menu_button.pressed.connect(_on_main_menu)
	resume_button.focus_entered.connect(_change_of_mind)

	_layout()
	hide()


## Ordinary play only: a gameplay map with its HUD up, and nothing else -
## a conversation, the inventory, a cutscene - holding the input.
func can_open() -> bool:
	return ObjectiveHUD.visible and not GameState.input_locked \
		and not Dialogue.is_active() and not InventoryUI.is_open


func open() -> void:
	if is_open:
		return

	is_open = true
	_change_of_mind()
	show()
	get_tree().paused = true
	resume_button.grab_focus()


func close() -> void:
	if not is_open:
		return

	is_open = false
	_change_of_mind()

	var focused := get_viewport().gui_get_focus_owner()

	if focused != null:
		focused.release_focus()

	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		if event.is_action_pressed("ui_cancel") and can_open():
			get_viewport().set_input_as_handled()
			open()
		return

	get_viewport().set_input_as_handled()

	if event.is_action_pressed("ui_cancel"):
		close()
	elif event.is_action_pressed("move_up"):
		_step(-1)
	elif event.is_action_pressed("move_down"):
		_step(1)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		var b := get_viewport().gui_get_focus_owner() as Button

		if b != null and menu.is_ancestor_of(b):
			await b.flash()

			if is_open:
				b.pressed.emit()


## W and S move between the buttons that can be chosen, wrapping round,
## the same as the arrow keys.
func _step(by: int) -> void:
	var live := _choosable()
	var at := live.find(get_viewport().gui_get_focus_owner())
	live[wrapi(at + by, 0, live.size())].grab_focus()


func _choosable() -> Array[Button]:
	var live: Array[Button] = []

	for b in [resume_button, settings_button, main_menu_button]:
		if not b.disabled:
			live.append(b)

	return live


func _on_main_menu() -> void:
	if not _leaving:
		_leaving = true
		note.show()
		return

	close()
	GameState.reset_run()
	get_tree().call_deferred("change_scene_to_file", TITLE_SCENE)


## Backing out of leaving: another button, or closing the menu.
func _change_of_mind() -> void:
	_leaving = false
	note.hide()


## The art centred at its scale, each button over its own drawing and the
## prompt on the paper beneath them. The arrow keys follow the same order
## as W and S.
func _layout() -> void:
	menu.size = Vector2(menu.texture.get_size()) * menu_scale
	menu.position = ((get_viewport().get_visible_rect().size - menu.size) / 2.0).round()

	for b in [resume_button, settings_button, main_menu_button]:
		b.position = Vector2(b.region.position) * menu_scale
		b.size = Vector2(b.region.size) * menu_scale

	note.position = Vector2(NOTE_AREA.position) * menu_scale
	note.size = Vector2(NOTE_AREA.size) * menu_scale
	note.add_theme_font_size_override("font_size", roundi(menu_scale * 13 / 3.0))

	var live := _choosable()

	for i in live.size():
		var up := live[wrapi(i - 1, 0, live.size())]
		var down := live[wrapi(i + 1, 0, live.size())]
		live[i].focus_neighbor_top = live[i].get_path_to(up)
		live[i].focus_neighbor_bottom = live[i].get_path_to(down)
		live[i].focus_previous = live[i].get_path_to(up)
		live[i].focus_next = live[i].get_path_to(down)
