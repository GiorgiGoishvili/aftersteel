extends CanvasLayer

## Fishing (autoload). With the fishing rod in the weapon slot, J or left
## click at the river's edge casts: Kiren throws the line (his cast
## animation) and stays on its last frame. After a short wait a fish bites
## and the minigame opens: hold J or the mouse button to lift the green
## zone, let go and it sinks. Keep the fish inside it to fill the meter -
## full, it's caught; empty, it gets away. Esc reels in at any point.
##
## The line has to land in water: the cast's last frame drops the line and
## its ripple a fixed way from Kiren, so he can only cast where every pixel
## of that ripple is over a Water tile - right at the bank.
##
## What's on the line is rolled before the minigame opens, and its rarity
## sets how hard the fish fights (DIFFICULTY).
##
## The art (AftersteelFishingminigame.png) has the zone, the fish and a
## part-filled meter drawn in. They are cut out at start-up: the zone and
## the fish become the moving pieces, and the track and meter behind them
## are filled back in from their own plain rows, so nothing shows twice.
##
## The game pauses during the minigame; this layer keeps running.

signal finished(result: String)    # "caught:<item id>", "escaped" or "cancelled"

## What a catch can be, and how often: each row's chance is its weight over
## the total (60 + 28 + 10 + 2 = 100 here, so they read as percentages). A
## "rarity" row is a fish of that rarity - every fish of it (Items.fish_of)
## equally likely. An {"item": id} row is a single catch. Demo balancing.
const CATCHES := [
	{"rarity": "common", "weight": 60},
	{"rarity": "uncommon", "weight": 28},
	{"rarity": "rare", "weight": 10},
	{"rarity": "divine", "weight": 2},
]

## How hard each rarity is to land (anything without a rarity fishes as
## Common). Speeds are art pixels a second. Simulated players (suite 22):
## Common is landed by everyone in about 2 s; Uncommon takes a beginner
## three times as long; Rare a beginner lands about 60%; Divine a beginner
## rarely, a practised player about two times in three.
##   fish_speed   the fish's usual top speed
##   fish_accel   how quickly it speeds up, slows and turns
##   turn_every   seconds between new places to swim to (min, max)
##   dash         chance a move is a dash (DASH times the speed)
##   zone         height of the green zone in art pixels (the art's is 23)
##   gain, loss   meter per second with the fish inside / outside the zone
const DIFFICULTY := {
	"common":    {"fish_speed": 12.0, "fish_accel": 24.0, "turn_every": Vector2(1.8, 3.2), "dash": 0.0, "zone": 32, "gain": 0.42, "loss": 0.09},
	"uncommon":  {"fish_speed": 35.0, "fish_accel": 110.0, "turn_every": Vector2(0.7, 1.5), "dash": 0.20, "zone": 23, "gain": 0.29, "loss": 0.19},
	"rare":      {"fish_speed": 44.0, "fish_accel": 160.0, "turn_every": Vector2(0.5, 1.15), "dash": 0.23, "zone": 20, "gain": 0.26, "loss": 0.22},
	"epic":      {"fish_speed": 46.0, "fish_accel": 172.0, "turn_every": Vector2(0.48, 1.05), "dash": 0.25, "zone": 19, "gain": 0.255, "loss": 0.22},
	"legendary": {"fish_speed": 48.0, "fish_accel": 184.0, "turn_every": Vector2(0.45, 0.98), "dash": 0.27, "zone": 18, "gain": 0.25, "loss": 0.225},
	"divine":    {"fish_speed": 50.0, "fish_accel": 196.0, "turn_every": Vector2(0.42, 0.9), "dash": 0.29, "zone": 17, "gain": 0.245, "loss": 0.23},
}

## How much faster a dash is than the fish's usual top speed.
const DASH := 1.7

## Where the line lands in the cast's last frame (KirenFishing.png, frame 8),
## measured from Kiren's centre facing right: its ripple covers x 8-30,
## y 21-27. Mirrored when he faces left.
const RIPPLE := Rect2i(8, 21, 23, 7)
## Looking this far below and beside Kiren for water, to tell him to step
## closer rather than that there's none.
const NEAR_WATER := 72.0
## Screen pixels between Kiren and the minigame on the side his line goes
## (the cast's last frame reaches about 230 px out).
const LINE_GAP := 260.0

const ART := preload("res://Assets/UI/FishingMinigame/Exports/AftersteelFishingminigame.png")

