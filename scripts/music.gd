extends Node

## Small global music player.
##
## One AudioStreamPlayer that lives on an autoload, so walking between the
## bedroom, the house and the village never restarts the track underneath.
##
##     Music.play("casual")      start immediately
##     Music.fade_to("casual")   fade the old track out, fade this one in
##     Music.fade_out()          fade down and stop
##     Music.stop()              stop immediately
##
## Asking for the track that is already playing does nothing at all, which
## is what keeps the playhead intact across scene changes.

# Default fade lengths in seconds. Callers can override per call.
const FADE_OUT_TIME := 1.2
const FADE_IN_TIME := 1.5

# Quiet enough to be inaudible; -80 is Godot's true silence.
const SILENT_DB := -60.0

## All tuning lives here: swap a file, change a volume, toggle a loop.
const TRACKS := {
	"menu": {
		"stream": preload("res://Assets/Audio/Music/MenuMusic.mp3"),
		"volume_db": -10.0,
		"loop": true,
	},
	"intro": {
		"stream": preload("res://Assets/Audio/Music/IntroTheme.mp3"),
		"volume_db": -9.0,
		"loop": false,
	},
	"casual": {
		"stream": preload("res://Assets/Audio/Music/Casual.mp3"),
		"volume_db": -14.0,
		"loop": true,
	},
}

var _player: AudioStreamPlayer
var _current := ""
var _tween: Tween


func _ready() -> void:
	_player = AudioStreamPlayer.new()
	_player.name = "MusicPlayer"

	# Falls back to Master if the Music bus is ever missing, so a broken
	# bus layout cannot silence the game.
	_player.bus = "Music" if AudioServer.get_bus_index("Music") != -1 else "Master"

	add_child(_player)

	# The .mp3 files import with loop = false, so looping is applied here
	# instead of changing the import settings of the source files.
	for id in TRACKS:
		TRACKS[id]["stream"].loop = TRACKS[id]["loop"]


func current_track() -> String:
	return _current


func is_playing() -> bool:
	return _player != null and _player.playing


## Starts a track at full volume. No-op if it is already playing.
func play(id: String) -> void:
	if not TRACKS.has(id):
		push_warning("Music.play: unknown track '%s'" % id)
		return

	if id == _current and _player.playing:
		return

	_kill_tween()

	_player.stream = TRACKS[id]["stream"]
	_player.volume_db = TRACKS[id]["volume_db"]
	_player.play()
	_current = id


## Fades whatever is playing down, swaps track, fades the new one up.
## No-op if the requested track is already playing.
func fade_to(id: String, fade_out_time := FADE_OUT_TIME, fade_in_time := FADE_IN_TIME) -> void:
	if not TRACKS.has(id):
		push_warning("Music.fade_to: unknown track '%s'" % id)
		return

	if id == _current and _player.playing:
		return

	_kill_tween()
	_tween = create_tween()

	# Nothing playing yet means there is nothing to fade out.
	if _player.playing:
		_tween.tween_property(_player, "volume_db", SILENT_DB, fade_out_time)

	_tween.tween_callback(_swap_to.bind(id))
	_tween.tween_property(
		_player,
		"volume_db",
		TRACKS[id]["volume_db"],
		fade_in_time
	)


func fade_out(fade_out_time := FADE_OUT_TIME) -> void:
	if not _player.playing:
		return

	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", SILENT_DB, fade_out_time)
	_tween.tween_callback(stop)


func stop() -> void:
	_kill_tween()
	_player.stop()
	_current = ""


func _swap_to(id: String) -> void:
	_player.stream = TRACKS[id]["stream"]
	_player.volume_db = SILENT_DB
	_player.play()
	_current = id


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()

	_tween = null
