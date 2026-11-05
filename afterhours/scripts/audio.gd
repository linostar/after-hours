class_name Audio
extends Node
## The game's sound, a child of Game (Game.audio; not an autoload of its own). play(id) plays
## sound effect audio/sfx/<id>.wav (tools/sfx.py) on the SFX bus from a pool of VOICES players
## taken in turn, and logs "[Audio] SFX <id>". It runs while the tree is paused (menu sounds).
## Every button in the tree sounds when used: a toggle its on or off tick, any other the tap.
## play_music(track) crossfades to loop audio/music/<track>.mp3 (tools/music.py) on the Music
## bus over CROSSFADE and logs "[Audio] Music <track>"; the same track again changes nothing.
## say(voice, event) speaks a guard's line (audio/voice/<voice>_<event>_<n>.mp3, tools/voices.py),
## its LINES_PER_EVENT lines in turn, on one voice player: an URGENT event cuts in, any other
## waits for silence (skipped). Speech never carries what the player needs: each line comes
## with its event's icon and sound.

const SFX_PATH := "res://audio/sfx/%s.wav"
## Every sound effect: tools/sfx.py EFFECTS makes one file per id (a test checks both agree).
const SFX_IDS: Array[StringName] = [
	&"tiptoe", &"splash", &"pipe_burst", &"tilt", &"straighten", &"hide", &"unhide", &"brush",
	&"dab", &"stroke_done", &"grade_perfect", &"grade_good", &"grade_sloppy", &"swap", &"door",
	&"chain_rattle", &"chains_fall", &"caught", &"toss", &"splat", &"dust_hands", &"guard_hear", &"guard_suspect", &"guard_alert",
	&"guard_lost", &"fake_found", &"searchlight", &"escape", &"shrug", &"mime_gag", &"confetti", &"new_best", &"star",
	&"no_star", &"ui_tap", &"toggle_on", &"toggle_off", &"pause", &"resume", &"error", &"sketch_drop", &"sketch_found",
	&"ball_throw", &"ball_land", &"rope_pull", &"box_up", &"power_unlock",
]
const SFX_BUS := &"SFX"
const MUSIC_PATH := "res://audio/music/%s.mp3"
## Every loop: tools/music.py TRACKS makes one file per track (a test checks both agree).
const MUSIC_TRACKS: Array[String] = ["caper", "wing_01", "wing_02", "wing_03", "wing_04", "wing_05", "wing_06", "results"]
const MUSIC_BUS := &"Music"
const CROSSFADE := 1.0
const VOICE_PATH := "res://audio/voice/%s_%s_%d.mp3"
## The guards' voices (tools/voices.json "voices") and the events they speak on ("events").
const GUARD_VOICES: Array[StringName] = [&"watchman", &"rookie"]
const VOICE_EVENTS: Array[StringName] = [&"hear", &"straighten", &"inspect", &"search", &"chase", &"lost", &"found_fake", &"caught"]
const LINES_PER_EVENT := 2
## Events whose line cuts off one being spoken.
const URGENT: Array[StringName] = [&"chase", &"found_fake", &"caught"]
## The audio driver of headless runs: sounds are only logged there (unless --write-movie
## records them: the movie writer mixes through the same driver).
const SILENT_DRIVER := "Dummy"
const VOICES := 8
## played keeps the ids of this many latest sounds (tests read it).
const LOG_SIZE := 64

## The ids of the latest sounds played, oldest first.
var played: Array[StringName] = []
## The loop playing (or fading in), "" before the first.
var music := ""
## The latest line ids spoken, oldest first (LOG_SIZE at most; tests read it).
var said: Array[StringName] = []

var _streams: Dictionary[StringName, AudioStream] = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music_players: Array[AudioStreamPlayer] = []
var _music_current := 0
var _fade: Tween
var _voice: AudioStreamPlayer
## How many times each voice has spoken each event ("<voice>_<event>": count).
var _spoken: Dictionary[StringName, int] = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.name = "Sfx%d" % i
		player.bus = SFX_BUS
		add_child(player)
		_players.append(player)
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % i
		player.bus = MUSIC_BUS
		add_child(player)
		_music_players.append(player)
	_voice = AudioStreamPlayer.new()
	_voice.name = "Voice"
	_voice.bus = SFX_BUS
	add_child(_voice)
	get_tree().node_added.connect(_on_node_added)


