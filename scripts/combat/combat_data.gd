class_name CombatData
extends RefCounted

## All combat tuning lives here so balance is one file, not five scripts.
## These numbers are TEMPORARY development values.

const W := "res://Assets/WeaponAnimations/"

## ===== DEMON EIRA PLACEHOLDER =====
## Swap this one line for her real sheets when the art arrives.
const DEMON_EIRA_SHEETS := "res://Assets/Enemies/WitchDoctor/Witch_Doctor_%s.png"

## She cannot be killed. When her HP drops to this the duel is called off.
const DEMON_EIRA_DRAW_HP := 65

## ===== DEMON EIRA DIALOGUE =====
## Both conversations live here so the text is in one obvious place.
const DEMON_EIRA_INTRO_LINES := [
	{"speaker": "EIRA", "text": "So it chose you after all."},
	{"speaker": "KIREN", "text": "What are you talking about?"},
	{"speaker": "EIRA", "text": "The amulet."},
	{"speaker": "EIRA", "text": "You have no idea what you're carrying."},
	{"speaker": "KIREN", "text": "Eira...?"},
	{"speaker": "EIRA", "text": "Not yet."},
]

const DEMON_EIRA_DRAW_LINES := [
	{"speaker": "KIREN", "text": "Wait!"},
	{"speaker": "EIRA", "text": "...You're stronger than I expected."},
	{"speaker": "EIRA", "text": "But you still don't understand that amulet."},
	{"speaker": "KIREN", "text": "Then tell me!"},
	{"speaker": "EIRA", "text": "Another time."},
]

# --- Kiren ------------------------------------------------------------
const KIREN_MAX_HP := 100
const KIREN_DAMAGE := 20
const KIREN_MOVE_SPEED := 70.0

## Seconds per frame. The attack animation is what limits attack spam -
## there is no artificial cooldown on top of it.
const IDLE_SPEED := 0.18
const MOVE_SPEED_ANIM := 0.09
const ATTACK_SPEED := 0.085

## Frame 3 of 6 is where the blade is fully extended (verified against
## the sheet: the sword's bounding box reaches furthest on that frame).
const KIREN_HIT_FRAME := 3

const HURT_INVULN := 0.45

## How long a hit interrupts the victim. Short enough that combat keeps
## flowing, long enough that hits read.
const HURT_STAGGER := 0.22
const KIREN_KNOCKBACK := 12.0
const ENEMY_KNOCKBACK := 8.0

## Kiren's default battle look. Beard and Hat are deliberately unused -
## they change who the character reads as. Sword_2 is the steel blade.
const KIREN_LAYERS := ["", "_Leggings", "_Boots", "_Chestplate", "_Gloves", "_Hair", "_Sword"]


static func kiren_states() -> Dictionary:
	return {
		"idle":   {"frames": 4, "speed": IDLE_SPEED, "loop": true,
				   "layers": _sheets("Idle")},
		"move":   {"frames": 6, "speed": MOVE_SPEED_ANIM, "loop": true,
				   "layers": _sheets("Move")},
		"attack": {"frames": 6, "speed": ATTACK_SPEED, "loop": false,
				   "layers": _sheets("Attack")},
		# Death ships with the base body only - no equipment sheets exist.
		"death":  {"frames": 11, "speed": 0.10, "loop": false,
				   "layers": [W + "Character_Death.png"]},
	}


static func _sheets(anim: String) -> Array:
	var out: Array = []
	for suffix in KIREN_LAYERS:
		out.append("%sCharacter_%s%s.png" % [W, anim, suffix])
	return out


