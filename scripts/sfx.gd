extends Node

## Sound-effect hooks. Every slot is intentionally EMPTY - assign the
## files in the Inspector on this autoload once they are chosen, and the
## calls scattered through the game start making noise with no code
## changes. Unassigned slots are silent no-ops.
##
## Routed to the existing Music bus fallback logic; no new buses.

@export var sword_swing: AudioStream
@export var sword_hit: AudioStream
@export var player_hurt: AudioStream
@export var enemy_hurt: AudioStream
@export var item_pickup: AudioStream
@export var item_use: AudioStream
@export var inventory_open: AudioStream
@export var inventory_close: AudioStream
@export var victory: AudioStream
@export var defeat: AudioStream

@export var volume_db := -6.0

var _player: AudioStreamPlayer


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"
	_player.volume_db = volume_db
	add_child(_player)


func play(slot: String) -> void:
	if _player == null:
		return

	var stream: AudioStream = get(slot) if slot in self else null

	if stream == null:
		return

	_player.stream = stream
	_player.play()
