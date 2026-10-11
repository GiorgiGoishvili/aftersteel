extends CharacterBody2D

## Kiren on the overworld.
##
## Every animation lives in KirenSpriteFrames.tres. Unarmed, Kiren has the
## four-facing set (F down, B up, L, R + Idle / Walk). With the sword out he
## only has the side-view set (L / R + SIdle / SWalk / SAttack / SHurt), so
## moving up or down keeps the last left/right look, while `facing` - which
## aims the blade - still follows all four directions.
##
## Fights happen right here on the map: a three-hit combo (one attack per
## press), the sword hitbox (one shape per facing, slash or thrust) dealing
## damage only on each attack's strike frames, and enemies hit Kiren through
## take_damage().

@export var speed: float = 100.0

## Scales the playback of every animation. 1.0 keeps the authored timing;
## each animation's own speed and frame durations are in the SpriteFrames.
@export var animation_speed := 1.0:
	set(value):
		animation_speed = value
		if sprite != null:
			sprite.speed_scale = value

## The combo, in order. Per attack: its animation (side + "anim"), the frames
## (0-based) its blade can hit on, damage and enemy knockback as multiples of
## the base, the frame from which a queued next attack takes over (one past
## the last frame = only when it ends), its hitbox ("" slash, "T" thrust) and
## whether it lunges forward on its first strike frame.
@export var combo: Array[Dictionary] = [
	{"anim": "SAttack", "strike": [4], "damage": 1.0, "knockback": 1.0, "chain_from": 6, "hitbox": "", "lunge": false},
	{"anim": "SAttack2", "strike": [1, 2], "damage": 1.25, "knockback": 1.3, "chain_from": 7, "hitbox": "", "lunge": false},
	{"anim": "SAttack3", "strike": [3, 4], "damage": 1.5, "knockback": 2.0, "chain_from": 9, "hitbox": "T", "lunge": true},
]

## After an attack ends, how long a press still continues the combo; later
## presses start again from the first attack. Short, so quick clicks chain
## but a click about a second after the last one starts a fresh Attack 1
## (Attack 1 alone lasts 0.8 s). Presses during an attack always queue.
@export var combo_window := 0.15

## The finisher's step forward: this speed (px/s), fading over lunge_time.
## It moves like any other step, so walls and bodies stop it.
@export var lunge_speed := 120.0
@export var lunge_time := 0.15

## Share of his walking speed Kiren keeps while swinging. He keeps facing
## the way he swings, so the blade and the animation stay on one side.
@export var attack_move_factor := 0.5

## Seconds after a hit during which Kiren can't be hurt again. He can still
## move, attack and be pushed in that time.
@export var hurt_protection := 0.6

## Tint Kiren flashes when he takes a hit, and how long it takes to fade.
@export var hurt_flash_color := Color(1.0, 0.35, 0.35)
@export var hurt_flash_time := 0.1

## A hit shoves Kiren away from whatever struck him: this speed (px/s),
## falling to nothing over knockback_time. It adds to his own movement, so
## the keys keep working, and it slides along walls like any other move.
@export var knockback_speed := 160.0
@export var knockback_time := 0.15

## Sword animations drawn by flipping the right-facing frames.
const MIRRORED := ["LSIdle"]

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword_hitbox: Area2D = $SwordHitbox

## The way Kiren last faced. Kept when he stops walking. Aims the sword.
var facing := "F"

## Left or right: which side-view sword animation shows. Only a left/right
## input changes it, so walking up or down keeps it. Starts on the right.
var side := "R"

## A sword attack that plays through once; it only slows Kiren. Empty while
## he is free.
var _one_shot := ""

## Which combo attack is playing, or played last (index into `combo`).
var combo_step := 0

## Time left in which a press continues the combo (0 = it starts over).
var _combo_open := 0.0

## A press made during an attack: the next attack takes over when this one
## allows. One press, one attack - more presses don't stack.
var _combo_queued := false

## The left mouse button is held down (pressed while Kiren could attack and
## not yet released): the combo keeps going, 1-2-3-1..., until it lets go.
var _attack_held := false

