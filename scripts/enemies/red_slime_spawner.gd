extends Node2D

## Keeps one red slime alive per spawn point on this map.
##
## A killed slime comes back at its own point after respawn_delay, with
## full health. The respawn timers are children of this node, so leaving
## the map frees them along with everything else: nothing is left pending
## and nothing follows Kiren into another scene.
##
## Also owns the grid the slimes path-find on, built from the map's real
## static colliders so they walk around trees and walls.

const SLIME := preload("res://scenes/enemies/red_slime.tscn")

## Markers (the old Map1Slime01-03 positions) a slime spawns on.
@export var spawn_points: Array[NodePath] = []
@export var respawn_delay := 5.0
## Grid resolution for path-finding, in pixels.
@export var path_cell := 8
## The slime's body footprint (its CollisionShape2D size); a grid cell is
## open only if a body this size fits there.
@export var body_size := Vector2(16, 6)

## Spawning is postponed while Kiren stands this close to the point.
const SPAWN_CLEARANCE := 28.0
const RETRY := 0.5

var _slots: Array[Dictionary] = []
var _grid: AStarGrid2D
var _query: PhysicsShapeQueryParameters2D


func _ready() -> void:
	for i in spawn_points.size():
		var marker := get_node_or_null(spawn_points[i]) as Node2D

		if marker == null:
			push_warning("RedSlimeSpawner: missing spawn point %s" % spawn_points[i])
			continue

		var timer := Timer.new()
		timer.name = "Respawn%d" % (i + 1)
		timer.one_shot = true
		add_child(timer)

		var slot := { "point": marker.global_position, "slime": null, "timer": timer }
		timer.timeout.connect(_spawn.bind(_slots.size()))
		_slots.append(slot)

	# The space can't be queried yet on the map's first frame; the spawn
	# points themselves are fixed, open ground.
	for i in _slots.size():
		_spawn(i, false)


func _physics_process(_delta: float) -> void:
	# The physics space is only queryable once the map is in the tree and
	# has stepped, so the grid is built on the first physics frame.
	if _grid == null:
		_build_grid()
	set_physics_process(false)


func get_slime(slot: int) -> Node2D:
	var slime: Node2D = _slots[slot]["slime"]
	return slime if is_instance_valid(slime) else null


func spawn_point(slot: int) -> Vector2:
	return _slots[slot]["point"]


func slot_count() -> int:
	return _slots.size()


func _spawn(slot: int, check_geometry := true) -> void:
	var s := _slots[slot]

	# Exactly one living slime per slot.
	if is_instance_valid(s["slime"]):
		return

	if not _point_is_clear(s["point"], check_geometry):
		s["timer"].start(RETRY)
		return

	var slime := SLIME.instantiate()
	slime.name = "RedSlime%d" % (slot + 1)
	slime.spawner = self
	slime.position = to_local(s["point"])
	slime.died.connect(_on_slime_died.bind(slot))
	s["slime"] = slime
	add_child(slime, true)


func _on_slime_died(slot: int) -> void:
	_slots[slot]["slime"] = null
	_slots[slot]["timer"].start(respawn_delay)


## Not on top of Kiren, and nothing solid where the body would stand.
func _point_is_clear(point: Vector2, check_geometry := true) -> bool:
	var feet := point + Vector2(0, 12)
	var player := get_tree().get_first_node_in_group("player") as Node2D

	if player != null and feet.distance_to(player.global_position + Vector2(0, 14)) < SPAWN_CLEARANCE:
		return false

	return not check_geometry or _hits_at(feet, false).is_empty()


func _hits_at(feet: Vector2, static_only: bool) -> Array:
	if _query == null:
		var shape := RectangleShape2D.new()
		shape.size = body_size
		_query = PhysicsShapeQueryParameters2D.new()
		_query.shape = shape
		_query.collision_mask = 1

	_query.transform = Transform2D(0.0, feet)
	var hits := get_world_2d().direct_space_state.intersect_shape(_query, 8)

	if static_only:
		return hits.filter(func(h): return h["collider"] is StaticBody2D)

	return hits.filter(func(h): return not (h["collider"] is Area2D))


# --- path-finding ------------------------------------------------------

func _build_grid() -> void:
	var ground := get_parent().get_node_or_null("Ground") as TileMapLayer

	if ground == null:
		push_warning("RedSlimeSpawner: no Ground layer to size the path grid")
		return

	var used := ground.get_used_rect()
	var tile := Vector2(ground.tile_set.tile_size)
	var top_left := ground.to_global(Vector2(used.position) * tile)
	var size := Vector2(used.size) * tile

	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(Vector2i.ZERO, Vector2i(size / path_cell))
	_grid.cell_size = Vector2(path_cell, path_cell)
	_grid.offset = top_left + Vector2(path_cell, path_cell) / 2.0
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()

	for x in _grid.region.size.x:
		for y in _grid.region.size.y:
			var cell := Vector2i(x, y)
			if not _hits_at(_grid.get_point_position(cell), true).is_empty():
				_grid.set_point_solid(cell)


## World-space waypoints (feet positions) from one point towards another.
## Ends as close to the target as the map allows if it can't be reached.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array()

	var a := _open_cell_near(_cell_at(from))
	var b := _cell_at(to)

	if a == Vector2i(-1, -1) or not _grid.is_in_boundsv(b):
		return PackedVector2Array()

	return _grid.get_point_path(a, b, true)


func _cell_at(p: Vector2) -> Vector2i:
	return Vector2i(((p - _grid.offset) / path_cell).round())


## A slime squeezed against a tree can sit in a "solid" cell; start its
## search from the nearest open one.
func _open_cell_near(cell: Vector2i) -> Vector2i:
	for r in 4:
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var c := cell + Vector2i(dx, dy)
				if _grid.is_in_boundsv(c) and not _grid.is_point_solid(c):
					return c

	return Vector2i(-1, -1)
