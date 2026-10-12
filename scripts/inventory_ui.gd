extends CanvasLayer

## Kiren's pack and the rest of the in-game menu. Opens with I, closes with
## I, Esc or the X.
##
## The menu art (AftersteelInsideGameMenu.png) has four section buttons on
## the wood and INDEX on the paper. EQUIPMENT opens its own screen
## (AftersteelEquipmentMenu.png); the others, and the monster index, cover
## the paper with a page and a Back link. Esc steps back one screen at a
## time, then closes.
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

const TITLES := {"craft": "Craft", "character": "Character", "quests": "Quests", "index": "Monster Index"}

## The equipment screen's drawn part and its inventory grid, in art pixels.
const EQUIP_CROP := Rect2i(2, 15, 252, 215)
const GRID_COLUMNS := [Vector2i(138, 25), Vector2i(165, 24), Vector2i(191, 25), Vector2i(217, 25)]
const GRID_ROWS := [Vector2i(75, 26), Vector2i(103, 26), Vector2i(131, 26), Vector2i(159, 25), Vector2i(186, 26)]
## The empty space under BOOTS and ACCESSORY, for item names and messages.
const NOTE_AREA := Rect2i(14, 196, 110, 22)
## The screen's slots as the game's equipment slots (the art has no head
## or legs slot). WEAPON also takes the fishing rod.
const SHOWN_SLOTS := {"weapon": "Weapon", "body": "Armor", "feet": "Boots", "accessory": "Accessory"}

## Kiren's preview is the gameplay Player's own sprite (same SpriteFrames,
## set in the scene), idling the way he does in the world: front idle
## unarmed, right-facing sword idle armed. Twice the menu's pixel size -
## three times would not fit between the slots - which is also exactly his
## size on screen in the game (camera zoom 8).
const KIREN_AT := Vector2i(36, 93)
const KIREN_SCALE := 2
const KIREN_UNARMED := "FIdle"
const KIREN_ARMED := "RSIdle"
## With the rod: the same rod idle as in the world. Its frames are 64 px,
## centred on the same Kiren as the 32 px ones.
const KIREN_ROD := "RFishIdle"

const ART_BUTTON := preload("res://scripts/pause_menu_button.gd")

## Pages of the grid: the arrows are the little green ones from the UI pack
## (Equipment.png), sat in the bare strip under the grid with the page
## number between them.
const UI_PACK := preload("res://Assets/UI/InventoryMenu/Exports/Equipment.png")
const ARROW_LEFT := Rect2i(156, 316, 4, 7)
const ARROW_RIGHT := Rect2i(128, 316, 4, 7)
const PREV_AT := Vector2i(170, 213)
const NEXT_AT := Vector2i(206, 213)
const PAGE_LABEL_AREA := Rect2i(175, 212, 30, 9)
## Kinds of item that show one square each rather than stacking.
const GEAR := ["weapon", "armor", "tool", "accessory"]

## The monsters Kiren can actually meet.
const MONSTERS := [
	{"kind": "red_slime", "name": "Red Slime", "scene": "res://scenes/enemies/red_slime.tscn",
		"frames": "res://Assets/Enemies/Slimes/Red/RedSlimeSpriteFrames.tres"},
]

const FIREWOOD_STEP: String = preload("res://scenes/kiren_eira_house_interior.gd").OBJECTIVE_FIREWOOD
const FIREPLACE_STEP: String = preload("res://scenes/village.gd").OBJECTIVE_FIREPLACE

const INK := Color(0.14, 0.08, 0.02)
const INK_SOFT := Color(0.4, 0.28, 0.16)
## Text inside the dark grid squares.
const INK_LIGHT := Color(0.93, 0.85, 0.7)
## The selected tint for the equipment screen's dark slots and squares.
const DARK_GLOW := Color(1.5, 1.32, 1.0)

## Screen pixels per art pixel. Whole numbers keep the pixel art crisp:
## 5 draws the menu 1045x800 on the 1920x1080 view.
@export_range(1, 8) var menu_scale := 5:
	set(value):
		menu_scale = value
		if is_node_ready():
			_layout()

## The same for the equipment screen: 4 draws it 1008x860.
@export_range(1, 8) var equip_scale := 4:
	set(value):
		equip_scale = value
		if is_node_ready():
			_layout()