## What is left of the last hit's shove, and of the finisher's lunge.
var _knockback := Vector2.ZERO
var _lunge := Vector2.ZERO
var _lunged := false

var _last_hp := 0
var _protected := 0.0
var _defeated := false

## Instance ids of enemies the current swing has already hit.
var _swing_hits := {}

var _flash_tween: Tween


func _ready() -> void:
	sprite.speed_scale = animation_speed
	sprite.animation_finished.connect(_on_animation_finished)

	_last_hp = GameState.get_player_hp()
	GameState.player_health_changed.connect(_on_health_changed)

	_aim_sword("")
	_play_loop(_loop_animation(false))


func _physics_process(delta: float) -> void:
	_tick_protection(delta)
	_knockback = _knockback.move_toward(Vector2.ZERO, knockback_speed / knockback_time * delta)
	_lunge = _lunge.move_toward(Vector2.ZERO, lunge_speed / lunge_time * delta)

	var attacking := _one_shot != ""

	if attacking:
		_attack_frame()
	else:
		_combo_open = maxf(_combo_open - delta, 0.0)

		# Still holding the button (after a hit, say): start again.
		if _attack_held and _can_attack():
			_start_attack(_next_step() if _combo_open > 0.0 else 0)
			attacking = true

	var direction := Vector2.ZERO

	# Dialogue / menus / cutscenes hold this lock. Stand still and idle.
	if not GameState.input_locked and (_one_shot == "" or attacking) and not _defeated:
		direction = Input.get_vector(
			"move_left",
			"move_right",
			"move_up",
			"move_down"
		)

	velocity = direction * speed * (attack_move_factor if attacking else 1.0) + _knockback + _lunge

	if direction != Vector2.ZERO and not attacking:
		facing = _facing_for(direction)
		if direction.x != 0.0:
			side = "R" if direction.x > 0.0 else "L"

	if _one_shot == "" and not _defeated:
		_play_loop(_loop_animation(direction != Vector2.ZERO))

	move_and_slide()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("attack"):
		return

	if not _can_attack():
		return

	# Only the mouse button repeats while held; a key press is one attack.
	if event is InputEventMouseButton:
		_attack_held = true

	# A press during an attack lines up the next one; it never restarts the
	# one playing.
	if _one_shot != "":
		_combo_queued = true
		return

	_start_attack(_next_step() if _combo_open > 0.0 else 0)


## Releases are watched here, before the UI, so a release over a menu or the
## HUD still ends the hold.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_attack_held = false


func _notification(what: int) -> void:
	# Alt-tabbing away or pausing mid-hold: the release would never arrive.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or what == NOTIFICATION_PAUSED:
		_attack_held = false


func _can_attack() -> bool:
	return not GameState.input_locked and not _defeated and GameState.has_weapon_equipped()


## Called by enemies when a strike connects, with where the blow came from.
## Returns false when Kiren is still protected from the last hit (or down).
func take_damage(amount: int, from: Vector2) -> bool:
	if _protected > 0.0 or _defeated:
		return false

	_protected = hurt_protection
	_knockback = _away_from(from) * knockback_speed
	GameState.damage_player(amount)
	return true


func _start_attack(step: int) -> void:
	var attack: Dictionary = combo[step]
	combo_step = step
	_combo_queued = false
	_combo_open = 0.0
	_lunged = false
	_swing_hits.clear()

	# The blade goes the way Kiren faces, all four ways; the attack is drawn
	# to his left or right side.
	_aim_sword(str(attack["hitbox"]) + facing)
	_start_one_shot(side + str(attack["anim"]))


func _next_step() -> int:
	return (combo_step + 1) % combo.size()


## Each physics frame of an attack: the blade on its strike frames, the
## finisher's lunge, and a queued next attack taking over once allowed.
func _attack_frame() -> void:
	var attack: Dictionary = combo[combo_step]
	var frame := sprite.frame

	if attack["strike"].has(frame):
		_sword_strike(attack)

	if attack["lunge"] and not _lunged and frame >= attack["strike"][0]:
		_lunged = true
		_lunge = _ahead() * lunge_speed

	if (_combo_queued or _attack_held) and frame >= int(attack["chain_from"]) and _can_attack():
		_start_attack(_next_step())


