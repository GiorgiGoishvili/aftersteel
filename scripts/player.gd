extends CharacterBody2D

## Kiren on the overworld.
##
## Every animation lives in KirenSpriteFrames.tres and is named after its
## Aseprite tag: facing (F down, B up, L, R), then S while the sword is
## equipped, then Idle / Walk / Attack / Hurt - FIdle, LSWalk, RSAttack...
##
## Fights happen right here on the map: the sword hitbox (one shape per
## facing) is live only on the swing's strike frames, and enemies hit
## Kiren through take_damage().

@export var speed: float = 100.0

## Scales the playback of every animation. 1.0 keeps the authored timing
## (300 ms a frame); each animation's own speed is in the SpriteFrames.
@export var animation_speed := 1.0:
	set(value):
		animation_speed = value
		if sprite != null:
			sprite.speed_scale = value

## Frames of the sword attacks (0-based) on which the blade can hit.
@export var sword_strike_frames: Array[int] = [2]

## Seconds after a hit during which Kiren can't be hurt again.
@export var hurt_protection := 0.8

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword_hitbox: Area2D = $SwordHitbox

## The way Kiren last faced. Kept when he stops walking.
var facing := "F"

## An attack or hurt animation that plays through once before Kiren can
## move again. Empty while he is free.
var _one_shot := ""

var _last_hp := 0
var _protected := 0.0
var _defeated := false

## Instance ids of enemies the current swing has already hit.
var _swing_hits := {}


func _ready() -> void:
	sprite.speed_scale = animation_speed
	sprite.animation_finished.connect(_on_animation_finished)

	_last_hp = GameState.get_player_hp()
	GameState.player_health_changed.connect(_on_health_changed)

	_aim_sword("")
	_play_loop(_loop_animation(false))


func _physics_process(delta: float) -> void:
	_tick_protection(delta)

	if _one_shot.ends_with("SAttack") and sword_strike_frames.has(sprite.frame):
		_sword_strike()

	var direction := Vector2.ZERO

	# Dialogue / menus / cutscenes hold this lock. Stand still and idle.
	if not GameState.input_locked and _one_shot == "" and not _defeated:
		direction = Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

	velocity = direction * speed

	if direction != Vector2.ZERO:
		facing = _facing_for(direction)

	if _one_shot == "" and not _defeated:
		_play_loop(_loop_animation(direction != Vector2.ZERO))

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return

	if GameState.input_locked or _one_shot != "" or _defeated or not GameState.has_weapon_equipped():
		return

	_swing_hits.clear()
	_aim_sword(facing)
	_start_one_shot(facing + "SAttack")


## Called by enemies when a strike connects. Returns false when Kiren is
## still protected from the last hit (or already down).
func take_damage(amount: int, _from: Vector2) -> bool:
	if _protected > 0.0 or _defeated:
		return false

	_protected = hurt_protection
	GameState.damage_player(amount)
	return true


## Every enemy hurtbox the facing blade overlaps takes one hit per swing.
func _sword_strike() -> void:
	if not GameState.has_weapon_equipped():
		return

	var damage := int(GameState.player_stats.get("attack_damage", 20))

	for area in sword_hitbox.get_overlapping_areas():
		var enemy := area.get_parent()
		var id := enemy.get_instance_id()

		if _swing_hits.has(id) or not enemy.has_method("take_damage"):
			continue

		_swing_hits[id] = true
		enemy.take_damage(damage, global_position)


func _on_health_changed(current: int, _maximum: int) -> void:
	var took_damage := current < _last_hp
	_last_hp = current

	if current <= 0 and not _defeated:
		_defeat()
		return

	# The hurt frames are drawn with the sword out (FSHurt...), so there is
	# nothing to play while Kiren is unarmed.
	if took_damage and GameState.has_weapon_equipped():
		_start_one_shot(facing + "SHurt")


## The old battle scene's loss handling (full health, try again), done in
## place: Kiren picks himself up at this map's entrance.
func _defeat() -> void:
	_defeated = true
	_one_shot = ""
	_aim_sword("")
	velocity = Vector2.ZERO
	GameState.input_locked = true

	if GameState.has_weapon_equipped():
		sprite.play(facing + "SHurt")

	get_tree().create_timer(1.2).timeout.connect(_recover)


func _recover() -> void:
	GameState.reset_player_hp()
	GameState.input_locked = false
	GameState.next_spawn = ""
	get_tree().reload_current_scene()


func _tick_protection(delta: float) -> void:
	if _protected <= 0.0:
		return

	_protected = maxf(_protected - delta, 0.0)


func _on_animation_finished() -> void:
	if sprite.animation == _one_shot:
		if _one_shot.ends_with("SAttack"):
			_aim_sword("")
		_one_shot = ""


func _start_one_shot(anim: String) -> void:
	# Getting hurt mid-swing ends the swing.
	if not anim.ends_with("SAttack"):
		_aim_sword("")

	_one_shot = anim
	velocity = Vector2.ZERO
	sprite.stop()
	sprite.play(anim)


## Enables only the blade shape for one facing ("" disables them all).
func _aim_sword(dir: String) -> void:
	for shape in sword_hitbox.get_children():
		shape.set_deferred("disabled", shape.name != dir)


func _loop_animation(moving: bool) -> String:
	var sword := "S" if GameState.has_weapon_equipped() else ""
	return facing + sword + ("Walk" if moving else "Idle")


func _play_loop(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		sprite.play(anim)


func _facing_for(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "R" if direction.x > 0 else "L"

	return "F" if direction.y > 0 else "B"