## At quit every player stops and lets go of its stream: a stream still playing when the
## autoload is torn down leaks its playback (seen quitting mid-room in the step 10 playtest).
func _exit_tree() -> void:
	if _fade != null:
		_fade.kill()
	for player: AudioStreamPlayer in _players + _music_players + [_voice]:
		player.stop()
		player.stream = null


## Whether sounds are heard: not on the Dummy driver, except while --write-movie records.
static func mixing() -> bool:
	return AudioServer.get_driver_name() != SILENT_DRIVER or not Engine.get_write_movie_path().is_empty()


## Plays sound `id` for `node` (Game.audio.play); a node outside the tree (a test's loose
## gimmick) is not in the game and makes no sound.
static func play_for(node: Node, id: StringName, pitch := 1.0) -> void:
	if node.is_inside_tree():
		(node.get_node(GameState.AUTOLOAD_PATH) as GameState).audio.play(id, pitch)


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
	# The Dummy driver (headless runs) never mixes, so a started sound would never finish.
	if mixing():
		player.play()


## Crossfades to loop `track` (one of MUSIC_TRACKS); an unknown or missing loop is reported
## once and the music goes on as it was.
func play_music(track: String) -> void:
	if track == music:
		return
	var stream: AudioStream = null
	if not track in MUSIC_TRACKS:
		(get_parent() as GameState).report_error("Unknown music track '%s' (not in Audio.MUSIC_TRACKS)" % track)
	else:
		stream = _load(StringName(track), MUSIC_PATH % track, "Music track", "music")
	if stream == null:
		return
	print("[Audio] Music %s (%s)" % [track, "from %s" % music if music != "" else "first loop"])
	music = track
	if _fade != null:
		_fade.kill()
	var old := _music_players[_music_current]
	_music_current = 1 - _music_current
	var player := _music_players[_music_current]
	player.stream = stream
	player.volume_linear = 0.0
	if mixing():
		player.play()
	_fade = create_tween().set_parallel()
	_fade.tween_property(player, "volume_linear", 1.0, CROSSFADE)
	_fade.tween_property(old, "volume_linear", 0.0, CROSSFADE)
	_fade.chain().tween_callback(old.stop)


## Speaks `voice`'s next line for `event` (GUARD_VOICES, VOICE_EVENTS); an unknown voice or
## event, or a missing line, is reported once.
func say(voice: StringName, event: StringName) -> void:
	var game := get_parent() as GameState
	if not voice in GUARD_VOICES or not event in VOICE_EVENTS:
		game.report_error("Unknown guard voice '%s' or event '%s' (Audio.GUARD_VOICES, Audio.VOICE_EVENTS)" % [voice, event])
		return
	if _voice.playing and not event in URGENT:
		return
	var key := StringName("%s_%s" % [voice, event])
	var count: int = _spoken.get(key, 0)
	var line := count % LINES_PER_EVENT + 1
	_spoken[key] = count + 1
	var id := StringName("%s_%d" % [key, line])
	var stream := _load(id, VOICE_PATH % [voice, event, line], "Voice line", "voices")
	if stream == null:
		return
	said.append(id)
	if said.size() > LOG_SIZE:
		said.pop_front()
	print("[Audio] Voice %s" % id)
	_voice.stream = stream
	if mixing():
		_voice.play()


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null:
		return
	if button.toggle_mode:
		button.toggled.connect(func(on: bool) -> void: play(&"toggle_on" if on else &"toggle_off"))
	else:
		button.pressed.connect(play.bind(&"ui_tap"))


func _stream(id: StringName) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	if not id in SFX_IDS:
		_streams[id] = null
		(get_parent() as GameState).report_error("Unknown sound effect '%s' (not in Audio.SFX_IDS)" % id)
		return null
	return _load(id, SFX_PATH % id, "Sound effect", "sfx")


## The stream at `path` under key `id`, loaded once; a missing or unloadable one is reported
## once (`what` names it, `tool` the tools/<tool>.py that makes it) and is null.
func _load(id: StringName, path: String, what: String, tool: String) -> AudioStream:
	if _streams.has(id):
		return _streams[id]
	# Cached before any report: report_error plays the error sound, which may be the missing one.
	_streams[id] = null
	var stream: AudioStream = null
	var game := get_parent() as GameState
	if not ResourceLoader.exists(path):
		game.report_error("%s '%s' is missing: %s (run python3 tools/%s.py)" % [what, id, path, tool])
	else:
		stream = load(path) as AudioStream
		if stream == null:
			game.report_error("%s '%s' at %s cannot be loaded as audio" % [what, id, path])
	_streams[id] = stream
	return stream