@onready var root: Control = $Root
@onready var panel: TextureRect = $Root/Panel
@onready var title: Label = $Root/Panel/Title
@onready var page: ColorRect = $Root/Panel/Page
@onready var back_button: Button = $Root/Panel/Page/Back
@onready var scroll: ScrollContainer = $Root/Panel/Page/Scroll
@onready var body: VBoxContainer = $Root/Panel/Page/Scroll/Body
@onready var page_hint: Label = $Root/Panel/Page/Hint
@onready var index_button: Button = $Root/Panel/Index
@onready var close_button: Button = $Root/Panel/Close
@onready var equip: TextureRect = $Root/Equip
@onready var equip_close: Button = $Root/Equip/Close
@onready var grid: Control = $Root/Equip/Grid
@onready var kiren: AnimatedSprite2D = $Root/Equip/Kiren
@onready var note: Label = $Root/Equip/Note

var is_open := false
## "" (the menu as drawn, INDEX showing) or the open screen: "equipment",
## "craft", "character", "quests" or "index".
var view := ""
## Where messages go: the page's line, or the equipment screen's.
var hint: Label

var _selected := 0
## What the equipment grid shows: the pack minus whatever is worn.
var _rows: Array = []
var _cells: Array[Button] = []
## Which page of the grid is showing (0 = first).
var _page := 0
var _prev: TextureButton
var _next: TextureButton
var _page_label: Label
var _font: Font
var _monster_stats := {}


func _ready() -> void:
	_font = title.get_theme_font("font")
	hint = page_hint

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
	_build_equipment_screen()
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
	_release_focus()
	root.hide()
	GameState.input_locked = false
	get_tree().paused = false
	Sfx.play("inventory_close")


## "" shows the menu as drawn, INDEX and all; "equipment" swaps in the
## equipment screen; anything else covers the paper with that page.
func show_view(which: String) -> void:
	view = which
	var equipping := which == "equipment"
	panel.visible = not equipping
	equip.visible = equipping
	page.visible = which != "" and not equipping
	index_button.visible = which == ""
	title.text = TITLES.get(which, "")
	hint = note if equipping else page_hint
	hint.text = ""

	if equipping:
		_page = 0

	_release_focus()
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
		KEY_I:
			close()
		KEY_ESCAPE:
			# One step back: out of a screen first, then out of the menu.
			if view == "":
				close()
			else:
				show_view("")
		KEY_W, KEY_UP:
			_move(-1)
		KEY_S, KEY_DOWN:
			_move(1)
		KEY_E:
			_use()


func _refresh() -> void:
	if not is_open or view == "":
		return

	if view == "equipment":
		_equipment_screen()
		return

	for c in body.get_children():
		body.remove_child(c)
		c.queue_free()

	match view:
		"craft":
			body.add_child(_label("Nothing to craft yet."))
		"character":
			_character_page()
		"quests":
			_quests_page()
		"index":
			_index_page()


# --- Equipment ---------------------------------------------------------

## Buttons over the screen's slots, its X and every grid square, each cut
## to its own drawing like the menu's.
func _build_equipment_screen() -> void:
	var art := (equip.texture as AtlasTexture).atlas.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)

	for slot in SHOWN_SLOTS:
		var b: Button = equip.get_node(SHOWN_SLOTS[slot])
		b.cut_from(art, Color.TRANSPARENT, true)
		b.set("selected_tint", DARK_GLOW)
		_add_item_parts(b)
		b.pressed.connect(_take_off.bind(slot))

	equip_close.cut_from(art, Color.TRANSPARENT, true)
	equip_close.pressed.connect(show_view.bind(""))

	for row in GRID_ROWS:
		for column in GRID_COLUMNS:
			var cell := Button.new()
			cell.set_script(ART_BUTTON)
			cell.flat = true
			cell.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
			cell.set("region", Rect2i(column.x, row.x, column.y, row.y))
			cell.set("fade_unavailable", false)
			cell.set("selected_tint", DARK_GLOW)
			grid.add_child(cell)
			cell.cut_from(art, Color.TRANSPARENT, true)
			_add_item_parts(cell)

			var i := _cells.size()
			cell.mouse_entered.connect(_show_name.bind(i))
			cell.pressed.connect(func() -> void:
				_selected = _page * _cells.size() + i
				_use())
			_cells.append(cell)

	_prev = _arrow(ARROW_LEFT, -1)
	_next = _arrow(ARROW_RIGHT, 1)
	_page_label = _label("", 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_page_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	equip.add_child(_page_label)


## A page arrow: lighter under the mouse, darker while pressed, faint when
## there is no page that way.
func _arrow(region: Rect2i, step: int) -> TextureButton:
	var tex := AtlasTexture.new()
	tex.atlas = UI_PACK
	tex.region = region
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_flip.bind(step))
	for s in [b.mouse_entered, b.mouse_exited, b.button_down, b.button_up]:
		s.connect(_tint_arrow.bind(b))
	equip.add_child(b)
	return b