# Where things are in the 128 px art.
const DRAWN := Rect2i(32, 9, 68, 110)        # the art's drawn part
const ZONE_ART := Rect2i(50, 57, 25, 23)     # the zone as drawn, fish and all
const ZONE_CAP := 3                          # its top and bottom rows that shape it
const FISH_ART := Rect2i(55, 62, 15, 14)
const PLAIN_TRACK_ROW := 50                  # a row of bare track
const PLAIN_ZONE_ROW := 60                   # a row of zone the fish misses
const TRACK_TOP := 31                        # where the zone can go: rows 31-106
const TRACK_BOTTOM := 107
const FISH_MIN := 38.0                       # the fish's centre, highest...
const FISH_MAX := 99.0                       # ...and lowest
const METER_X := 87                          # meter inside: 5 px wide,
const METER_TOP := 41                        # rows 41-93, the end rows 3 px
const METER_BOTTOM := 93
const PLAIN_METER_ROW := 50
const FILL_TOP_AS_DRAWN := 63
## Rows of the drawn fill to colour each band of the live one (bottom band
## red, then orange, then yellow on top - the same split as the art).
const FILL_ROWS := [85, 75, 66]

enum State { IDLE, WAITING, PLAYING }

## Seconds before a bite, picked at random in this range.
@export var bite_delay := Vector2(1.2, 3.0)
## Screen pixels per art pixel.
@export_range(1, 8) var art_scale := 6

var state := State.IDLE
## The minigame in progress (or null).
var challenge: Challenge
## What's on the line, rolled when the fish bites.
var catch_id := ""

var _bite_timer := 0.0
var _note_timer := 0.0
var _last_hp := 0
var _fill_colours: Array = []
var _zone_art: Image
var _zone_textures := {}
var _rng := RandomNumberGenerator.new()

var _root: Control
var _panel: TextureRect
var _zone: TextureRect
var _fish: TextureRect
var _meter: Control
var _note: Label


## One go at the minigame: the zone, the fish and the meter, moved one step
## at a time. Separate from the screen so it can be tried out in tests.
class Challenge:
	# The zone. Held, it accelerates up; let go, gravity takes it; drag bleeds
	# off momentum so short taps and feathering settle instead of overshooting.
	# It climbs more slowly than it falls, so a held button stays controllable.
	const LIFT := 150.0
	const GRAVITY := 160.0
	const DRAG := 1.6
	const MAX_UP_SPEED := 62.0
	const MAX_DOWN_SPEED := 90.0
	const BOUNCE := 0.3          # share of its speed it keeps off the bottom
	const BOUNCE_MIN := 22.0     # any slower and it just settles there
	const START := 0.35

	var settings: Dictionary
	var progress := START
	var zone_h := 23
	var zone_y := 0.0            # the zone's top, art pixels
	var zone_speed := 0.0        # down is positive
	var fish_y := 0.0            # the fish's centre, art pixels
	var fish_speed := 0.0
	var fish_target := 0.0
	var fish_top_speed := 0.0
	var fish_timer := 0.0
	var inside := false
	var _rng: RandomNumberGenerator

	func _init(rarity: String, rng: RandomNumberGenerator) -> void:
		settings = DIFFICULTY.get(rarity, DIFFICULTY["common"])
		_rng = rng
		zone_h = int(settings["zone"])
		zone_y = zone_max()
		fish_y = (FISH_MIN + FISH_MAX) / 2.0
		fish_target = fish_y

	func zone_max() -> float:
		return float(TRACK_BOTTOM - zone_h)

	## Advances by `delta` seconds with the button held or not. Returns
	## "caught" or "escaped" when it ends, otherwise "".
	func step(delta: float, held: bool) -> String:
		_move_fish(delta)
		_move_zone(delta, held)
		inside = fish_y >= zone_y + 1.0 and fish_y <= zone_y + zone_h - 1.0
		var rate: float = settings["gain"] if inside else -float(settings["loss"])
		progress = clampf(progress + rate * delta, 0.0, 1.0)

		if progress >= 1.0:
			return "caught"
		if progress <= 0.0:
			return "escaped"
		return ""

	## The fish keeps picking somewhere new to swim to, easing up to speed
	## and slowing as it arrives; now and then a move is a dash.
	func _move_fish(delta: float) -> void:
		fish_timer -= delta

		if fish_timer <= 0.0:
			var turn: Vector2 = settings["turn_every"]
			fish_timer = _rng.randf_range(turn.x, turn.y)
			fish_target = _rng.randf_range(FISH_MIN, FISH_MAX)
			var dash := _rng.randf() < float(settings["dash"])
			fish_top_speed = float(settings["fish_speed"]) * (DASH if dash else _rng.randf_range(0.6, 1.0))

		var wanted := clampf((fish_target - fish_y) * 2.5, -fish_top_speed, fish_top_speed)
		var accel := float(settings["fish_accel"]) * (2.0 if fish_top_speed > float(settings["fish_speed"]) else 1.0)
		fish_speed = move_toward(fish_speed, wanted, accel * delta)
		fish_y += fish_speed * delta

		if fish_y < FISH_MIN or fish_y > FISH_MAX:
			fish_y = clampf(fish_y, FISH_MIN, FISH_MAX)
			fish_speed = 0.0

	func _move_zone(delta: float, held: bool) -> void:
		zone_speed += (-LIFT if held else GRAVITY) * delta
		zone_speed -= zone_speed * DRAG * delta
		zone_speed = clampf(zone_speed, -MAX_UP_SPEED, MAX_DOWN_SPEED)
		zone_y += zone_speed * delta

		if zone_y < TRACK_TOP:
			zone_y = TRACK_TOP
			zone_speed = maxf(zone_speed, 0.0)
		elif zone_y > zone_max():
			zone_y = zone_max()
			zone_speed = -zone_speed * BOUNCE if zone_speed > BOUNCE_MIN else 0.0


