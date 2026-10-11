extends CanvasLayer

## Kiren's pack and the rest of the in-game menu. Opens with I, closes with
## I, Esc or the X.
##
## The menu art (AftersteelInsideGameMenu.png) has four section buttons on
## the wood and INDEX on the paper. A section, or the monster index, covers
## the paper with its own page and a Back link; Back returns to INDEX.
##
## The game pauses while it is open. Dialogue outranks it - the screen
## refuses to open while someone is talking - and it never opens over the
## pause menu, so the two can never fight over Esc.
##
## Pages only show what the game really has: there is no crafting yet, no
## defence stat and no drop tables, so those say so instead.

## The drawn part of the 256 px canvas.
const ART_CROP := Rect2i(24, 44, 209, 160)
## The paper on the right, in art pixels: pages draw over it.
const PAGE := Rect2i(119, 66, 103, 132)
## The empty green bar above the paper, for the page's title.
const HEADER := Rect2i(114, 46, 100, 17)
## Equipment.png: the plain square from its equipment grid.
const SLOT_CELL := Rect2i(97, 321, 14, 14)
const EQUIPMENT_SHEET := preload("res://Assets/UI/InventoryMenu/Exports/Equipment.png")

const SLOTS := [["weapon", "Weapon"], ["head", "Head"], ["body", "Body"], ["legs", "Legs"], ["feet", "Feet"]]
const TITLES := {"equipment": "Equipment", "craft": "Craft", "character": "Character", "quests": "Quests", "index": "Monster Index"}

## The monsters Kiren can actually meet.
const MONSTERS := [
	{"kind": "red_slime", "name": "Red Slime", "scene": "res://scenes/enemies/red_slime.tscn",
		"frames": "res://Assets/Enemies/Slimes/Red/RedSlimeSpriteFrames.tres"},
]

const FIREWOOD_STEP: String = preload("res://scenes/kiren_eira_house_interior.gd").OBJECTIVE_FIREWOOD
const FIREPLACE_STEP: String = preload("res://scenes/village.gd").OBJECTIVE_FIREPLACE

const INK := Color(0.14, 0.08, 0.02)
const INK_SOFT := Color(0.4, 0.28, 0.16)
const INK_HOVER := Color(0.6, 0.32, 0.04)

## Screen pixels per art pixel. Whole numbers keep the pixel art crisp:
## 5 draws the menu 1045x800 on the 1920x1080 view.
@export_range(1, 8) var menu_scale := 5:
	set(value):
		menu_scale = value
		if is_node_ready():
			_layout()

@onready var root: Control = $Root
@onready var panel: TextureRect = $Root/Panel
@onready var title: Label = $Root/Panel/Title
@onready var page: ColorRect = $Root/Panel/Page
@onready var back_button: Button = $Root/Panel/Page/Back
@onready var scroll: ScrollContainer = $Root/Panel/Page/Scroll
@onready var body: VBoxContainer = $Root/Panel/Page/Scroll/Body
@onready var hint: Label = $Root/Panel/Page/Hint
@onready var index_button: Button = $Root/Panel/Index
@onready var close_button: Button = $Root/Panel/Close

var is_open := false
## "" (the menu as drawn, INDEX showing) or the open page: "equipment",
## "craft", "character", "quests" or "index".
var view := ""
## The pack's rows, while the equipment page is up.
var list: VBoxContainer

var _selected := 0
var _rows: Array = []
var _font: Font
var _monster_stats := {}
# Stands in for a missing icon so every name lines up.
var _no_icon := ImageTexture.create_from_image(Image.create(32, 32, false, Image.FORMAT_RGBA8))


