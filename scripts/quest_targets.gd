class_name QuestTargets
extends RefCounted

## Where each objective is, for the quest marker. GameState.objective_target
## holds one of the keys below; set_objective() callers choose it, so nothing
## is read from the objective text.
##
## A target lives in one map. From any other map the marker stands at the
## exit toward it (routed through the maps in between), pointing the way
## through.

## key: [map root name, node path in that map]. An empty path makes the whole
## map the place (a quest area): inside that map there is nothing to mark.
const TARGETS := {
	"bedroom_chest": ["KirenEiraBedroom", "Chest"],
	"eira": ["KirenEiraHouseInterior", "EiraSprite"],
	"woodpile": ["Village", "Props/Woodpile"],
	"fireplace": ["KirenEiraHouseInterior", "Fireplace"],
	"welf": ["Village", "NPCs/Welf"],
	"slime_clearing": ["WesternOutskirts", ""],
}

## map: {neighbouring map: [exit trigger node, the way Kiren walks through it]}
## (the directions the route tests walk each exit in).
const EXITS := {
	"KirenEiraBedroom": {
		"KirenEiraHouseInterior": ["GoToLivingRoom", "up"],
	},
	"KirenEiraHouseInterior": {
		"KirenEiraBedroom": ["GoToBedroom", "up"],
		"Village": ["ExitToVillage", "down"],
	},
	"Village": {
		"KirenEiraHouseInterior": ["KirenEiraHouse/EnterHouse", "up"],
		"WesternOutskirts": ["Triggers2/ToWesternOutskirts", "left"],
	},
	"WesternOutskirts": {
		"Village": ["Triggers/ToVillage", "right"],
		"WesternRiver": ["Triggers/ToWesternRiver", "down"],
	},
	"WesternRiver": {
		"WesternOutskirts": ["Triggers/ToWesternOutskirts", "up"],
	},
}

const DIRECTIONS := {
	"up": Vector2.UP,
	"down": Vector2.DOWN,
	"left": Vector2.LEFT,
	"right": Vector2.RIGHT,
}

## Where the fingertip is, from the marker's centre, at the full reach of its
## bob (measured on Fingerpointingdirectionsanimation.png).
const TIP := {
	"up": Vector2(-1.5, -16.0),
	"down": Vector2(-1.5, 16.0),
	"left": Vector2(-16.0, 3.5),
	"right": Vector2(16.0, 3.5),
}

## Space left between the fingertip at full reach and what it points at.
const CLEARANCE := 3.0
## Above a character's head the gap is wider, so the hand reads as a sign over
## them rather than touching them.
const HEAD_CLEARANCE := 6.0

## Optional child of a target: a Marker2D with this name places the hand
## exactly (its position is the hand's centre). Metadata "point" says which
## way the finger points; "hide_in_reach" hides it while Kiren can use the
## target, so it never sits on him or the prompt.
const SPOT_NAME := "QuestMarkerSpot"


## The node the marker is about in this map: the target, or the exit toward
## it. null when the key is unknown, there is no way there, or this map is
## the target area.
static func node_for(map: Node, target: String) -> Node2D:
	var hop := _hop(map, target)

	if hop.is_empty():
		return null

	return map.get_node_or_null(hop[0]) as Node2D


## Centre of what is being marked (null when nothing is).
static func locate(map: Node, target: String) -> Variant:
	var node := node_for(map, target)

	if node == null:
		return null

	return _bounds(node).get_center()


