extends Node2D

## One enemy controller for every enemy. All the differences between
## Skeleton, Witch Doctor and Gollux live in CombatData.ENEMIES, not in
## three copies of this script.
##
## Deliberately tiny AI: approach (or back off, if it prefers range),
## wind up, strike, recover, cool down. No behaviour tree, no pathfinding
## and no turns - it runs on its own clock while Kiren runs on his.

signal health_changed(current: int, maximum: int)
signal died

enum State { IDLE, APPROACH, WINDUP, STRIKE, RECOVER, DEAD, HURT }

const PROJECTILE := preload("res://scenes/combat/projectile.tscn")

@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var rig: BattleRig
var target: Node2D
var state: int = State.IDLE
var data: Dictionary = {}

var display_name := "SKELETON"
var max_hp := 60
var current_hp := 60
var damage := 12
var move_speed := 42.0
var attack_range := 26.0
var attack_cooldown := 1.4

var ranged := false
var projectile_speed := 78.0
var keep_distance := 56.0
var windup_time := 0.35
var strike_time := 0.18
var recover_time := 0.30

var arena: Rect2 = Rect2(24, 56, 272, 108)

## Placeholder enemies are tinted; kept so the hit flash restores it.
var base_tint := Color.WHITE

var _cool := 0.0
var _timer := 0.0
var _hit_this_swing := false
var _knockback := Vector2.ZERO
var _lunge := Vector2.ZERO
var _has_attack_anim := false
var _hurt_timer := 0.0


func setup(enemy_id: String) -> void:
	data = CombatData.enemy(enemy_id)
	display_name = data["display_name"]
	max_hp = data["max_hp"]
	current_hp = max_hp
	damage = data["damage"]
	move_speed = data["move_speed"]
	attack_range = data["attack_range"]
	attack_cooldown = data["attack_cooldown"]

	ranged = data.get("ranged", false)
	projectile_speed = data.get("projectile_speed", 78.0)
	keep_distance = data.get("keep_distance", 56.0)
	windup_time = data.get("windup", 0.35)
	strike_time = data.get("strike", 0.18)
	recover_time = data.get("recover", 0.30)

	var path: String = data["sheets"]
	rig = BattleRig.new()
	rig.name = "Rig"
	rig.foot_y = data.get("foot_offset", -80.0)
	add_child(rig)
	move_child(rig, 0)

	var states := {
		"idle": {"frames": data["idle_frames"], "speed": 0.20, "loop": true,
				 "layers": [path % "Idle"]},
		"move": {"frames": data["move_frames"], "speed": 0.11, "loop": true,
				 "layers": [path % "Move"]},
	}

	# Only some enemies ship an attack sheet; the rest reuse Move.
	var attack_anim: String = data.get("attack_anim", "")
	_has_attack_anim = attack_anim != "" and int(data.get("attack_frames", 0)) > 0

	if _has_attack_anim:
		var total: float = windup_time + strike_time + recover_time
		states["attack"] = {
			"frames": int(data["attack_frames"]),
			"speed": total / float(data["attack_frames"]),
			"loop": false,
			"layers": [path % attack_anim],
		}

	rig.configure(states)
	rig.play("idle")

	base_tint = data.get("tint", Color.WHITE)
	modulate = base_tint

	attack_hitbox.monitoring = false
	attack_hitbox.area_entered.connect(_on_attack_area_entered)
	health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if state == State.DEAD or target == null or rig == null:
		return

	if _knockback.length() > 1.0:
		position += _knockback * delta
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 8.0)
		_clamp_to_arena()

	if _cool > 0.0:
		_cool -= delta

	var to_target: Vector2 = target.global_position - global_position
	var dist := to_target.length()

	match state:
		State.HURT:
			_hurt_timer -= delta
			if _hurt_timer <= 0.0:
				state = State.IDLE
				rig.play("idle")

		State.IDLE, State.APPROACH:
			_face(to_target)

			if _target_dead():
				state = State.IDLE
				rig.play("idle")
				return

			if dist > attack_range:
				state = State.APPROACH
				rig.play("move")
				position += to_target.normalized() * move_speed * delta
				_clamp_to_arena()
			elif ranged and dist < keep_distance:
				# Casters back away rather than let Kiren stand on them.
				state = State.APPROACH
				rig.play("move")
				position -= to_target.normalized() * move_speed * delta
				_clamp_to_arena()
			elif _cool <= 0.0:
				_begin_windup(to_target)
			else:
				state = State.IDLE
				rig.play("idle")

		State.WINDUP:
			_timer -= delta
			position += _lunge * delta
			_clamp_to_arena()

			if _timer <= 0.0:
				state = State.STRIKE
				_timer = strike_time
				_hit_this_swing = false

				if ranged:
					_throw(to_target)
				else:
					_position_hitbox()
					attack_hitbox.monitoring = true

		State.STRIKE:
			_timer -= delta

			if _timer <= 0.0:
				attack_hitbox.monitoring = false
				state = State.RECOVER
				_timer = recover_time
				_lunge = -_lunge * 0.5

		State.RECOVER:
			_timer -= delta
			position += _lunge * delta
			_clamp_to_arena()

			if _timer <= 0.0:
				_lunge = Vector2.ZERO
				_cool = attack_cooldown
				state = State.IDLE
				rig.play("idle")


