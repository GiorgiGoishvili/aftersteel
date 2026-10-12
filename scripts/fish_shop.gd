extends CanvasLayer

## Toma's Fishing Shop (autoload FishShop). Toma opens it after he talks;
## Esc, the X or CLOSE shuts it.
##
## The screen is the user's TomaFishingShop.png, drawn at the equipment
## screen's scale. Everything interactive sits exactly over its own drawing
## and only text is added on top: the fish grid on the right (the equipment
## screen's 4x5 squares, with the same page arrows under it), the selected
## fish's square, name and details on the left, the gold beside the coin,
## and the four buttons along the bottom - SELL, SELL ALL, EXCHANGE and
## CLOSE. The DIVINE EXCHANGE badge on the left does the same as EXCHANGE.
##
## Selling and prices are FishMarket's. Divine fish go to DivineExchange:
## in the browser build, the strip above the fish connects Phantom (Solana
## Devnet) and shows its address and balance, and EXCHANGE asks the exchange
## server to pay the fish's claim. The fish leaves the pack only once the
## server reports the transfer confirmed; its signature then links to the
## Solana Explorer. The game pauses while the shop is open.

## The drawn part of the 256 px canvas.
const SHOP_CROP := Rect2i(2, 15, 252, 238)
## The fish squares: the same grid as the equipment screen's.
const GRID_COLUMNS := [Vector2i(138, 25), Vector2i(165, 24), Vector2i(191, 25), Vector2i(217, 25)]
const GRID_ROWS := [Vector2i(75, 26), Vector2i(103, 26), Vector2i(131, 26), Vector2i(159, 25), Vector2i(186, 26)]
const CLOSE_X := Rect2i(229, 18, 24, 25)
const ICON_SLOT := Rect2i(18, 75, 27, 28)
## Bare paper beside the icon square, for the name and rarity.
const NAME_AREA := Rect2i(48, 76, 73, 27)
## The light panel, for quantity, price and messages.
const TEXT_PANEL := Rect2i(17, 120, 104, 48)
## Bare paper beside the coin.
const GOLD_AREA := Rect2i(38, 171, 82, 13)
## Bare paper above the icon square, for the wallet.
const WALLET_AREA := Rect2i(14, 57, 108, 15)
## Explorer links are drawn in this ink.
const INK_LINK := Color(0.1, 0.22, 0.5)
const DIVINE_BADGE := Rect2i(18, 187, 26, 26)
const BUTTONS := {
	"Sell": Rect2i(12, 232, 53, 18),
	"SellAll": Rect2i(69, 232, 57, 18),
	"Exchange": Rect2i(127, 229, 64, 24),
	"CloseButton": Rect2i(193, 232, 53, 18),
}
const BUTTON_TEXT := {"Sell": "SELL", "SellAll": "SELL ALL", "Exchange": "EXCHANGE", "CloseButton": "CLOSE"}

## Page arrows: the inventory's, from the UI pack, in the same bare strip
## under the grid.
const UI_PACK := preload("res://Assets/UI/InventoryMenu/Exports/Equipment.png")
const ARROW_LEFT := Rect2i(156, 316, 4, 7)
const ARROW_RIGHT := Rect2i(128, 316, 4, 7)
const PREV_AT := Vector2i(170, 213)
const NEXT_AT := Vector2i(206, 213)
const PAGE_LABEL_AREA := Rect2i(175, 212, 30, 9)

const ART := preload("res://Assets/UI/FishingShop/Exports/TomaFishingShop.png")
const ART_BUTTON := preload("res://scripts/pause_menu_button.gd")
const FONT := preload("res://Assets/UI/Fabled_Font.ttf")

const INK := Color(0.14, 0.08, 0.02)
const INK_SOFT := Color(0.4, 0.28, 0.16)
const INK_LIGHT := Color(0.93, 0.85, 0.7)
const DARK_GLOW := Color(1.5, 1.32, 1.0)
## What an unavailable button fades towards (the buttons sit on the world,
## not on paper).
const UNAVAILABLE_SHADE := Color(0.12, 0.08, 0.06)
const RARITY_INK := {
	"common": Color(0.4, 0.28, 0.16),
	"uncommon": Color(0.13, 0.36, 0.12),
	"rare": Color(0.1, 0.22, 0.5),
	"divine": Color(0.45, 0.12, 0.52),
}

