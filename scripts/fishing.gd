extends CanvasLayer

## Fishing (autoload). With the fishing rod in the weapon slot, J or left
## click at a fishing spot casts: Kiren throws the line (his cast animation)
## and stays on its last frame. After a short wait a fish bites and the
## minigame opens: hold J or the mouse button to lift the green zone, let go
## and it sinks. Keep the fish inside it to fill the meter - full, it's
## caught; empty, it gets away. Esc reels in at any point, catching nothing.
##
## The art (AftersteelFishingminigame.png) has the zone, the fish and a
## part-filled meter drawn in. They are cut out at start-up: the zone and
## the fish become the moving pieces, and the track and meter behind them
## are filled back in from their own plain rows, so nothing shows twice.
##
## The game pauses during the minigame; this layer keeps running.

signal finished(result: String)    # "caught:<item id>", "escaped" or "cancelled"

## What a catch can be, and how often: each one's chance is its weight over
## the total (65 + 30 + 5 = 100 here: 65% fish, 30% junk, 5% the ring).
const CATCHES := [
	{"item": "river_fish", "weight": 65},
	{"item": "driftwood", "weight": 30},
	{"item": "old_ring", "weight": 5},
]

## Fishing works this close to a node named FishingSpot (map pixels).
const SPOT_RANGE := 48.0
## Screen pixels between Kiren and the minigame on the side his line goes
## (the cast's last frame reaches about 230 px out).
const LINE_GAP := 260.0

const ART := preload("res://Assets/UI/FishingMinigame/Exports/AftersteelFishingminigame.png")

# Where things are in the 128 px art.
const DRAWN := Rect2i(32, 9, 68, 110)        # the art's drawn part
const ZONE_ART := Rect2i(50, 57, 25, 23)     # the zone as drawn, fish and all
const FISH_ART := Rect2i(55, 62, 15, 14)
const PLAIN_TRACK_ROW := 50                  # a row of bare track
const PLAIN_ZONE_ROW := 60                   # a row of zone the fish misses
const ZONE_MIN := 31                         # the zone's top, highest...
const ZONE_MAX := 84                         # ...and lowest (track ends at 106)
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

# How it feels. Art pixels and seconds.
const GRAVITY := 380.0
const LIFT := 760.0
const MAX_SPEED := 170.0
const BOUNCE := 0.35          # share of its speed the zone keeps off the bottom
const GAIN := 0.30            # meter per second with the fish in the zone
const LOSS := 0.20            # meter per second without
const START := 0.35

enum State { IDLE, WAITING, PLAYING }

## Seconds before a bite, picked at random in this range.
@export var bite_delay := Vector2(1.2, 3.0)
## Screen pixels per art pixel.
@export_range(1, 8) var art_scale := 6

var state := State.IDLE
var progress := 0.0
var zone_y := 0.0          # the zone's top row, art pixels
var zone_speed := 0.0      # down is positive
var fish_y := 0.0          # the fish's centre, art pixels

var _fish_target := 0.0
var _fish_speed := 0.0
var _fish_timer := 0.0
var _bite_timer := 0.0
var _note_timer := 0.0
var _last_hp := 0
var _fill_colours: Array = []
var _rng := RandomNumberGenerator.new()

var _root: Control
var _panel: TextureRect
var _zone: TextureRect
var _fish: TextureRect
var _meter: Control
var _note: Label


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


## Casts at the nearest fishing spot, if Kiren is at one.
func cast() -> void:
	if state != State.IDLE:
		return

	if _spot_near() == null:
		_say("No water to fish here.", 1.4)
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


## The catch for a roll in [0, 1), by the CATCHES weights.
static func pick_catch(roll: float) -> String:
	var total := 0

	for c in CATCHES:
		total += int(c["weight"])

	var left := roll * total

	for c in CATCHES:
		left -= int(c["weight"])
		if left < 0.0:
			return c["item"]

	return CATCHES[-1]["item"]


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
	progress = START
	zone_y = ZONE_MAX
	zone_speed = 0.0
	fish_y = (FISH_MIN + FISH_MAX) / 2.0
	_fish_timer = 0.0
	_note.hide()
	_layout()
	_place()
	_root.show()
	get_tree().paused = true