# --- Enemies ----------------------------------------------------------
## Only "skeleton" is wired up. The others are catalogued so adding them
## later is a data edit, not a code change. Their AI is NOT implemented.
const ENEMIES := {
	"skeleton": {
		"display_name": "SKELETON",
		"max_hp": 60, "damage": 12, "move_speed": 42.0,
		"attack_range": 26.0, "attack_cooldown": 1.4,
		"sheets": "res://Assets/Enemies/Skeleton/Skeleton_%s.png",
		"idle_frames": 4, "move_frames": 6,
		"attack_anim": "", "attack_frames": 0,
		"directional": true, "foot_offset": -80.0, "scale": 1.0,
		"ranged": false,
		"windup": 0.35, "strike": 0.18, "recover": 0.30,
		"rewards": [["healing_herb", 1]],
	},
	"witch_doctor": {
		"display_name": "WITCH DOCTOR",
		"max_hp": 48, "damage": 9, "move_speed": 32.0,
		# Keeps its distance and throws instead of closing in.
		"attack_range": 84.0, "attack_cooldown": 2.0,
		"sheets": "res://Assets/Enemies/WitchDoctor/Witch_Doctor_%s.png",
		"idle_frames": 4, "move_frames": 6,
		"attack_anim": "Skill", "attack_frames": 6,
		"directional": true, "foot_offset": -80.0, "scale": 1.0,
		"ranged": true, "projectile_speed": 78.0, "keep_distance": 56.0,
		"windup": 0.55, "strike": 0.12, "recover": 0.35,
		"rewards": [["healing_herb", 2], ["steel_fragment", 1]],
	},
	"gollux": {
		"display_name": "GOLLUX",
		# Heavy archetype: slow, tanky, hits hard, long recovery.
		"max_hp": 110, "damage": 20, "move_speed": 24.0,
		"attack_range": 34.0, "attack_cooldown": 2.6,
		"sheets": "res://Assets/Enemies/Gollux/gollux_%s.png",
		"idle_frames": 5, "move_frames": 24,
		"attack_anim": "attack_A", "attack_frames": 51,
		# Single-row strip, so it faces one way and is mirrored by scale.
		"directional": false, "foot_offset": -128.0, "scale": 1.0,
		"ranged": false,
		"windup": 0.85, "strike": 0.22, "recover": 0.55,
		"rewards": [["steel_fragment", 2], ["healing_herb", 1]],
	},
	"demon_eira": {
		"display_name": "EIRA",
		"max_hp": 160, "damage": 14, "move_speed": 46.0,
		"attack_range": 30.0, "attack_cooldown": 1.5,
		# ===== PLACEHOLDER ART =====
		# Demon Eira has no sheets yet, so the Witch Doctor rig stands in,
		# tinted. To drop in the real art: point "sheets" at the new files
		# (same 128px, 4-rows-per-facing convention) and delete "tint".
		"sheets": DEMON_EIRA_SHEETS,
		"idle_frames": 4, "move_frames": 6,
		"attack_anim": "Skill", "attack_frames": 6,
		"tint": Color(0.62, 0.30, 0.58),
		"directional": true, "foot_offset": -80.0, "scale": 1.0,
		"ranged": false,
		"windup": 0.40, "strike": 0.16, "recover": 0.32,
		"rewards": [],
		# Story fight: she is never killed and never kills.
		"is_story_duel": true,
	},
	"minotaur": {
		"display_name": "MINOTAUR",
		"max_hp": 300, "damage": 22, "move_speed": 34.0,
		"attack_range": 32.0, "attack_cooldown": 2.0,
		"sheets": "res://Assets/Enemies/Minotaur/Minotaur - Sprite Sheet.png",
		# 8x15 grid whose row meaning is still unconfirmed - NOT wired up.
		"idle_frames": 0, "move_frames": 0,
		"attack_anim": "", "attack_frames": 0,
		"directional": true, "foot_offset": -80.0, "scale": 1.0,
		"ranged": false,
		"windup": 0.5, "strike": 0.2, "recover": 0.4,
		"rewards": [],
	},
}


static func enemy(id: String) -> Dictionary:
	return ENEMIES.get(id, ENEMIES["skeleton"])


## Deterministic victory rewards - no loot tables, no rolls.
static func rewards(id: String) -> Array:
	return enemy(id).get("rewards", [])
