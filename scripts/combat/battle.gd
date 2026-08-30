extends Node2D

## Runs one real-time fight and hands control back to the overworld.
##
## Launching this scene directly starts a development fight against a
## skeleton at full HP, so combat can be iterated on without replaying
## the opening.
##
## One fight is special: the demo's closing duel against Demon Eira. It
## opens with dialogue, and instead of a victory it ends in a scripted
## draw - neither fighter can kill the other.

@onready var kiren: Node2D = $Arena/Kiren
@onready var enemy: Node2D = $Arena/Enemy
@onready var kiren_bar: ProgressBar = $BattleUI/KirenPanel/Bar
@onready var kiren_text: Label = $BattleUI/KirenPanel/Text
@onready var enemy_bar: ProgressBar = $BattleUI/EnemyPanel/Bar
@onready var enemy_text: Label = $BattleUI/EnemyPanel/Text
@onready var hint: Label = $BattleUI/Hint
@onready var result: Label = $BattleUI/Result
@onready var reward: Label = $BattleUI/Reward
@onready var fade: ColorRect = $BattleUI/Fade

const MUSIC_FADE := 1.0

var _over := false
var _won := false
var _dev_mode := false
var _enemy_id := "skeleton"
var _story_duel := false
var _draw_running := false


func _ready() -> void:
	_dev_mode = GameState.battle_enemy_id == ""
	_enemy_id = GameState.battle_enemy_id if not _dev_mode else "skeleton"

	# Launched straight from the editor: always start from a clean slate.
	if _dev_mode:
		GameState.reset_player_hp()

	Music.fade_out(MUSIC_FADE)

	enemy.setup(_enemy_id)
	enemy.target = kiren
	kiren.setup(GameState.player_stats["current_hp"], GameState.player_stats["max_hp"])
	kiren.damage = GameState.player_stats["attack_damage"]

	kiren.health_changed.connect(_on_kiren_health)
	enemy.health_changed.connect(_on_enemy_health)
	kiren.died.connect(_on_kiren_died)
	enemy.died.connect(_on_enemy_died)

	_on_kiren_health(kiren.current_hp, kiren.max_hp)
	_on_enemy_health(enemy.current_hp, enemy.max_hp)
	enemy_text.text = enemy.display_name

	result.hide()
	reward.hide()
	fade.color = Color(0, 0, 0, 0)
	hint.text = "WASD MOVE     E ATTACK"

	_story_duel = bool(enemy.data.get("is_story_duel", false))

	if _story_duel:
		# Neither fighter may die in the closing duel.
		kiren.invincible = true
		_run_intro_dialogue()


## The duel opens with a conversation, not a swing.
func _run_intro_dialogue() -> void:
	_freeze(true)
	await get_tree().create_timer(0.6).timeout
	Dialogue.start(CombatData.DEMON_EIRA_INTRO_LINES)
	await Dialogue.finished
	_freeze(false)


func _freeze(on: bool) -> void:
	kiren.set_physics_process(not on)
	enemy.set_physics_process(not on)
	kiren.set_process_unhandled_input(not on)


func _on_kiren_health(cur: int, maxi: int) -> void:
	kiren_bar.max_value = maxi
	kiren_bar.value = cur
	kiren_text.text = "KIREN   %d / %d" % [cur, maxi]
	GameState.player_stats["current_hp"] = cur


func _on_enemy_health(cur: int, maxi: int) -> void:
	enemy_bar.max_value = maxi
	enemy_bar.value = cur
	enemy_text.text = "%s   %d / %d" % [enemy.display_name, cur, maxi]

	# She is never killed - the fight is called off instead.
	if _story_duel and not _draw_running and cur <= CombatData.DEMON_EIRA_DRAW_HP:
		_draw_running = true
		_run_draw_sequence()


func _on_enemy_died() -> void:
	if _over or _story_duel:
		return

	_over = true
	_won = true
	GameState.mark_encounter_cleared(GameState.battle_encounter_id)
	Sfx.play("victory")

	# Rewards land in the pack before the overworld reloads.
	var lines: Array = []

	for entry in CombatData.rewards(_enemy_id):
		var item := Items.by_id(entry[0])

		if item.is_empty():
			continue

		GameState.add_item(item, int(entry[1]))
		lines.append("%s x%d" % [item["name"], int(entry[1])])

	if not lines.is_empty():
		reward.text = "Obtained:\n" + "\n".join(lines)
		reward.show()

	_finish("VICTORY", "[E] Continue")


func _on_kiren_died() -> void:
	if _over:
		return

	_over = true
	_won = false
	Sfx.play("defeat")
	_finish("DEFEATED", "[E] Retry")


## Neither VICTORY nor DEFEATED: the duel simply stops.
func _run_draw_sequence() -> void:
	_over = true

	# Clamp her above zero so a final blow cannot kill her.
	enemy.current_hp = maxi(enemy.current_hp, 1)
	enemy.state = 0
	enemy.attack_hitbox.monitoring = false
	enemy.hurtbox.monitoring = false
	enemy.hurtbox.monitorable = false
	enemy.rig.play("idle")

	kiren.attack_hitbox.monitoring = false
	kiren.state = 0
	kiren.rig.play("idle")

	_freeze(true)
	hint.text = ""
	Music.fade_out(1.2)

	await get_tree().create_timer(0.5).timeout
	Dialogue.start(CombatData.DEMON_EIRA_DRAW_LINES)
	await Dialogue.finished

	await _retreat()
	await _fade_out()

	GameState.clear_battle_context()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/demo_end.tscn")


## TEMPORARY retreat - no retreat animation exists. She steps back and
## fades out; replace with real art by swapping this for an animation.
func _retreat() -> void:
	Sfx.play("defeat")
	var away := (enemy.global_position - kiren.global_position).normalized()
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(enemy, "global_position",
		enemy.global_position + away * 46.0, 1.1).set_trans(Tween.TRANS_SINE)
	t.tween_property(enemy, "modulate:a", 0.0, 1.1)
	await t.finished
	enemy.hide()
	await get_tree().create_timer(0.5).timeout


func _fade_out() -> void:
	var t := create_tween()
	t.tween_property(fade, "color", Color(0, 0, 0, 1), 1.2)
	await t.finished


func _finish(text: String, hint_text: String) -> void:
	result.text = text
	result.show()
	hint.text = hint_text


func _unhandled_input(event: InputEvent) -> void:
	if not _over or _draw_running:
		return

	if not (event is InputEventKey):
		return

	if not event.pressed or event.echo or event.keycode != KEY_E:
		return

	get_viewport().set_input_as_handled()

	if _won:
		_leave()
	else:
		GameState.reset_player_hp()
		get_tree().call_deferred("reload_current_scene")


func _leave() -> void:
	var target_scene := GameState.battle_return_scene

	# Finishing the third demo fight summons the closing duel.
	if GameState.demo_encounters_cleared():
		GameState.battle_enemy_id = "demon_eira"
		GameState.battle_encounter_id = "demon_eira"
		GameState.battle_return_scene = ""
		GameState.battle_return_position = Vector2.ZERO
		get_tree().call_deferred("reload_current_scene")
		return

	# battle_return_position is deliberately NOT cleared here - the map
	# being returned to consumes it to stand Kiren beside the encounter,
	# and clears it itself.
	GameState.battle_enemy_id = ""
	GameState.battle_encounter_id = ""
	GameState.battle_return_scene = ""

	if target_scene == "":
		# Development launch - nothing to return to.
		get_tree().quit()
		return

	get_tree().call_deferred("change_scene_to_file", target_scene)
