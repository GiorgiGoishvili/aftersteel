extends Button

## One button of the pause menu (and the inventory menu). It draws nothing
## of its own: the button is part of the menu art underneath, and this
## Control sits exactly over it. When it is selected, pressed or unavailable
## it redraws just its own pixels on top, tinted, so the rest of the menu
## never changes.

## Multiplied into the button's pixels: a warm gold lift when selected and
## a darkening while pressed.
const SELECTED := Color(1.1, 1.04, 0.86)
const PRESSED := Color(0.8, 0.75, 0.7)
## How far an unavailable button fades into the paper.
const FADE := 0.6
## Anything darker than this is a button's outline.
const OUTLINE := 0.235
## How long the darkening shows for a key press (a held click shows it for
## as long as the button is held).
const FLASH_TIME := 0.1

## Where the button is drawn in the menu art, in art pixels.
@export var region := Rect2i()
## Off for buttons that are only sometimes in use (an empty slot): then
## an unavailable button just shows the art as drawn.
@export var fade_unavailable := true
## The selected tint; dark buttons need a stronger lift to read as warm.
@export var selected_tint := SELECTED

var _art: Texture2D      # this button's pixels, the paper around it clear
var _shape: Texture2D    # the same outline in plain white
var _hit: Image          # the outline, for mouse hits
var _paper := Color.WHITE
var _flashing := false


func _ready() -> void:
	# Hovering selects, so the mouse and the keys never pick two buttons.
	mouse_entered.connect(func() -> void:
		if not disabled:
			grab_focus())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


## Cuts this button out of the menu art. `paper` is the colour behind the
## button: everything that colour reachable from the button's edge is not
## button. With `stop_at_outline`, everything short of the button's dark
## outline is not button instead (for buttons on textured wood).
func cut_from(art: Image, paper: Color, stop_at_outline := false) -> void:
	var img := art.get_region(region)
	var w := img.get_width()
	var h := img.get_height()
	var outside := {}
	var todo: Array[Vector2i] = []

	for x in w:
		todo.append(Vector2i(x, 0))
		todo.append(Vector2i(x, h - 1))
	for y in h:
		todo.append(Vector2i(0, y))
		todo.append(Vector2i(w - 1, y))

	while not todo.is_empty():
		var p: Vector2i = todo.pop_back()
		if p.x < 0 or p.y < 0 or p.x >= w or p.y >= h or outside.has(p):
			continue
		var c := img.get_pixelv(p)
		if (c.a > 0.0 and maxf(c.r, maxf(c.g, c.b)) < OUTLINE) if stop_at_outline else c != paper:
			continue
		outside[p] = true
		todo.append_array([p + Vector2i.LEFT, p + Vector2i.RIGHT, p + Vector2i.UP, p + Vector2i.DOWN])

	_hit = Image.create(w, h, false, Image.FORMAT_RGBA8)

	for y in h:
		for x in w:
			if outside.has(Vector2i(x, y)):
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			else:
				_hit.set_pixel(x, y, Color.WHITE)

	_art = ImageTexture.create_from_image(img)
	_shape = ImageTexture.create_from_image(_hit)
	_paper = paper
	queue_redraw()


## "selected", "pressed", "unavailable" or "" - what the button shows now.
func look() -> String:
	if disabled:
		return "unavailable"
	if _flashing or get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED:
		return "pressed"
	if has_focus():
		return "selected"
	return ""


## Shows the press briefly, for presses that have no held state of their own.
func flash() -> void:
	_flashing = true
	queue_redraw()
	await get_tree().create_timer(FLASH_TIME).timeout
	_flashing = false
	queue_redraw()


func _draw() -> void:
	if _art == null:
		return

	var box := Rect2(Vector2.ZERO, size)

	match look():
		"unavailable":
			if fade_unavailable:
				draw_texture_rect(_shape, box, false, Color(_paper, FADE))
		"pressed":
			draw_texture_rect(_art, box, false, PRESSED)
		"selected":
			draw_texture_rect(_art, box, false, selected_tint)


## Only the button's own pixels take the mouse, not the paper around its
## carved ends.
func _has_point(point: Vector2) -> bool:
	if _hit == null:
		return Rect2(Vector2.ZERO, size).has_point(point)

	var p := Vector2i((point / size * Vector2(_hit.get_size())).floor())
	return Rect2i(Vector2i.ZERO, _hit.get_size()).has_point(p) and _hit.get_pixelv(p).a > 0.0