## Screen pixels per art pixel; 4, like the equipment screen (1008x952).
@export_range(1, 8) var shop_scale := 4

var is_open := false
## The fish shown, one entry per stack, in pack order.
var rows: Array = []
## Index into rows of the fish on show, -1 with none.
var selected := -1
var page := 0

var _root: Control
var _panel: TextureRect
var _cells: Array[Button] = []
var _buttons := {}
var _close_x: Button
var _badge: Button
var _icon: TextureRect
var _name: Label
var _rarity: Label
var _quantity: Label
var _price: Label
var _info: Label
var _gold: Label
var _prev: TextureButton
var _next: TextureButton
var _page_label: Label
var _opened_frame := -1
var _wallet_line: Button
var _tx_link: Button
var _tx_url := ""
## An exchange waiting on the server: buttons hold still until it answers.
var _exchanging := false


func _ready() -> void:
	_build()
	_root.hide()


## Not over a conversation, the inventory or the pause menu.
func can_open() -> bool:
	return not is_open and not GameState.input_locked and not Dialogue.is_active() \
		and not InventoryUI.is_open and not PauseMenu.is_open


func open() -> void:
	if not can_open():
		return

	is_open = true
	_opened_frame = Engine.get_process_frames()
	page = 0
	GameState.input_locked = true
	get_tree().paused = true
	_root.show()
	refresh()
	select(0 if not rows.is_empty() else -1)
	_info.text = "" if not rows.is_empty() else "Bring me something from the river."
	Sfx.play("inventory_open")


func close() -> void:
	if not is_open:
		return

	is_open = false
	_show_link("", "")
	var focused := get_viewport().gui_get_focus_owner()

	if focused != null:
		focused.release_focus()

	_root.hide()
	GameState.input_locked = false
	get_tree().paused = false
	Sfx.play("inventory_close")


## Re-reads the pack: the grid, the page, the buttons and the gold.
func refresh() -> void:
	rows = GameState.inventory.filter(func(entry: Dictionary) -> bool:
		return Items.by_id(str(entry.get("id", ""))).get("fish", false))
	page = clampi(page, 0, _page_count() - 1)
	var first := page * _cells.size()

	for i in _cells.size():
		_fill(_cells[i], rows[first + i] if first + i < rows.size() else {})

	_page_label.text = "%d / %d" % [page + 1, _page_count()]
	_prev.disabled = page == 0
	_next.disabled = page >= _page_count() - 1
	_tint_arrow(_prev)
	_tint_arrow(_next)
	_gold.text = str(GameState.gold)

	if selected >= rows.size():
		selected = rows.size() - 1

	_show_selected()


## Shows rows[i] on the left (-1: none).
func select(i: int) -> void:
	selected = clampi(i, -1, rows.size() - 1)
	_info.text = ""
	_show_selected()


## SELL: one of the selected fish.
func sell_selected() -> void:
	var id := _selected_id()

	if id == "":
		_info.text = "Pick a fish to sell."
		return

	if DivineExchange.accepts(id):
		_info.text = "I don't buy those for gold. Try the exchange."
		return

	var paid := FishMarket.sell(id, 1)

	if paid <= 0:
		_info.text = "Nothing to sell."
		return

	var fish_name := str(Items.by_id(id).get("name", ""))
	refresh()
	_info.text = "Sold %s for %d gold." % [fish_name, paid]
	Sfx.play("item_use")


## SELL ALL: every fish Toma buys; Divine ones stay.
func sell_all() -> void:
	var result := FishMarket.sell_all()
	refresh()

	if int(result["fish"]) == 0:
		_info.text = "Nothing I can buy." if not rows.is_empty() else "Nothing to sell."
		return

	_info.text = "Sold %d fish for %d gold." % [result["fish"], result["gold"]]
	Sfx.play("item_use")


## EXCHANGE: asks DivineExchange, which says why it can't yet.
func exchange_selected() -> void:
	var id := _selected_id()

	if id == "":
		_info.text = "Pick a Divine fish to exchange."
		return

	if _exchanging:
		return

	var ready := DivineExchange.check(id)

	if not ready["ok"]:
		_info.text = str(ready["message"])
		return

	var claim := str(ready["claim"])
	_exchanging = true
	_info.text = "Sending %s Devnet SOL..." % _sol(DivineExchange.price_of(id))
	_show_selected()
	Wallet.redeem(claim, func(result: Dictionary) -> void: _on_redeemed(id, claim, result))