func _ready() -> void:
	_font = title.get_theme_font("font")

	var art := (panel.texture as AtlasTexture).atlas.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)

	for b in _art_buttons():
		b.cut_from(art, Color.TRANSPARENT, true)

	# The X sits on a plain square of its own.
	close_button.cut_from(art, art.get_pixelv(HEADER.position + Vector2i(8, 8)))

	for which in ["equipment", "craft", "character", "quests"]:
		(panel.get_node(which.capitalize()) as Button).pressed.connect(show_view.bind(which))

	index_button.pressed.connect(show_view.bind("index"))
	back_button.pressed.connect(show_view.bind(""))
	close_button.pressed.connect(close)
	GameState.inventory_changed.connect(_refresh, CONNECT_DEFERRED)
	GameState.equipment_changed.connect(_refresh, CONNECT_DEFERRED)

	_layout()
	root.hide()


## Ordinary play only, the same as the pause menu: a gameplay map with its
## HUD up and nothing else holding the input.
func can_open() -> bool:
	return ObjectiveHUD.visible and not GameState.input_locked \
		and not Dialogue.is_active() and not PauseMenu.is_open


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	if is_open or not can_open():
		return

	is_open = true
	_selected = 0
	root.show()
	show_view("")
	GameState.input_locked = true
	get_tree().paused = true
	Sfx.play("inventory_open")


func close() -> void:
	if not is_open:
		return

	is_open = false

	var focused := get_viewport().gui_get_focus_owner()

	if focused != null:
		focused.release_focus()

	root.hide()
	GameState.input_locked = false
	get_tree().paused = false
	Sfx.play("inventory_close")


## "" shows the menu as drawn, INDEX and all; anything else covers the
## paper with that page.
func show_view(which: String) -> void:
	view = which
	page.visible = which != ""
	index_button.visible = which == ""
	title.text = TITLES.get(which, "")
	hint.text = ""
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return

	if not is_open:
		if event.keycode == KEY_I and can_open():
			get_viewport().set_input_as_handled()
			open()
		return

	get_viewport().set_input_as_handled()

	match event.keycode:
		KEY_I, KEY_ESCAPE:
			close()
		KEY_W, KEY_UP:
			_move(-1)
		KEY_S, KEY_DOWN:
			_move(1)
		KEY_E:
			_use()


func _refresh() -> void:
	if not is_open or view == "":
		return

	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()

	list = null

	match view:
		"equipment":
			_equipment_page()
		"craft":
			body.add_child(_label("Nothing to craft yet."))
		"character":
			_character_page()
		"quests":
			_quests_page()
		"index":
			_index_page()


# --- Equipment ---------------------------------------------------------

func _equipment_page() -> void:
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 14)

	for s in SLOTS:
		slots.add_child(_slot(s[0], s[1]))

	body.add_child(slots)
	body.add_child(_label("Pack", 26, INK_SOFT))

	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 0)
	body.add_child(list)

	_rows = GameState.inventory.duplicate()
	_selected = clampi(_selected, 0, maxi(0, _rows.size() - 1))

	if _rows.is_empty():
		list.add_child(_label("Nothing yet."))
		return

	for i in _rows.size():
		list.add_child(_row(i))