func _ready() -> void:
	_rng.randomize()
	_build()
	_last_hp = GameState.get_player_hp()
	GameState.player_health_changed.connect(_on_health_changed)


## Ordinary play only: a gameplay map with its HUD up and nothing else -
## a conversation, a menu, a cutscene - holding the input.
func can_fish() -> bool:
	return ObjectiveHUD.visible and not GameState.input_locked and not get_tree().paused \
		and not Dialogue.is_active() and _player() != null


## True when the line would land in water from where Kiren stands now.
func line_lands_in_water() -> bool:
	var player := _player()

	if player == null:
		return false

	for corner in [RIPPLE.position, RIPPLE.end - Vector2i.ONE, Vector2i(RIPPLE.position.x, RIPPLE.end.y - 1),
			Vector2i(RIPPLE.end.x - 1, RIPPLE.position.y), RIPPLE.get_center()]:
		if not _is_water(player.global_position + _facing(Vector2(corner))):
			return false

	return true


## Casts, if the line would land in the water.
func cast() -> void:
	if state != State.IDLE:
		return

	if not line_lands_in_water():
		_say("Get closer to the water." if _water_nearby() else "No water to fish here.", 1.4)
		return

	state = State.WAITING
	GameState.input_locked = true
	# The bite can't come before the line is in the water.
	var throw: float = _player().start_fishing()
	_bite_timer = throw + _rng.randf_range(bite_delay.x, bite_delay.y)
	_say("Waiting for a bite...", INF)


func cancel() -> void:
	if state == State.IDLE:
		return

	_end()
	_say("Reeled in.", 1.0)
	finished.emit("cancelled")


## The catch for a roll in [0, 1) by the CATCHES weights; a second roll
## picks the fish when the row is a rarity pool.
static func pick_catch(roll: float, fish_roll := 0.0) -> String:
	var total := 0

	for c in CATCHES:
		total += int(c["weight"])

	var left := roll * total
	var row: Dictionary = CATCHES[-1]

	for c in CATCHES:
		left -= int(c["weight"])
		if left < 0.0:
			row = c
			break

	if row.has("item"):
		return row["item"]

	var pool := Items.fish_of(row["rarity"])
	return pool[mini(int(fish_roll * pool.size()), pool.size() - 1)]


## How hard a catch fights: its item's rarity, or Common for anything without.
static func rarity_of(id: String) -> String:
	var rarity := str(Items.by_id(id).get("rarity", "common"))
	return rarity if DIFFICULTY.has(rarity) else "common"


func _unhandled_input(event: InputEvent) -> void:
	if state == State.IDLE:
		if event.is_action_pressed("attack") and GameState.has_rod_equipped() and can_fish():
			get_viewport().set_input_as_handled()
			cast()
		return

	# While fishing, nothing else: no second cast, no menus, no swings.
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		cancel()
	elif event is InputEventKey or event is InputEventMouseButton:
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _note_timer > 0.0:
		_note_timer -= delta
		if _note_timer <= 0.0:
			_note.hide()

	match state:
		State.WAITING:
			_bite_timer -= delta
			if _bite_timer <= 0.0:
				_start_minigame()
		State.PLAYING:
			_play(delta)