func _tint_arrow(b: TextureButton) -> void:
	if b.disabled:
		b.modulate = Color(1, 1, 1, 0.3)
	elif b.is_pressed():
		b.modulate = Color(0.75, 0.75, 0.75)
	elif b.is_hovered():
		b.modulate = Color(1.3, 1.25, 1.1)
	else:
		b.modulate = Color.WHITE


func _page_count() -> int:
	return maxi(1, ceili(_rows.size() / float(_cells.size())))


func _flip(step: int) -> void:
	var to := clampi(_page + step, 0, _page_count() - 1)

	if to == _page:
		return

	_page = to
	_selected = _page * _cells.size()
	_equipment_screen()


## An icon, a name for items with no icon, and a count, laid over a slot
## or square.
func _add_item_parts(b: Button) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(icon)

	var tag := _label("", 16, INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
	tag.name = "Tag"
	tag.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(tag)
	tag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var count := _label("", 16, INK_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
	count.name = "Count"
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	count.autowrap_mode = TextServer.AUTOWRAP_OFF
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(count)
	count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	count.offset_right = -10
	count.offset_bottom = -6


func _equipment_screen() -> void:
	for slot in SHOWN_SLOTS:
		_fill(equip.get_node(SHOWN_SLOTS[slot]), Items.by_id(str(GameState.equipment.get(slot, ""))))

	# A worn item stays in GameState's inventory; here it shows in its slot
	# instead of the grid, so nothing is ever in two places. Gear shows one
	# square per piece; everything else stacks into one square with a count.
	_rows = []

	for entry in GameState.inventory:
		var count := int(entry.get("count", 1)) - (1 if GameState.is_equipped(str(entry.get("id", ""))) else 0)
		var gear := GEAR.has(str(entry.get("type", "")))

		for n in (count if gear else mini(count, 1)):
			var shown: Dictionary = entry.duplicate()
			shown["count"] = 1 if gear else count
			_rows.append(shown)

	# 20 squares a page; never past the last page, even after items go.
	_page = clampi(_page, 0, _page_count() - 1)
	_selected = clampi(_selected, 0, maxi(0, _rows.size() - 1))
	var first := _page * _cells.size()

	for i in _cells.size():
		var item: Dictionary = _rows[first + i] if first + i < _rows.size() else {}
		_fill(_cells[i], item, int(item.get("count", 1)))

	_page_label.text = "%d / %d" % [_page + 1, _page_count()]
	_prev.disabled = _page == 0
	_next.disabled = _page >= _page_count() - 1
	_tint_arrow(_prev)
	_tint_arrow(_next)

	var idle := KIREN_ARMED if GameState.has_weapon_equipped() else (KIREN_ROD if GameState.has_rod_equipped() else KIREN_UNARMED)
	kiren.offset = Vector2(-16, -16) if idle == KIREN_ROD else Vector2.ZERO

	if kiren.animation != idle or not kiren.is_playing():
		kiren.play(idle)


## Shows `item` (or nothing) in a slot or square. Empty ones can't be
## picked, so they never light up.
func _fill(b: Button, item: Dictionary, count := 1) -> void:
	var icon: TextureRect = b.get_node("Icon")
	var has_icon := item.has("icon") and ResourceLoader.exists(item["icon"])
	icon.texture = load(item["icon"]) if has_icon else null
	icon.size = Vector2(64, 64)
	icon.position = ((b.size - icon.size) / 2.0).round()

	var item_name := str(item.get("name", ""))
	(b.get_node("Tag") as Label).text = "" if has_icon else item_name.get_slice(" ", item_name.get_slice_count(" ") - 1)
	(b.get_node("Count") as Label).text = "x%d" % count if count > 1 else ""
	b.disabled = item.is_empty()


func _take_off(slot: String) -> void:
	var item := Items.by_id(str(GameState.equipment.get(slot, "")))

	if item.is_empty():
		return

	GameState.unequip(slot)
	hint.text = "Unequipped: %s" % item["name"]


func _show_name(i: int) -> void:
	var at := _page * _cells.size() + i

	if at < _rows.size():
		_selected = at
		hint.text = Items.label_of(_rows[at])


## W and S step through the grid's items, the same as hovering them.
func _move(step: int) -> void:
	if view != "equipment" or _rows.is_empty():
		return

	_selected = wrapi(_selected + step, 0, _rows.size())

	# Stepping off a page turns to the page the item is on.
	var on_page := floori(float(_selected) / _cells.size())

	if on_page != _page:
		_page = on_page
		_equipment_screen()

	_cells[_selected % _cells.size()].grab_focus()
	hint.text = Items.label_of(_rows[_selected])


func _use() -> void:
	if view != "equipment" or _rows.is_empty():
		return

	var item: Dictionary = _rows[_selected]
	var id := str(item["id"])
	var kind := str(item.get("type", ""))

	# Into its slot, when the screen has one for it. GameState keeps the
	# item in the pack underneath; the slot's button takes it off again.
	var slot := "weapon" if kind == "weapon" else str(item.get("slot", ""))

	if slot != "" and SHOWN_SLOTS.has(slot):
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
	_pair("Gold", str(GameState.gold))


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


## The game's errands, read from the story flags that run them.
func _quests() -> Array:
	var out := []

	if GameState.has_flag("eira_firewood_quest_started"):
		var done := GameState.has_flag("eira_firewood_quest_completed")
		var step := FIREPLACE_STEP if GameState.has_item("firewood_bundle") else FIREWOOD_STEP
		out.append({"from": "Eira", "text": FIREWOOD_STEP if done else step, "done": done})

	if GameState.has_flag("village_intro_started"):
		var next := GameState.next_villager()
		var text := "Talk to the villagers"
		if next != "":
			text += " (visit %s)" % GameState.VILLAGERS[next]
		out.append({"from": "Eira", "text": text, "done": next == ""})

	if GameState.has_flag("slime_quest_started"):
		var done := GameState.has_flag("slime_quest_completed")
		var back := GameState.slimes_defeated >= GameState.SLIME_QUEST_GOAL and not done
		out.append({"from": "Blue Slime", "text": "Return to Blue Slime" if back else GameState.slime_quest_objective(), "done": done})

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


func _release_focus() -> void:
	var focused := get_viewport().gui_get_focus_owner()

	if focused != null:
		focused.release_focus()


func _art_buttons() -> Array:
	return [panel.get_node("Equipment"), panel.get_node("Craft"), panel.get_node("Character"),
		panel.get_node("Quests"), index_button]


func _equipment_buttons() -> Array:
	var buttons: Array = [equip_close]

	for slot in SHOWN_SLOTS:
		buttons.append(equip.get_node(SHOWN_SLOTS[slot]))

	return buttons + _cells


## Both screens centred at their scale, each button over its own drawing,
## the title in the green bar, pages on the paper and Kiren between the
## slots.
func _layout() -> void:
	var view_size := get_viewport().get_visible_rect().size
	var k := menu_scale
	panel.size = Vector2(ART_CROP.size) * k
	panel.position = ((view_size - panel.size) / 2.0).round()

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
	page_hint.position = Vector2(24, page.size.y - 80)
	page_hint.size = Vector2(page.size.x - 48, 72)

	var e := equip_scale
	equip.size = Vector2(EQUIP_CROP.size) * e
	equip.position = ((view_size - equip.size) / 2.0).round()

	for b in _equipment_buttons():
		b.position = Vector2(b.region.position - EQUIP_CROP.position) * e
		b.size = Vector2(b.region.size) * e

	kiren.position = Vector2(KIREN_AT - EQUIP_CROP.position) * e
	kiren.scale = Vector2.ONE * KIREN_SCALE * e
	note.position = Vector2(NOTE_AREA.position - EQUIP_CROP.position) * e
	note.size = Vector2(NOTE_AREA.size) * e
	_prev.position = Vector2(PREV_AT - EQUIP_CROP.position) * e
	_prev.size = Vector2(ARROW_LEFT.size) * e
	_next.position = Vector2(NEXT_AT - EQUIP_CROP.position) * e
	_next.size = Vector2(ARROW_RIGHT.size) * e
	_page_label.position = Vector2(PAGE_LABEL_AREA.position - EQUIP_CROP.position) * e
	_page_label.size = Vector2(PAGE_LABEL_AREA.size) * e

	_refresh()