## One equipment slot: Equipment.png's square, the worn item's icon, and
## a click takes it off.
func _slot(slot: String, label: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var cell := Button.new()
	cell.flat = true
	cell.focus_mode = Control.FOCUS_NONE
	cell.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	cell.custom_minimum_size = Vector2(SLOT_CELL.size) * menu_scale

	var tile := AtlasTexture.new()
	tile.atlas = EQUIPMENT_SHEET
	tile.region = SLOT_CELL
	cell.add_child(_picture(tile, cell.custom_minimum_size))

	var item := Items.by_id(str(GameState.equipment.get(slot, "")))

	if item.has("icon") and ResourceLoader.exists(item["icon"]):
		var icon := _picture(load(item["icon"]), Vector2(64, 64))
		icon.position = (cell.custom_minimum_size - icon.size) / 2.0
		cell.add_child(icon)
		cell.mouse_entered.connect(func() -> void: hint.text = str(item["name"]))
		cell.pressed.connect(func() -> void:
			GameState.unequip(slot)
			hint.text = "Unequipped: %s" % item["name"])

	var name_label := _label(label, 18, INK_SOFT, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	box.add_child(cell)
	box.add_child(name_label)
	return box


func _row(i: int) -> Button:
	var item: Dictionary = _rows[i]
	var row := Button.new()
	row.flat = true
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	var count := int(item.get("count", 1))
	row.text = str(item.get("name", "?")) + ("  x%d" % count if count > 1 else "")
	row.icon = load(item["icon"]) if item.has("icon") and ResourceLoader.exists(item["icon"]) else _no_icon

	# Worn items say so at the row's right end.
	if GameState.is_equipped(str(item.get("id", ""))):
		var tag := _label("EQUIPPED", 18, INK_SOFT, HORIZONTAL_ALIGNMENT_RIGHT)
		tag.name = "Tag"
		tag.autowrap_mode = TextServer.AUTOWRAP_OFF
		tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		row.add_child(tag)
		tag.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)

	row.add_theme_font_override("font", _font)
	row.add_theme_font_size_override("font_size", 22)
	row.add_theme_color_override("font_hover_color", INK_HOVER)
	row.add_theme_color_override("font_pressed_color", INK_SOFT)
	row.add_theme_color_override("font_hover_pressed_color", INK_SOFT)
	row.mouse_entered.connect(_pick.bind(i))
	row.pressed.connect(func() -> void:
		_selected = i
		_use())
	_paint(row, i == _selected)
	return row


func _paint(row: Button, chosen: bool) -> void:
	row.add_theme_color_override("font_color", INK_HOVER if chosen else INK)
	row.add_theme_color_override("font_focus_color", INK_HOVER if chosen else INK)


func _pick(i: int) -> void:
	_selected = i
	hint.text = str(_rows[i].get("description", ""))

	if list != null:
		for j in list.get_child_count():
			if list.get_child(j) is Button:
				_paint(list.get_child(j), j == i)


func _move(step: int) -> void:
	if view != "equipment" or _rows.is_empty():
		return

	_pick(wrapi(_selected + step, 0, _rows.size()))


func _use() -> void:
	if view != "equipment" or _rows.is_empty():
		return

	var item: Dictionary = _rows[_selected]
	var id := str(item["id"])
	var kind := str(item.get("type", ""))

	# Weapons and armour go in and out of their slot; the item stays here.
	if kind == "weapon" or kind == "armor":
		if GameState.is_equipped(id):
			GameState.unequip("weapon" if kind == "weapon" else str(item.get("slot", "")))
			hint.text = "Unequipped: %s" % item["name"]
		else:
			GameState.equip(id)
			hint.text = "Equipped: %s" % item["name"]
		return

	if item.get("use", "") != "heal":
		hint.text = "Nothing happens."
		return

	if GameState.get_player_hp() >= GameState.get_player_max_hp():
		hint.text = "Kiren is already at full health."
		return

	var restored := GameState.heal_player(int(item.get("power", 0)))
	GameState.remove_item(id, 1)
	hint.text = "Restored %d health." % restored
	Sfx.play("item_use")


# --- Character, quests ---------------------------------------------------

func _character_page() -> void:
	var weapon := Items.by_id(str(GameState.equipment.get("weapon", "")))
	var down := 0

	for kind in GameState.enemies_defeated:
		down += int(GameState.enemies_defeated[kind])

	_pair("Health", "%d / %d" % [GameState.get_player_hp(), GameState.get_player_max_hp()])
	_pair("Attack", str(GameState.player_stats.get("attack_damage", 0)))
	_pair("Weapon", str(weapon.get("name", "None")))
	_pair("Defeated", str(down))


func _quests_page() -> void:
	body.add_child(_label("Now", 26, INK_SOFT))
	body.add_child(_label(GameState.objective if GameState.objective != "" else "Nothing in particular."))

	for done in [false, true]:
		body.add_child(_label("Done" if done else "Active", 26, INK_SOFT))
		var none := true

		for q in _quests():
			if q["done"] == done:
				body.add_child(_label("%s: %s" % [q["from"], q["text"]]))
				none = false

		if none:
			body.add_child(_label("None."))


## The game's two errands, read from the story flags that run them.
func _quests() -> Array:
	var out := []

	if GameState.has_flag("eira_firewood_quest_started"):
		var done := GameState.has_flag("eira_firewood_quest_completed")
		var step := FIREPLACE_STEP if GameState.has_item("firewood_bundle") else FIREWOOD_STEP
		out.append({"from": "Eira", "text": FIREWOOD_STEP if done else step, "done": done})

	if GameState.has_flag("welf_slime_quest_started"):
		var done := GameState.has_flag("welf_slime_quest_completed")
		var back := GameState.slimes_defeated >= GameState.SLIME_QUEST_GOAL and not done
		out.append({"from": "Welf", "text": "Return to Welf" if back else GameState.slime_quest_objective(), "done": done})

	return out


# --- Monster index -------------------------------------------------------

## A monster shows as a shadow until Kiren has put one down. Nothing in the
## game drops loot yet, so there are no drops or chances to list.
func _index_page() -> void:
	for m in MONSTERS:
		var met := int(GameState.enemies_defeated.get(m["kind"], 0))
		var entry := HBoxContainer.new()
		entry.add_theme_constant_override("separation", 20)

		var frames: SpriteFrames = load(m["frames"])
		var pic := _picture(frames.get_frame_texture("FIdle", 0), Vector2(128, 128))

		if met == 0:
			pic.modulate = Color(0, 0, 0, 0.5)

		entry.add_child(pic)

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(info)

		if met == 0:
			info.add_child(_label("???", 28))
			info.add_child(_label("Not met yet.", 22, INK_SOFT))
		else:
			var stats := _stats_of(m)
			info.add_child(_label(m["name"], 28))
			info.add_child(_label("Health  %d" % stats["health"], 22, INK_SOFT))
			info.add_child(_label("Hits for  %d" % stats["damage"], 22, INK_SOFT))
			info.add_child(_label("Defeated  %d" % met, 22, INK_SOFT))
			info.add_child(_label("Drops  None", 22, INK_SOFT))

		body.add_child(entry)


## Health and damage as the monster's own scene sets them.
func _stats_of(m: Dictionary) -> Dictionary:
	if not _monster_stats.has(m["kind"]):
		var one: Node = (load(m["scene"]) as PackedScene).instantiate()
		_monster_stats[m["kind"]] = {"health": int(one.get("max_health")), "damage": int(one.get("damage"))}
		one.free()

	return _monster_stats[m["kind"]]


# --- Building blocks -----------------------------------------------------

func _label(text: String, size := 24, colour := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


func _pair(name_text: String, value: String) -> void:
	var row := HBoxContainer.new()
	var left := _label(name_text, 24, INK_SOFT)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	row.add_child(_label(value))
	body.add_child(row)


func _picture(texture: Texture2D, at_size: Vector2) -> TextureRect:
	var pic := TextureRect.new()
	pic.texture = texture
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.custom_minimum_size = at_size
	pic.size = at_size
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pic


func _art_buttons() -> Array:
	return [panel.get_node("Equipment"), panel.get_node("Craft"), panel.get_node("Character"),
		panel.get_node("Quests"), index_button]


## The art centred at its scale, each button over its own drawing, the
## title in the green bar and pages on the paper.
func _layout() -> void:
	var k := menu_scale
	panel.size = Vector2(ART_CROP.size) * k
	panel.position = ((get_viewport().get_visible_rect().size - panel.size) / 2.0).round()

	for b in _art_buttons() + [close_button]:
		b.position = Vector2(b.region.position - ART_CROP.position) * k
		b.size = Vector2(b.region.size) * k

	title.position = Vector2(HEADER.position - ART_CROP.position) * k
	title.size = Vector2(HEADER.size) * k
	page.position = Vector2(PAGE.position - ART_CROP.position) * k
	page.size = Vector2(PAGE.size) * k

	back_button.position = Vector2(14, 8)
	scroll.position = Vector2(24, 60)
	scroll.size = Vector2(page.size.x - 40, page.size.y - 60 - 84)
	hint.position = Vector2(24, page.size.y - 80)
	hint.size = Vector2(page.size.x - 48, 72)

	_refresh()