## Where the hand goes and which way it points: {"position", "point"}, or
## {} when there is nothing to mark here.
static func marker(map: Node, target: String) -> Dictionary:
	var hop := _hop(map, target)

	if hop.is_empty():
		return {}

	var node := map.get_node_or_null(hop[0]) as Node2D

	if node == null:
		return {}

	var travel: String = hop[1]

	# An exit: on the side Kiren comes from, pointing the way through.
	if travel != "":
		var gate := _bounds(node)
		var way: Vector2 = DIRECTIONS[travel]
		var near_edge := gate.get_center() - way * absf(way.dot(gate.size)) / 2.0
		return _placed(near_edge - way * CLEARANCE, travel)

	var spot := node.get_node_or_null(SPOT_NAME) as Node2D

	if spot != null:
		return { "position": spot.global_position, "point": str(spot.get_meta("point", "down")),
			"hide_in_reach": bool(spot.get_meta("hide_in_reach", false)), "reach": _interactable(node) }

	var box := _bounds(node)

	# A character or object: over its head, finger down.
	if not _sprites(node).is_empty():
		return _placed(Vector2(box.get_center().x, box.position.y - HEAD_CLEARANCE), "down")

	# An area (the fireplace): just above it, finger down.
	return _placed(Vector2(box.get_center().x, box.position.y - CLEARANCE), "down")


## The marker whose fingertip (at full reach) lands on `tip`.
static func _placed(tip: Vector2, point: String) -> Dictionary:
	return { "position": tip - TIP[point], "point": point }


## [node path, travel direction or ""] for this map, or [] for nothing.
static func _hop(map: Node, target: String) -> Array:
	if map == null or not TARGETS.has(target):
		return []

	var spec: Array = TARGETS[target]
	var here := str(map.name)

	if spec[0] == here:
		return [] if spec[1] == "" else [spec[1], ""]

	var next := next_map(here, spec[0])

	if next == "":
		return []

	return EXITS[here][next]


## What the player sees of a node: its sprites' visible pixels, else its
## trigger's shape.
static func _bounds(node: Node2D) -> Rect2:
	var sprites := _sprites(node)

	if not sprites.is_empty():
		var box := _sprite_rect(sprites[0])
		for s in sprites:
			box = box.merge(_sprite_rect(s))
		return box

	for child in node.get_children():
		if child is CollisionShape2D and child.shape is RectangleShape2D:
			var size: Vector2 = child.shape.size
			return Rect2(child.global_position - size / 2.0, size)

	return Rect2(node.global_position, Vector2.ZERO)


static func _sprites(node: Node2D) -> Array:
	return [node] if _is_sprite(node) else node.get_children().filter(_is_sprite)


static func _is_sprite(node: Node) -> bool:
	return node is Sprite2D or node is AnimatedSprite2D


## The sprite's visible (non-transparent) pixels, in the world.
static func _sprite_rect(s: Node2D) -> Rect2:
	var tex: Texture2D = null

	if s is Sprite2D:
		tex = s.texture
	elif s is AnimatedSprite2D and s.sprite_frames != null:
		tex = s.sprite_frames.get_frame_texture(s.animation, 0)

	if tex == null:
		return Rect2(s.global_position, Vector2.ZERO)

	var size := tex.get_size()
	var top_left: Vector2 = s.offset - (size / 2.0 if s.centered else Vector2.ZERO)
	var used := _opaque(tex)
	return Rect2(s.global_position + (top_left + used.position) * s.global_scale, used.size * s.global_scale)


static var _opaque_cache := {}


static func _opaque(tex: Texture2D) -> Rect2:
	if not _opaque_cache.has(tex):
		var img := tex.get_image()
		_opaque_cache[tex] = Rect2(img.get_used_rect()) if img != null else Rect2(Vector2.ZERO, tex.get_size())
	return _opaque_cache[tex]


## The Interactable that is the target, or that it carries (an NPC's Talk).
## Found by its method rather than its class, so this table compiles alone.
static func _interactable(node: Node) -> Node:
	if node.has_method("is_player_in_range"):
		return node

	for child in node.get_children():
		if child.has_method("is_player_in_range"):
			return child

	return null


## The neighbouring map to walk into next on the way from one map to another.
static func next_map(from: String, to: String) -> String:
	if from == to or not EXITS.has(from):
		return ""

	var came_from := { from: "" }
	var queue: Array[String] = [from]

	while not queue.is_empty():
		var map: String = queue.pop_front()
		for next: String in EXITS.get(map, {}):
			if came_from.has(next):
				continue
			came_from[next] = map
			if next == to:
				var step := next
				while came_from[step] != from:
					step = came_from[step]
				return step
			queue.append(next)

	return ""
