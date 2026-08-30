extends Node2D

## Kiren during a fight. Real time: he moves whenever the player holds a
## direction and swings when E is pressed. Nothing waits for a turn.
##
## Deliberately separate from the 32x32 overworld player.gd - exploration
## and combat stay independent.

signal health_changed(current: int, maximum: int)
signal died

enum State { IDLE, MOVING, ATTACKING, HURT, DEAD }

@onready var hurtbox: Area2D = $Hurtbox
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D

var rig: BattleRig
var state: int = State.IDLE
var max_hp := CombatData.KIREN_MAX_HP
var current_hp := CombatData.KIREN_MAX_HP
var damage := CombatData.KIREN_DAMAGE

var arena: Rect2 = Rect2(24, 56, 272, 108)

var _invuln := 0.0
var _already_hit: Array = []
var _knockback := Vector2.ZERO
var _hurt_timer := 0.0


func _ready() -> void:
	rig = BattleRig.new()
	rig.name = "Rig"
	add_child(rig)
	move_child(rig, 0)
	rig.configure(CombatData.kiren_states())
	rig.animation_finished.connect(_on_anim_finished)
	rig.play("idle")

	attack_hitbox.monitoring = false
	attack_hitbox.area_entered.connect(_on_attack_area_entered)


func setup(hp: int, hp_max: int) -> void:
	max_hp = hp_max
	current_hp = clampi(hp, 0, hp_max)
	health_changed.emit(current_hp, max_hp)


func _physics_process(delta: float) -> void:
	if _invuln > 0.0:
		_invuln -= delta
		modulate.a = 0.45 if int(_invuln * 20.0) % 2 == 0 else 1.0
		if _invuln <= 0.0:
			modulate.a = 1.0

	if state == State.DEAD:
		return

	if _knockback.length() > 1.0:
		position += _knockback * delta
		_knockback = _knockback.lerp(Vector2.ZERO, delta * 8.0)
		_clamp_to_arena()

	# Priority: DEAD > HURT > ATTACKING > MOVING/IDLE. Nothing lower may
	# overwrite something higher.
	match state:
		State.HURT:
			_hurt_timer -= delta
			if _hurt_timer <= 0.0:
				state = State.IDLE
				rig.play("idle")
		State.ATTACKING:
			_update_attack()
		_:
			_update_free(delta)


func _update_free(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		_start_attack()
		return

	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if dir == Vector2.ZERO:
		state = State.IDLE
		rig.play("idle")
		return

	state = State.MOVING
	rig.set_direction(BattleRig.dir_from_vector(dir))
	rig.play("move")
	position += dir * CombatData.KIREN_MOVE_SPEED * delta
	_clamp_to_arena()


func _start_attack() -> void:
	state = State.ATTACKING
	_already_hit.clear()
	rig.play("attack", true)
	Sfx.play("sword_swing")
	_position_hitbox()


## The hitbox is live only on the strike frame, so a swing that ends
## before Kiren closes the distance genuinely misses.
func _update_attack() -> void:
	var live := rig.frame == CombatData.KIREN_HIT_FRAME
	if live and not attack_hitbox.monitoring:
		_position_hitbox()
	attack_hitbox.monitoring = live


func _position_hitbox() -> void:
	var reach := 20.0
	match rig.direction:
		BattleRig.DIR_RIGHT: attack_shape.position = Vector2(reach, -15)
		BattleRig.DIR_LEFT:  attack_shape.position = Vector2(-reach, -15)
		BattleRig.DIR_UP:    attack_shape.position = Vector2(0, -15 - reach)
		_:                   attack_shape.position = Vector2(0, -15 + reach)


func _on_attack_area_entered(area: Area2D) -> void:
	var target := area.get_parent()

	# One hit per swing, however many frames stay overlapping.
	if target in _already_hit:
		return

	if not target.has_method("take_damage"):
		return

	_already_hit.append(target)
	Sfx.play("sword_hit")
	target.take_damage(damage, global_position)


func _on_anim_finished(finished: String) -> void:
	if finished == "attack":
		attack_hitbox.monitoring = false
		state = State.IDLE
		rig.play("idle")
	elif finished == "hurt_placeholder":
		state = State.IDLE
		rig.play("idle")


## Set during the closing duel so the scripted ending cannot be spoiled
## by Kiren dying mid-conversation.
var invincible := false


func take_damage(amount: int, from: Vector2) -> void:
	if state == State.DEAD or _invuln > 0.0:
		return

	if invincible:
		current_hp = maxi(current_hp, 1)

	current_hp = clampi(current_hp - amount, 0, max_hp)

	if invincible:
		current_hp = maxi(current_hp, 1)
	health_changed.emit(current_hp, max_hp)
	Sfx.play("player_hurt")

	if current_hp <= 0:
		_die()
		return

	_invuln = CombatData.HURT_INVULN
	_knockback = (global_position - from).normalized() * CombatData.KIREN_KNOCKBACK * 8.0
	attack_hitbox.monitoring = false

	# TEMPORARY hit reaction - there is no Character_Hit sheet, so this is
	# a brief interruption plus the invulnerability flash.
	state = State.HURT
	_hurt_timer = CombatData.HURT_STAGGER
	rig.play("idle")


func _die() -> void:
	state = State.DEAD
	attack_hitbox.monitoring = false
	hurtbox.monitoring = false
	hurtbox.monitorable = false
	modulate.a = 1.0
	rig.play("death")
	died.emit()


func _clamp_to_arena() -> void:
	position.x = clampf(position.x, arena.position.x, arena.position.x + arena.size.x)
	position.y = clampf(position.y, arena.position.y, arena.position.y + arena.size.y)
