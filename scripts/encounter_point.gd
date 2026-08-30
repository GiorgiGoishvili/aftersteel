class_name EncounterPoint
extends Marker2D

## A place where a fight is meant to happen, chosen by hand.
##
## Deliberately inert for now: combat does not exist yet, so these only
## record WHERE an encounter belongs and WHICH enemy it uses. Nothing
## reads them at runtime.
##
## When combat arrives it can attach a sprite/trigger here and ask for
## "enemy_id" - no map edits needed. There is no randomness, no respawn
## timer and no roaming AI, and there never should be.

@export var encounter_id: String = ""
@export var enemy_id: String = ""

## Off until a combat system exists to switch it on.
@export var enabled: bool = false

## Whether this fight should happen only once per playthrough.
@export var one_time: bool = true


func is_cleared() -> bool:
	return one_time and GameState.has_flag("encounter_cleared_" + encounter_id)


func mark_cleared() -> void:
	if one_time:
		GameState.set_flag("encounter_cleared_" + encounter_id, true)