## Every enemy hurtbox the blade overlaps takes one hit per attack. An enemy
## still shrugging off the last hit is tried again on the next strike frame.
func _sword_strike(attack: Dictionary) -> void:
	if not GameState.has_weapon_equipped():
		return

	var damage := roundi(float(GameState.player_stats.get("attack_damage", 20)) * float(attack["damage"]))
	var push := float(attack["knockback"])

	for area in sword_hitbox.get_overlapping_areas():
		var enemy := area.get_parent()
		var id := enemy.get_instance_id()

		if _swing_hits.has(id) or not enemy.has_method("take_damage"):
			continue

		var landed: bool
		if enemy.get_method_argument_count("take_damage") >= 3:
			landed = enemy.take_damage(damage, global_position, push)
		else:
			landed = enemy.take_damage(damage, global_position)

		if landed:
			_swing_hits[id] = true


func _on_health_changed(current: int, _maximum: int) -> void:
	var took_damage := current < _last_hp
	_last_hp = current

	# No stagger: a hit flashes Kiren and cuts a swing short, and he keeps
	# running (take_damage adds the shove).
	if took_damage:
		_flash()
		_cancel_attack()

	if current <= 0 and not _defeated:
		_defeat()


## The old battle scene's loss handling (full health, try again), done in
## place: Kiren picks himself up at this map's entrance.
func _defeat() -> void:
	_defeated = true
	_one_shot = ""
	_aim_sword("")
	velocity = Vector2.ZERO
	GameState.input_locked = true

	if GameState.has_weapon_equipped():
		_play(side + "SHurt")

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
	if sprite.animation != _one_shot:
		return

	if (_combo_queued or _attack_held) and _can_attack():
		_start_attack(_next_step())
		return

	_one_shot = ""
	_combo_queued = false
	_aim_sword("")
	_combo_open = combo_window


func _start_one_shot(anim: String) -> void:
	_one_shot = anim
	velocity = Vector2.ZERO
	sprite.stop()
	_play(anim)


## Getting hit ends the attack and the combo: the next press starts over.
func _cancel_attack() -> void:
	combo_step = 0
	_combo_open = 0.0
	_combo_queued = false
	_lunge = Vector2.ZERO

	if _one_shot == "":
		return

	_one_shot = ""
	_aim_sword("")


## Unit vector the way Kiren faces (which the blade and lunge follow).
func _ahead() -> Vector2:
	var ahead := {"F": Vector2.DOWN, "B": Vector2.UP, "L": Vector2.LEFT, "R": Vector2.RIGHT}
	return ahead[facing]


## Unit vector from the blow's origin to Kiren; straight back from where he
## faces if the two overlap exactly.
func _away_from(from: Vector2) -> Vector2:
	var away := global_position - from

	if away.length() > 0.5:
		return away.normalized()

	return -_ahead()


## Enables only the blade shape for one facing ("" disables them all).
func _aim_sword(dir: String) -> void:
	for shape in sword_hitbox.get_children():
		shape.set_deferred("disabled", shape.name != dir)


func _loop_animation(moving: bool) -> String:
	var gait := "Walk" if moving else "Idle"

	if GameState.has_weapon_equipped():
		return side + "S" + gait

	return facing + gait


func _play_loop(anim: String) -> void:
	if sprite.animation != anim or not sprite.is_playing():
		_play(anim)


func _play(anim: String) -> void:
	sprite.flip_h = MIRRORED.has(anim)
	sprite.play(anim)


## A brief tint on the sprite, so a hit reads even without a hurt pose.
func _flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()

	sprite.modulate = hurt_flash_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(sprite, "modulate", Color.WHITE, hurt_flash_time)


func _facing_for(direction: Vector2) -> String:
	if abs(direction.x) > abs(direction.y):
		return "R" if direction.x > 0 else "L"

	return "F" if direction.y > 0 else "B"