func _play(delta: float) -> void:
	_move_fish(delta)
	_move_zone(delta)

	var inside := fish_y >= zone_y + 2.0 and fish_y <= zone_y + ZONE_ART.size.y - 2.0
	progress = clampf(progress + (GAIN if inside else -LOSS) * delta, 0.0, 1.0)
	_zone.modulate = Color.WHITE if inside else Color(0.78, 0.78, 0.78)
	_place()

	if progress >= 1.0:
		_finish(true)
	elif progress <= 0.0:
		_finish(false)


## The fish keeps picking somewhere new to swim to, mostly at an easy pace,
## now and then in a dash.
func _move_fish(delta: float) -> void:
	_fish_timer -= delta

	if _fish_timer <= 0.0:
		_fish_timer = _rng.randf_range(0.5, 1.6)
		_fish_target = _rng.randf_range(FISH_MIN, FISH_MAX)
		_fish_speed = _rng.randf_range(20.0, 60.0) if _rng.randf() > 0.25 else _rng.randf_range(80.0, 110.0)

	fish_y = move_toward(fish_y, _fish_target, _fish_speed * delta)


## Held, the zone climbs; let go, it falls, and it bounces a little off
## the bottom. Short taps hold it in place.
func _move_zone(delta: float) -> void:
	var held := Input.is_action_pressed("attack")
	zone_speed = clampf(zone_speed + (GRAVITY - (LIFT if held else 0.0)) * delta, -MAX_SPEED, MAX_SPEED)
	zone_y += zone_speed * delta

	if zone_y < ZONE_MIN:
		zone_y = ZONE_MIN
		zone_speed = maxf(zone_speed, 0.0)
	elif zone_y > ZONE_MAX:
		zone_y = ZONE_MAX
		zone_speed = -zone_speed * BOUNCE if zone_speed > 30.0 else 0.0


func _finish(caught: bool) -> void:
	if not caught:
		_end()
		_say("It got away.", 1.6)
		finished.emit("escaped")
		return

	var id := pick_catch(_rng.randf())
	var item := Items.by_id(id)
	GameState.add_item(item)
	_end()
	_say("Caught: %s" % item["name"], 2.0)
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


func _spot_near() -> Node2D:
	var player := _player()

	if player == null:
		return null

	for spot in get_tree().current_scene.find_children("FishingSpot*", "Node2D", true, false):
		if (spot as Node2D).global_position.distance_to(player.global_position) <= SPOT_RANGE:
			return spot

	return null


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
	_zone = _texture_rect(ImageTexture.create_from_image(zone))
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
	_zone.size = Vector2(ZONE_ART.size) * k
	_fish.size = Vector2(FISH_ART.size) * k
	_meter.position = Vector2(METER_X, METER_TOP) * k
	_meter.size = Vector2(5, METER_BOTTOM - METER_TOP + 1) * k


## The moving pieces at their places, snapped to whole art pixels.
func _place() -> void:
	var k := art_scale
	_zone.position = Vector2(ZONE_ART.position.x, roundf(zone_y)) * k
	_fish.position = Vector2(FISH_ART.position.x, roundf(fish_y) - FISH_ART.size.y / 2.0) * k
	_meter.queue_redraw()


## The live fill, from the bottom up: red, then orange, then yellow on top,
## in the art's own colours.
func _draw_meter() -> void:
	var k := art_scale
	var rows := METER_BOTTOM - METER_TOP + 1
	var filled := roundi(progress * rows)

	for i in filled:
		var y := METER_BOTTOM - i
		var share := float(i) / float(filled)
		var colours: Array = _fill_colours[0 if share < 0.4 else (1 if share < 0.7 else 2)]
		var end_row := y == METER_TOP or y == METER_BOTTOM

		for x in range(1 if end_row else 0, 4 if end_row else 5):
			_meter.draw_rect(Rect2(Vector2(x, y - METER_TOP) * k, Vector2(k, k)), colours[x])