func _start_minigame() -> void:
	state = State.PLAYING
	catch_id = pick_catch(_rng.randf(), _rng.randf())
	challenge = Challenge.new(rarity_of(catch_id), _rng)
	_zone.texture = _zone_texture(challenge.zone_h)
	_note.hide()
	_layout()
	_place()
	_root.show()
	get_tree().paused = true


func _play(delta: float) -> void:
	var result := challenge.step(delta, Input.is_action_pressed("attack"))
	_zone.modulate = Color.WHITE if challenge.inside else Color(0.78, 0.78, 0.78)
	_place()

	if result != "":
		_finish(result == "caught")


func _finish(caught: bool) -> void:
	if not caught:
		_end()
		_say("It got away.", 1.6)
		finished.emit("escaped")
		return

	var id := catch_id
	var item := Items.by_id(id)
	GameState.add_item(item)
	_end()
	_say("Caught: %s" % Items.label_of(item), 2.0)
	finished.emit("caught:" + id)


func _end() -> void:
	if state == State.PLAYING:
		get_tree().paused = false

	state = State.IDLE
	_root.hide()
	GameState.input_locked = false

	var player := _player()

	if player != null:
		player.stop_fishing()


func _on_health_changed(current: int, _maximum: int) -> void:
	# A hit while waiting for a bite spoils it.
	if state == State.WAITING and current < _last_hp:
		cancel()

	_last_hp = current


func _player() -> Node2D:
	var scene := get_tree().current_scene
	return null if scene == null else scene.find_child("Player", true, false) as Node2D


## A point measured facing right, turned the way Kiren faces.
func _facing(point: Vector2) -> Vector2:
	var player := _player()
	return Vector2(-point.x, point.y) if player != null and player.side == "L" else point


func _water_layers() -> Array:
	var scene := get_tree().current_scene
	return [] if scene == null else scene.find_children("Water*", "TileMapLayer", true, false)


func _is_water(world: Vector2) -> bool:
	for found in _water_layers():
		var water := found as TileMapLayer
		if water.get_cell_source_id(water.local_to_map(water.to_local(world))) != -1:
			return true

	return false


func _water_nearby() -> bool:
	var player := _player()

	if player == null:
		return false

	for dx in [-NEAR_WATER / 2.0, 0.0, NEAR_WATER / 2.0]:
		for dy in range(8, int(NEAR_WATER) + 1, 8):
			if _is_water(player.global_position + Vector2(dx, dy)):
				return true

	return false


## A line above Kiren's head. `secs` INF keeps it up until replaced.
func _say(text: String, secs: float) -> void:
	_note.text = text
	_note.visible = text != ""
	_note_timer = secs if secs != INF else 0.0

	var player := _player()
	var at := player.get_global_transform_with_canvas().origin if player != null else Vector2(960, 540)
	_note.position = (at + Vector2(-_note.size.x / 2.0, -190.0)).round()


# --- The minigame's pieces -------------------------------------------------

func _build() -> void:
	var art := ART.get_image()
	art.decompress()
	art.convert(Image.FORMAT_RGBA8)

	# Behind the zone: bare track, copied down from a plain row.
	var back := art.duplicate()

	for y in range(ZONE_ART.position.y, ZONE_ART.end.y):
		for x in range(ZONE_ART.position.x, ZONE_ART.end.x):
			back.set_pixel(x, y, art.get_pixel(x, PLAIN_TRACK_ROW))

	# Behind the drawn fill: the empty meter (its bottom end from its top).
	for y in range(FILL_TOP_AS_DRAWN, METER_BOTTOM + 1):
		for x in range(METER_X, METER_X + 5):
			if y == METER_BOTTOM and (x == METER_X or x == METER_X + 4):
				continue
			back.set_pixel(x, y, art.get_pixel(x, METER_TOP if y == METER_BOTTOM else PLAIN_METER_ROW))

	# The zone without the fish, and the fish without the zone.
	var zone := art.get_region(ZONE_ART)
	var fish := Image.create(FISH_ART.size.x, FISH_ART.size.y, false, Image.FORMAT_RGBA8)

	for y in FISH_ART.size.y:
		for x in FISH_ART.size.x:
			var at := FISH_ART.position + Vector2i(x, y)
			var plain := art.get_pixel(at.x, PLAIN_ZONE_ROW)
			var c := art.get_pixelv(at)
			if c != plain:
				fish.set_pixel(x, y, c)
				zone.set_pixelv(at - ZONE_ART.position, plain)

	# The zone's corner pixels are track showing through.
	var w := ZONE_ART.size.x - 1
	var h := ZONE_ART.size.y - 1

	for corner in [Vector2i(0, 0), Vector2i(w, 0), Vector2i(0, h), Vector2i(w, h)]:
		zone.set_pixelv(corner, Color(0, 0, 0, 0))

	_zone_art = zone

	for row in FILL_ROWS:
		var colours := []
		for x in range(METER_X, METER_X + 5):
			colours.append(art.get_pixel(x, row))
		_fill_colours.append(colours)

	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.hide()
	add_child(_root)

	_panel = _texture_rect(ImageTexture.create_from_image(back))
	_root.add_child(_panel)
	_zone = _texture_rect(_zone_texture(ZONE_ART.size.y))
	_panel.add_child(_zone)
	_fish = _texture_rect(ImageTexture.create_from_image(fish))
	_panel.add_child(_fish)

	_meter = Control.new()
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.draw.connect(_draw_meter)
	_panel.add_child(_meter)

	_note = Label.new()
	_note.size = Vector2(700, 60)
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.add_theme_font_override("font", load("res://Assets/UI/Fabled_Font.ttf"))
	_note.add_theme_font_size_override("font_size", 30)
	_note.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	_note.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.04))
	_note.add_theme_constant_override("outline_size", 8)
	_note.hide()
	add_child(_note)


