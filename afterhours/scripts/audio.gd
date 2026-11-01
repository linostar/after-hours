class_name Audio
extends Node
## The game's sound, a child of Game (Game.audio; not an autoload of its own). play(id) plays
## sound effect audio/sfx/<id>.wav (tools/sfx.py) on the SFX bus from a pool of VOICES players
## taken in turn, and logs "[Audio] SFX <id>". It runs while the tree is paused (menu sounds).

const SFX_PATH := "res://audio/sfx/%s.wav"
## Every sound effect: tools/sfx.py EFFECTS makes one file per id (a test checks both agree).
const SFX_IDS: Array[StringName] = [
	&"tiptoe", &"splash", &"pipe_burst", &"tilt", &"straighten", &"hide", &"unhide", &"brush",
	&"dab", &"stroke_done", &"grade_perfect", &"grade_good", &"grade_sloppy", &"swap", &"door",
	&"chain_rattle", &"caught", &"toss", &"land", &"guard_hear", &"guard_suspect", &"guard_alert",
	&"guard_lost", &"fake_found", &"searchlight", &"creature", &"carry", &"escape", &"star",
	&"no_star", &"ui_tap", &"toggle_on", &"toggle_off", &"pause", &"resume", &"error",
]
const SFX_BUS := &"SFX"
const VOICES := 8
## played keeps the ids of this many latest sounds (tests read it).
const LOG_SIZE := 64

## The ids of the latest sounds played, oldest first.
var played: Array[StringName] = []

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)


## Plays sound effect `id` (one of SFX_IDS) at `pitch`; an unknown or missing sound is
## reported once and plays nothing.
func play(id: StringName, pitch := 1.0) -> void:
	var stream := _stream(id)
	if stream == null:
		return
	played.append(id)
	if played.size() > LOG_SIZE:
		played.pop_front()
	print("[Audio] SFX %s%s" % [id, " x%.2f" % pitch if pitch != 1.0 else ""])
	var player := _players[_next]
	_next = (_next + 1) % VOICES
	player.stream = stream
	player.pitch_scale = pitch
	player.play()


func _stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	# Cached before any report: report_error plays the error sound, which may be the missing one.
	_streams[id] = null
	var stream: AudioStream = null
	var path := SFX_PATH % id
	var game := get_parent() as GameState
	if not id in SFX_IDS:
		game.report_error("Unknown sound effect '%s' (not in Audio.SFX_IDS)" % id)
	elif not ResourceLoader.exists(path):
		game.report_error("Sound effect '%s' is missing: %s (run python3 tools/sfx.py)" % [id, path])
	else:
		stream = load(path) as AudioStream
		if stream == null:
			game.report_error("Sound effect '%s' at %s cannot be loaded as audio" % [id, path])
	_streams[id] = stream
	return stream