func _on_redeemed(id: String, claim: String, result: Dictionary) -> void:
	_exchanging = false
	var sig := str(result.get("signature", ""))

	if result.get("ok", false) and result.get("status", "") == "paid" and sig != "":
		# Paid and confirmed on Devnet: only now does the fish change hands.
		GameState.remove_divine_claim(id, claim)
		GameState.remove_item(id, 1)
		Wallet.refresh_balance()
		refresh()
		_info.text = "Paid %s Devnet SOL." % _sol(float(result.get("amountSol", 0.0)))
		_show_link(str(result.get("explorer", "")), sig)
	elif result.get("ok", false) and result.get("status", "") == "pending":
		refresh()
		_info.text = "Still confirming on Devnet. Press EXCHANGE to check again."
		_show_link(str(result.get("explorer", "")), sig)
	else:
		refresh()
		_info.text = DivineExchange.error_text(result)


## The last transaction's Explorer link, on the panel's bottom line until the
## shop closes ("" hides it). Messages above it get two lines.
func _show_link(url: String, sig: String) -> void:
	_tx_url = url
	_tx_link.text = "Tx %s...%s  (Solana Explorer)" % [sig.left(6), sig.right(6)]
	_tx_link.visible = url != ""
	_info.size.y = (11 if _tx_link.visible else 24) * shop_scale


func _on_wallet_line() -> void:
	if Wallet.connected:
		Wallet.refresh_balance()
	elif Wallet.available and not Wallet.connecting:
		_info.text = "Approve the connection in Phantom..."
		Wallet.connect_wallet(func(r: Dictionary) -> void:
			if r.get("ok", false):
				_info.text = "Wallet connected (Devnet)."
			elif r.get("error", "") == "no_phantom":
				_info.text = DivineExchange.NEEDS_PHANTOM
			elif r.get("error", "") == "cancelled":
				_info.text = "Cancelled in Phantom."
			else:
				# Phantom's own words, so a failure can be told apart.
				_info.text = "Couldn't connect (%s): %s" % [r.get("step", r.get("error", "")), str(r.get("detail", r.get("error", ""))).left(70)])


func _show_wallet() -> void:
	Wallet.refresh_flags()

	if not Wallet.available:
		_wallet_line.text = "Wallet: browser build only"
	elif Wallet.connecting:
		_wallet_line.text = "Waiting for Phantom..."
	elif Wallet.connected:
		_wallet_line.text = "%s (Devnet)" % Wallet.describe()
	elif Wallet.phantom:
		_wallet_line.text = "> Connect Phantom (Devnet)"
	else:
		_wallet_line.text = "Phantom not found"
	_wallet_line.disabled = not Wallet.available


static func _sol(amount: float) -> String:
	return ("%.4f" % amount).rstrip("0").rstrip(".")


func flip(step: int) -> void:
	var to := clampi(page + step, 0, _page_count() - 1)

	if to == page:
		return

	page = to
	refresh()
	select(page * _cells.size())


func _unhandled_input(event: InputEvent) -> void:
	if not is_open or not (event is InputEventKey) or not event.pressed or event.echo:
		return

	get_viewport().set_input_as_handled()

	# The key that closed Toma's last line must not act in here.
	if Engine.get_process_frames() == _opened_frame:
		return

	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_A, KEY_LEFT:
			_step(-1)
		KEY_D, KEY_RIGHT:
			_step(1)
		KEY_W, KEY_UP:
			_step(-GRID_COLUMNS.size())
		KEY_S, KEY_DOWN:
			_step(GRID_COLUMNS.size())


## Keys walk the fish, turning the page when they step off it.
func _step(by: int) -> void:
	if rows.is_empty():
		return

	var to := clampi(maxi(selected, 0) + by, 0, rows.size() - 1)
	var on_page := floori(float(to) / _cells.size())

	if on_page != page:
		page = on_page
		refresh()

	select(to)
	_cells[to % _cells.size()].grab_focus()


func _selected_id() -> String:
	return str(rows[selected].get("id", "")) if selected >= 0 and selected < rows.size() else ""


func _page_count() -> int:
	return maxi(1, ceili(rows.size() / float(_cells.size())))


