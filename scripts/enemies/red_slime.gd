extends CharacterBody2D

## A red slime. Chases Kiren anywhere on its map, stops in reach, and
## slams him on the strike frame of its attack. Spawned (and respawned)
## by red_slime_spawner.gd; it never leaves the scene it was spawned in.
##
## Animations are the Aseprite tags: F/B/L/R + Idle / Attack / Hurt.
## There is no walk sheet - the idle hop doubles as movement.

signal died

@export var max_health := 40
@export var damage := 6
@export var move_speed := 45.0
## Seconds between the end of one attack and the start of the next.
@export var attack_cooldown := 1.8
## Feet-to-feet distance at which it starts an attack.
@export var attack_range := 22.0
## Attack frame (0-based) on which the slam lands.
@export var strike_frame := 2
## Seconds after a hit during which it can't be hurt again.
@export var hurt_protection := 0.35

## Centre of the body collision shape, i.e. where the slime "stands".
const FEET := Vector2(0, 12)
const PLAYER_FEET := Vector2(0, 14)
const REPATH_TIME := 0.25

enum State { CHASE, ATTACK, HURT, DEAD }

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox

## Set by the spawner; provides find_path().
var spawner: Node
var health := 0
var facing := "F"
var state := State.CHASE

var _cooldown := 0.0
var _protected := 0.0
var _struck := false
var _path := PackedVector2Array()
var _repath := 0.0
var _player: Node2D


func _ready() -> void:
	health = max_health
	sprite.animation_finished.connect(_on_animation_finished)
	_aim_attack("")
	# Spread path requests so three slimes don't all search on one frame.
	_repath = randf() * REPATH_TIME
	sprite.play(facing + "Idle")


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return

	_cooldown = maxf(_cooldown - delta, 0.0)
	_protected = maxf(_protected - delta, 0.0)

	var player := _find_player()

	# Dialogue, menus and cutscenes hold everything still, slimes included.
	if player == null or GameState.input_locked:
		velocity = Vector2.ZERO
		return

	match state:
		State.CHASE:
			_chase(player, delta)
		State.ATTACK:
			_strike(player)


func _chase(player: Node2D, delta: float) -> void:
	var feet := global_position + FEET
	var goal := player.global_position + PLAYER_FEET
	var to_goal := goal - feet
	facing = _facing_for(to_goal)

	if to_goal.length() <= attack_range and _cooldown <= 0.0:
		_start_attack()
		return

	_repath -= delta
	if _repath <= 0.0:
		_repath = REPATH_TIME
		_path = spawner.find_path(feet, goal) if spawner != null else PackedVector2Array()

	# Close enough: wait out the cooldown instead of shoving into Kiren.
	if to_goal.length() <= attack_range * 0.7:
		velocity = Vector2.ZERO
	else:
		velocity = (_next_waypoint(feet, goal) - feet).normalized() * move_speed

	move_and_slide()
	_play(facing + "Idle")


## Follows the grid path; falls back to heading straight for Kiren when
## there is no path (e.g. before the grid is ready).
func _next_waypoint(feet: Vector2, goal: Vector2) -> Vector2:
	while _path.size() > 0 and feet.distance_to(_path[0]) < 4.0:
		_path.remove_at(0)

	if _path.size() <= 1:
		return goal

	return _path[0]


func _start_attack() -> void:
	state = State.ATTACK
	velocity = Vector2.ZERO
	_struck = false
	_aim_attack(facing)
	_play(facing + "Attack", true)


## The slam only lands on its strike frame, and at most once per attack.
func _strike(player: Node2D) -> void:
	if _struck or sprite.frame != strike_frame:
		return

	for area in attack_hitbox.get_overlapping_areas():
		if area.get_parent() == player and player.has_method("take_damage"):
			_struck = true
			player.take_damage(damage, global_position)
			return


## Called by Kiren's sword. Returns false if the hit didn't count.
func take_damage(amount: int, _from: Vector2) -> bool:
	if state == State.DEAD or _protected > 0.0:
		return false

	health = maxi(health - amount, 0)
	_protected = hurt_protection

	if health == 0:
		_die()
		return true

	# A hit cuts its own attack short.
	state = State.HURT
	velocity = Vector2.ZERO
	_aim_attack("")
	_play(facing + "Hurt", true)
	return true


## Stops attacking and colliding at once, flashes through its hurt
## frames, then fades and frees itself. The spawner handles the respawn.
func _die() -> void:
	state = State.DEAD
	velocity = Vector2.ZERO
	body_shape.set_deferred("disabled", true)
	hurtbox.set_deferred("monitorable", false)
	attack_hitbox.set_deferred("monitoring", false)
	_aim_attack("")
	died.emit()

	_play(facing + "Hurt", true)
	var fade := create_tween()
	fade.tween_interval(0.3)
	fade.tween_property(self, "modulate:a", 0.0, 0.25)
	fade.tween_callback(queue_free)


func _on_animation_finished() -> void:
	match state:
		State.ATTACK:
			_aim_attack("")
			_cooldown = attack_cooldown
			state = State.CHASE
		State.HURT:
			state = State.CHASE


## Enables only the strike shape for one facing ("" disables them all).
func _aim_attack(dir: String) -> void:
	for shape in attack_hitbox.get_children():
		shape.set_deferred("disabled", shape.name != dir)


func _play(anim: String, restart := false) -> void:
	if restart:
		sprite.stop()
		sprite.play(anim)
	elif sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _facing_for(v: Vector2) -> String:
	if abs(v.x) > abs(v.y):
		return "R" if v.x > 0 else "L"

	return "F" if v.y > 0 else "B"


func _find_player() -> Node2D:
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player") as Node2D
	return _player