## The zone at any height: the art's own top and bottom rows, its plain
## middle row repeated between them - taller or shorter, never stretched.
func _zone_texture(h: int) -> Texture2D:
	if not _zone_textures.has(h):
		var img := Image.create(ZONE_ART.size.x, h, false, Image.FORMAT_RGBA8)
		var src_h := _zone_art.get_height()

		for y in h:
			var from := y if y < ZONE_CAP else (src_h - (h - y) if y >= h - ZONE_CAP else ZONE_CAP)
			img.blit_rect(_zone_art, Rect2i(0, from, ZONE_ART.size.x, 1), Vector2i(0, y))

		_zone_textures[h] = ImageTexture.create_from_image(img)

	return _zone_textures[h]


func _texture_rect(texture: Texture2D) -> TextureRect:
	var r := TextureRect.new()
	r.texture = texture
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Beside Kiren - to his right, or his left near the screen's edge - at a
## whole scale, clear of his line on the side it was cast to.
func _layout() -> void:
	var k := art_scale
	var view := get_viewport().get_visible_rect().size
	var player := _player()
	var at := player.get_global_transform_with_canvas().origin if player != null else view / 2.0
	var line_right: bool = player == null or player.side == "R"
	var left := at.x + (LINE_GAP if line_right else 120.0) - DRAWN.position.x * k

	if left + DRAWN.end.x * k > view.x - 16.0:
		left = at.x - (120.0 if line_right else LINE_GAP) - DRAWN.end.x * k

	var top := clampf(at.y - (DRAWN.position.y + DRAWN.size.y / 2.0) * k, 16.0 - DRAWN.position.y * k, view.y - 16.0 - DRAWN.end.y * k)
	_panel.position = Vector2(left, top).round()
	_panel.size = Vector2(128, 128) * k
	_zone.size = Vector2(ZONE_ART.size.x, challenge.zone_h if challenge != null else ZONE_ART.size.y) * k
	_fish.size = Vector2(FISH_ART.size) * k
	_meter.position = Vector2(METER_X, METER_TOP) * k
	_meter.size = Vector2(5, METER_BOTTOM - METER_TOP + 1) * k


## The moving pieces at their places. They move by whole screen pixels (a
## sixth of an art pixel), so slow drifts glide instead of stepping.
func _place() -> void:
	var k := art_scale
	_zone.position = Vector2(ZONE_ART.position.x * k, roundf(challenge.zone_y * k))
	_fish.position = Vector2(FISH_ART.position.x * k, roundf((challenge.fish_y - FISH_ART.size.y / 2.0) * k))
	_meter.queue_redraw()


## The live fill, from the bottom up: red, then orange, then yellow on top,
## in the art's own colours.
func _draw_meter() -> void:
	if challenge == null:
		return

	var k := art_scale
	var rows := METER_BOTTOM - METER_TOP + 1
	var filled := roundi(challenge.progress * rows)

	for i in filled:
		var y := METER_BOTTOM - i
		var share := float(i) / float(filled)
		var colours: Array = _fill_colours[0 if share < 0.4 else (1 if share < 0.7 else 2)]
		var end_row := y == METER_TOP or y == METER_BOTTOM

		for x in range(1 if end_row else 0, 4 if end_row else 5):
			_meter.draw_rect(Rect2(Vector2(x, y - METER_TOP) * k, Vector2(k, k)), colours[x])