func _show_selected() -> void:
	var id := _selected_id()
	var item := Items.by_id(id)
	var rarity := str(item.get("rarity", ""))
	var divine := DivineExchange.accepts(id)
	_icon.texture = load(item["icon"]) if item.has("icon") and ResourceLoader.exists(item["icon"]) else null
	_name.text = str(item.get("name", "No fish")) if id != "" or rows.is_empty() else ""
	_rarity.text = rarity.capitalize()
	_rarity.add_theme_color_override("font_color", RARITY_INK.get(rarity, INK_SOFT))

	if id == "":
		_quantity.text = ""
		_price.text = ""
	else:
		_quantity.text = "Quantity  x%d" % GameState.get_item_count(id)
		_price.text = DivineExchange.offer(id) if divine else "Price  %d gold each" % FishMarket.price_of(id)

	if divine and _info.text == "":
		_info.text = DivineExchange.TEST_NOTE

	_set_available("Sell", id != "" and FishMarket.can_sell(id))
	_set_available("SellAll", rows.any(func(e: Dictionary) -> bool: return FishMarket.can_sell(str(e.get("id", "")))))
	_set_available("Exchange", not _exchanging)

	if _exchanging:
		_set_available("Sell", false)
		_set_available("SellAll", false)

	_show_wallet()


func _set_available(which: String, on: bool) -> void:
	var b: Button = _buttons[which]
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	(b.get_node("Text") as Label).modulate.a = 1.0 if on else 0.45
	b.queue_redraw()


## A square showing a fish (or nothing: then it can't be picked).
func _fill(b: Button, entry: Dictionary) -> void:
	var item := Items.by_id(str(entry.get("id", "")))
	var icon: TextureRect = b.get_node("Icon")
	icon.texture = load(item["icon"]) if item.has("icon") and ResourceLoader.exists(item["icon"]) else null
	var count := int(entry.get("count", 1))
	(b.get_node("Count") as Label).text = "x%d" % count if count > 1 else ""
	b.disabled = entry.is_empty()
	b.focus_mode = Control.FOCUS_NONE if entry.is_empty() else Control.FOCUS_ALL
	b.queue_redraw()


# --- Building --------------------------------------------------------------

func _build() -> void:
	var art := ART.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)
	var k := shop_scale

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var tex := AtlasTexture.new()
	tex.atlas = ART
	tex.region = Rect2(SHOP_CROP)
	_panel = TextureRect.new()
	_panel.texture = tex
	_panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_panel.size = Vector2(SHOP_CROP.size) * k
	_panel.position = ((get_viewport().get_visible_rect().size - _panel.size) / 2.0).round()
	_root.add_child(_panel)

	for row in GRID_ROWS:
		for column in GRID_COLUMNS:
			var cell := _art_button(art, Rect2i(column.x, row.x, column.y, row.y), false)
			var i := _cells.size()
			_add_icon(cell, Vector2(64, 64))
			var count := _label("", 16, INK_LIGHT, HORIZONTAL_ALIGNMENT_RIGHT)
			count.name = "Count"
			count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			count.autowrap_mode = TextServer.AUTOWRAP_OFF
			cell.add_child(count)
			count.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			count.offset_right = -10
			count.offset_bottom = -6
			cell.focus_entered.connect(func() -> void: select(page * _cells.size() + i))
			cell.pressed.connect(func() -> void: select(page * _cells.size() + i))
			_cells.append(cell)

	_close_x = _art_button(art, CLOSE_X)
	_close_x.pressed.connect(close)
	_badge = _art_button(art, DIVINE_BADGE)
	_badge.set("selected_tint", DARK_GLOW)
	_badge.pressed.connect(exchange_selected)

	for which in BUTTONS:
		var b := _art_button(art, BUTTONS[which])
		b.name = which
		var text := _label(BUTTON_TEXT[which], 22, INK_LIGHT, HORIZONTAL_ALIGNMENT_CENTER)
		text.name = "Text"
		text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		text.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.add_child(text)
		text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_buttons[which] = b

	(_buttons["Sell"] as Button).pressed.connect(sell_selected)
	(_buttons["SellAll"] as Button).pressed.connect(sell_all)
	(_buttons["Exchange"] as Button).pressed.connect(exchange_selected)
	(_buttons["CloseButton"] as Button).pressed.connect(close)

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.size = Vector2(64, 64)
	_icon.position = (_art_to_panel(ICON_SLOT.position) + (Vector2(ICON_SLOT.size) * k - _icon.size) / 2.0).round()
	_panel.add_child(_icon)

	_name = _place(_label("", 26, INK), Rect2i(NAME_AREA.position, Vector2i(NAME_AREA.size.x, 15)))
	_name.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_rarity = _place(_label("", 20, INK_SOFT), Rect2i(NAME_AREA.position + Vector2i(0, 16), Vector2i(NAME_AREA.size.x, 10)))

	var inner := TEXT_PANEL.grow(-3)
	_quantity = _place(_label("", 20, INK), Rect2i(inner.position, Vector2i(inner.size.x, 9)))
	_price = _place(_label("", 18, INK), Rect2i(inner.position + Vector2i(0, 9), Vector2i(inner.size.x, 9)))
	_price.autowrap_mode = TextServer.AUTOWRAP_OFF
	_price.clip_text = true
	_info = _place(_label("", 18, INK_SOFT), Rect2i(inner.position + Vector2i(0, 18), Vector2i(inner.size.x, 24)))
	_info.clip_text = true
	_gold = _place(_label("", 24, INK), GOLD_AREA)

	_wallet_line = _text_button(WALLET_AREA, 20, INK)
	_wallet_line.pressed.connect(_on_wallet_line)
	Wallet.changed.connect(func() -> void:
		if is_open:
			_show_wallet())
	_tx_link = _text_button(Rect2i(20, 153, 98, 12), 18, INK_LINK)
	_tx_link.pressed.connect(func() -> void: Wallet.open_explorer(_tx_url))
	_tx_link.hide()
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_prev = _arrow(ARROW_LEFT, PREV_AT, -1)
	_next = _arrow(ARROW_RIGHT, NEXT_AT, 1)
	_page_label = _place(_label("", 20, INK, HORIZONTAL_ALIGNMENT_CENTER), PAGE_LABEL_AREA)
	_page_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_page_label.autowrap_mode = TextServer.AUTOWRAP_OFF