func _target_dead() -> bool:
	return "state" in target and target.state == 4


func _begin_windup(to_target: Vector2) -> void:
	state = State.WINDUP
	_timer = windup_time

	if _has_attack_anim:
		rig.play("attack", true)
	else:
		rig.play("move")

	# Casters plant their feet; melee steps into the swing.
	_lunge = Vector2.ZERO if ranged else to_target.normalized() * 26.0


func _face(to_target: Vector2) -> void:
	if bool(data.get("directional", true)):
		rig.set_direction(BattleRig.dir_from_vector(to_target))
	else:
		# Single-row sheet - mirrored, because no left-facing art exists.
		rig.scale.x = -1.0 if to_target.x < 0.0 else 1.0


func _throw(to_target: Vector2) -> void:
	var shot := PROJECTILE.instantiate()
	shot.damage = damage
	shot.velocity = to_target.normalized() * projectile_speed
	get_parent().add_child(shot)
	shot.global_position = global_position + Vector2(0, -15)


func _position_hitbox() -> void:
	var reach := 18.0

	match rig.direction:
		BattleRig.DIR_RIGHT: attack_shape.position = Vector2(reach, -15)
		BattleRig.DIR_LEFT:  attack_shape.position = Vector2(-reach, -15)
		BattleRig.DIR_UP:    attack_shape.position = Vector2(0, -15 - reach)
		_:                   attack_shape.position = Vector2(0, -15 + reach)

	# A non-directional rig only mirrors, so aim by the mirror instead.
	if not bool(data.get("directional", true)):
		attack_shape.position = Vector2(reach * signf(rig.scale.x), -15)


func _on_attack_area_entered(area: Area2D) -> void:
	if _hit_this_swing:
		return

	var who := area.get_parent()

	if not who.has_method("take_damage"):
		return

	_hit_this_swing = true
	who.take_damage(damage, global_position)


func take_damage(amount: int, from: Vector2) -> void:
	if state == State.DEAD:
		return

	current_hp = clampi(current_hp - amount, 0, max_hp)
	health_changed.emit(current_hp, max_hp)
	Sfx.play("enemy_hurt")

	# TEMPORARY hit reaction - most enemies have no Hit sheet.
	modulate = Color(1.6, 0.7, 0.7)
	create_tween().tween_property(self, "modulate", base_tint, 0.18)
	_knockback = (global_position - from).normalized() * CombatData.ENEMY_KNOCKBACK * 8.0

	if current_hp <= 0:
		_die()
		return

	# A stagger, but never mid-swing - being hit should not cancel a blow
	# that has already landed its hitbox.
	if state != State.STRIKE:
		attack_hitbox.monitoring = false
		state = State.HURT
		_hurt_timer = CombatData.HURT_STAGGER
		rig.play("idle")


func _die() -> void:
	state = State.DEAD
	attack_hitbox.monitoring = false
	hurtbox.monitoring = false
	hurtbox.monitorable = false
	rig.play("idle")

	# TEMPORARY death - no Death sheet exists for these enemies.
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.5)
	t.tween_callback(hide)
	died.emit()


func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena.position.x, arena.position.x + arena.size.x)
	position.y = clampf(position.y, arena.position.y, arena.position.y + arena.size.y)
