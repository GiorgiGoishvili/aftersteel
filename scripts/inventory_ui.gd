extends CanvasLayer

## Kiren's pack. Opens with I, closes with I or Esc.
##
## Deliberately small: a list, a description, healing items to use and
## weapons to equip. No drag and drop, no slots, no sorting, no weight.
##
## Dialogue outranks it - the screen refuses to open while someone is
## talking, so the two can never fight over E.

@onready var root: Control = $Root
@onready var list: VBoxContainer = $Root/Panel/List
@onready var desc: Label = $Root/Panel/Description
@onready var title: Label = $Root/Panel/Title
@onready var hint: Label = $Root/Panel/Hint
@onready var hp: Label = $Root/Panel/Health

var is_open := false
var _selected := 0
var _rows: Array = []


func _ready() -> void:
	layer = 95
	root.hide()
	GameState.inventory_changed.connect(_refresh)


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	# Dialogue has priority; never steal input from a conversation.
	if is_open or Dialogue.is_active():
		return

	is_open = true
	_selected = 0
	root.show()
	GameState.input_locked = true
	_refresh()
	Sfx.play("inventory_open")


func close() -> void:
	if not is_open:
		return

	is_open = false
	root.hide()
	GameState.input_locked = false
	Sfx.play("inventory_close")


func _refresh() -> void:
	if not is_open:
		return

	for c in list.get_children():
		c.queue_free()

	_rows = GameState.inventory.duplicate()
	_selected = clampi(_selected, 0, maxi(0, _rows.size() - 1))

	hp.text = "HP  %d / %d" % [GameState.get_player_hp(), GameState.get_player_max_hp()]

	if _rows.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_font_override("font", title.get_theme_font("font"))
		empty.add_theme_font_size_override("font_size", 28)
		list.add_child(empty)
		desc.text = ""
		return

	for i in _rows.size():
		var item: Dictionary = _rows[i]
		var row := Label.new()
		var mark := ">" if i == _selected else " "
		row.text = "%s %-22s x%d" % [mark, item.get("name", "?"), int(item.get("count", 1))]
		if GameState.is_equipped(str(item.get("id", ""))):
			row.text += "   EQUIPPED"
		row.add_theme_font_override("font", title.get_theme_font("font"))
		row.add_theme_font_size_override("font_size", 28)
		row.add_theme_color_override("font_color",
			Color(1, 0.92, 0.72) if i == _selected else Color(0.75, 0.72, 0.66))
		list.add_child(row)

	desc.text = str(_rows[_selected].get("description", ""))


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if event.keycode == KEY_I:
		get_viewport().set_input_as_handled()
		toggle()
		return

	if not is_open:
		return

	get_viewport().set_input_as_handled()

	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_W, KEY_UP:
			_move(-1)
		KEY_S, KEY_DOWN:
			_move(1)
		KEY_E:
			_use()


func _move(step: int) -> void:
	if _rows.is_empty():
		return

	_selected = wrapi(_selected + step, 0, _rows.size())
	_refresh()


func _use() -> void:
	if _rows.is_empty():
		return

	var item: Dictionary = _rows[_selected]

	# Weapons toggle in and out of the weapon slot; the item stays here.
	if item.get("type", "") == "weapon":
		var id := str(item["id"])

		if GameState.is_equipped(id):
			GameState.unequip("weapon")
			hint.text = "Unequipped: %s" % item["name"]
		else:
			GameState.equip(id)
			hint.text = "Equipped: %s" % item["name"]

		_refresh()
		return

	if item.get("use", "") != "heal":
		hint.text = "Nothing happens."
		return

	if GameState.get_player_hp() >= GameState.get_player_max_hp():
		hint.text = "Kiren is already at full health."
		return

	var restored := GameState.heal_player(int(item.get("power", 0)))
	GameState.remove_item(str(item["id"]), 1)
	hint.text = "Restored %d health." % restored
	Sfx.play("item_use")
	_refresh()