## A plain text button on the paper (no art of its own).
func _text_button(area: Rect2i, size: int, colour: Color) -> Button:
	var b := Button.new()
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", FONT)
	b.add_theme_font_size_override("font_size", size)
	for state in ["font_color", "font_focus_color", "font_pressed_color"]:
		b.add_theme_color_override(state, colour)
	b.add_theme_color_override("font_hover_color", Color(0.6, 0.32, 0.04))
	b.add_theme_color_override("font_disabled_color", INK_SOFT)
	for box in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(box, StyleBoxEmpty.new())
	b.position = _art_to_panel(area.position)
	b.size = Vector2(area.size) * shop_scale
	_panel.add_child(b)
	return b


## A button over its own drawing in the art, cut out so only its pixels
## light up and take the mouse.
func _art_button(art: Image, region: Rect2i, fade := true) -> Button:
	var b := Button.new()
	b.set_script(ART_BUTTON)
	b.flat = true
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.set("region", region)
	b.set("fade_unavailable", fade)
	b.set("selected_tint", DARK_GLOW)
	b.position = _art_to_panel(region.position)
	b.size = Vector2(region.size) * shop_scale
	_panel.add_child(b)
	b.cut_from(art, UNAVAILABLE_SHADE, true)
	return b


func _add_icon(b: Button, at_size: Vector2) -> void:
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size = at_size
	icon.position = ((b.size - at_size) / 2.0).round()
	b.add_child(icon)


func _arrow(region: Rect2i, at: Vector2i, step: int) -> TextureButton:
	var tex := AtlasTexture.new()
	tex.atlas = UI_PACK
	tex.region = region
	var b := TextureButton.new()
	b.texture_normal = tex
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.focus_mode = Control.FOCUS_NONE
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.position = _art_to_panel(at)
	b.size = Vector2(region.size) * shop_scale
	b.pressed.connect(flip.bind(step))
	for s in [b.mouse_entered, b.mouse_exited, b.button_down, b.button_up]:
		s.connect(_tint_arrow.bind(b))
	_panel.add_child(b)
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


func _label(text: String, size := 24, colour := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", FONT)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	return l


## Puts a label over an area of the art.
func _place(l: Label, area: Rect2i) -> Label:
	l.position = _art_to_panel(area.position)
	l.size = Vector2(area.size) * shop_scale
	_panel.add_child(l)
	return l


func _art_to_panel(art_point: Vector2i) -> Vector2:
	return Vector2(art_point - SHOP_CROP.position) * shop_scale
