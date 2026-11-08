class_name GameState
extends Node
## The one autoload (Game): the flow state, screen changes (goto: an iris wipe to the
## museum's dark, a fade under Reduce Motion, that blocks touches while it runs), the wing
## being played (run: play_wing starts one in its room 0, enter_room moves to another of its
## rooms; ROOM's scene is the run's current room), the save (progress and settings: Save, in save_path; loaded at start and
## written on every change; a corrupt one is reported, kept as backup_path() and replaced by
## defaults; SaveFile reads and writes it) and wordless error reporting. Its children do the
## rest: Audio (sound), ScreenFit (the screen fit: visible_rect, safe_rect, world_offset, the
## rotate overlay, shake and punch; Game keeps those names as delegates) and ButtonFeel (every
## button's press dip and focus ring).
## Every error goes to the log (push_error) and shows the cracked-frame ErrorBadge,
## never text (CLAUDE.md, "Errors are visible without words").

enum Flow { TITLE, ROOM, HUB, HIDEOUT, FINALE }

## Scripts reach the autoload through this path (get_node(GameState.AUTOLOAD_PATH)), never
## the bare Game name, which tool runs (--script) cannot compile against.
const AUTOLOAD_PATH := ^"/root/Game"
## Seconds to close the wipe, and again to open it, on a screen change.
const FADE_TIME := 0.25
const SAVE_PATH := "user://save.json"
## Tool runs (tests, the bot, the project check) start from defaults and write here, never
## over the player's save.
const TOOL_SAVE_PATH := "user://tool_save.json"

## A pressed button's dip (ButtonFeel).
const PRESS_SCALE := ButtonFeel.PRESS_SCALE
const PRESS_TIME := ButtonFeel.PRESS_TIME

## Emitted when a goto's fade-in has finished.
signal transition_finished(flow: Flow)
## Emitted when the visible area or its safe part changes (world_offset() with them).
signal screen_fit_changed

## The scene each flow state runs (run_main.gd checks the running scene against it).
var scene_paths: Dictionary[Flow, String] = {
	Flow.TITLE: "res://scenes/title.tscn",
	Flow.ROOM: "res://scenes/room.tscn",
	Flow.HUB: "res://scenes/hub.tscn",
	Flow.HIDEOUT: "res://scenes/hideout.tscn",
	Flow.FINALE: "res://scenes/finale.tscn",
}
var state := Flow.TITLE
## The wing being played (null before any; a room loaded on its own makes a one-room run).
var run: WingRun
## The wing (index in Content.WINGS) a first escape just unlocked, until the hub plays its
## unlock beat (-1: none).
var just_unlocked := -1
## Whether the escape just recorded was the first to finish every wing: the results' home
## then plays the finale once (leave_results) instead of going to the hub.
var ending_due := false
## Where the finale goes when it ends or is skipped (play_finale).
var finale_return := Flow.HUB
## Every error reported this run, oldest first.
var errors: Array[String] = []
## While true, report_error logs with print instead of push_error, so a test that
## provokes an error on purpose does not fail validate.sh's ERROR scan.
var quiet_errors := false
## Tests set this (base units) to stand in for a notched screen's safe area; it applies from
## the next fit_screen(). An empty rect means the display's own safe area.
var safe_area_override: Rect2:
	get:
		return screen.safe_area_override
	set(value):
		screen.safe_area_override = value
var save_path := SAVE_PATH
## The progress and settings (Save's shape).
var save := Save.defaults()
## Assist mode (a setting, off by default): the forgery canvas offers one press that paints
## the fake at exactly Good quality (Forgery.ASSIST_QUALITY), never Perfect.
var assist: bool:
	get:
		return save["settings"]["assist"]
	set(value):
		set_setting("assist", value)
## The game's sound: effects and music (arrive plays each flow's loop, music_for).
var audio: Audio
## The screen fit, the rotate overlay, shake and punch.
var screen: ScreenFit
var _transitioning := false

@onready var _error_badge: TextureRect = $ErrorLayer/ErrorBadge
@onready var _cover: ColorRect = $CoverLayer/Cover
@onready var _rotate_overlay: Control = $RotateLayer/RotateOverlay


func _ready() -> void:
	audio = Audio.new()
	audio.name = "Audio"
	add_child(audio)
	var buttons := ButtonFeel.new()
	buttons.name = "ButtonFeel"
	add_child(buttons)
	screen = ScreenFit.new()
	screen.name = "ScreenFit"
	screen.rotate_overlay = _rotate_overlay
	add_child(screen)
	screen.changed.connect(screen_fit_changed.emit)
	screen.fit_window()
	get_viewport().size_changed.connect(screen.fit)
	screen.fit()
	# Tool runs drive the tree from a SceneTree script.
	if get_tree().get_script() != null:
		save_path = TOOL_SAVE_PATH
		_apply_settings()
	else:
		load_save()


## Reads the save from save_path (defaults when there is none). A corrupt one is reported,
## moved to backup_path() and replaced by a fresh save.
func load_save() -> void:
	var problems: Array[String] = []
	save = SaveFile.read(save_path, problems)
	for problem in problems:
		report_error(problem)
	_apply_settings()
	if not problems.is_empty():
		write_save()


## Where a corrupt save is kept (one backup: the latest corrupt save replaces it).
func backup_path() -> String:
	return SaveFile.backup_path(save_path)


## Writes the save to save_path through a temporary file, so a failed write leaves the last
## good save; returns whether it worked (a failure is reported).
func write_save() -> bool:
	var problems: Array[String] = []
	var written := SaveFile.write(save_path, save, problems)
	for problem in problems:
		report_error(problem)
	return written


## Mutes the Music and SFX buses as the settings say, and makes the screen change's iris
## a plain fade under Reduce Motion (which also stops a running shake or punch).
func _apply_settings() -> void:
	for bus: String in ["Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			report_error("Audio bus '%s' is missing (default_bus_layout.tres)" % bus)
			continue
		AudioServer.set_bus_mute(index, not setting("music" if bus == "Music" else "sound"))
	(_cover.material as ShaderMaterial).set_shader_parameter("fade", setting("reduce_motion"))
	if setting("reduce_motion") and jolting():
		screen.stop_jolts()
		screen.place_world()


## Changes setting `key` (Save.SETTINGS), applies it and writes the save.
func set_setting(key: String, value: bool) -> void:
	if not Save.SETTINGS.has(key):
		report_error("Unknown setting '%s'" % key)
		return
	save["settings"][key] = value
	print("[Game] Setting %s is now %s" % [key, value])
	_apply_settings()
	write_save()


func setting(key: String) -> bool:
	return save["settings"].get(key, false)


## Records the run's escape (its stars, time and `challenges`, Challenge order) for its wing
## and writes the save when it is a best or completes a challenge for the first time; returns
## what it beat (Save.improvement) and, under "challenges", the challenges completed for the
## first time (Save.record_challenges). A first escape from a wing unlocks the next one
## (just_unlocked, for the hub's unlock beat). A run of a room loaded on its own (no wing file)
## is not recorded and beats nothing.
func record_escape(stars: Array[bool], time: float, challenges: Array[bool]) -> Dictionary:
	if run == null or run.wing.resource_path.is_empty():
		print("[Game] Escape not recorded: the run has no wing file")
		return {"stars": false, "time": false, "challenges": Challenges.none()}
	var id := Content.wing_id(run.wing.resource_path)
	var beaten := Save.improvement(save, id, stars, time)
	var first := not Save.finished(save, id)
	var all_before := all_wings_finished()
	var best := Save.record(save, id, stars, time)
	if best:
		print("[Game] New best for %s: %d star(s), %.2f s" % [id, Save.stars_of(save, id), save["wings"][id]["time"]])
	var fresh := Save.record_challenges(save, id, challenges)
	beaten["challenges"] = fresh
	if fresh.has(true):
		print("[Game] Challenges first completed for %s: %s" % [id, fresh])
	if best or fresh.has(true):
		write_save()
	var index := Content.WINGS.find(run.wing.resource_path)
	if first and index >= 0 and index + 1 < Content.WINGS.size():
		just_unlocked = index + 1
		print("[Game] Wing %d unlocked" % (just_unlocked + 1))
	if not all_before and all_wings_finished():
		ending_due = true
		print("[Game] Every wing finished: the finale is due")
	return beaten


## Whether every wing (Content.WINGS) has been escaped from (the finale is earned).
func all_wings_finished() -> bool:
	return Content.wing_ids().all(func(id: String) -> bool: return Save.finished(save, id))


## The results' home: the finale once when it is due (ending_due, then back to the hub),
## else the hub.
func leave_results() -> void:
	if ending_due:
		ending_due = false
		play_finale(Flow.HUB)
	else:
		goto(Flow.HUB)


## Plays the finale, which ends (or is skipped) at `back_to`.
func play_finale(back_to: Flow) -> void:
	finale_return = back_to
	goto(Flow.FINALE)


## Keeps the run's wing's sketch as found (Save.record_sketch) and writes the save at once, so
## leaving the wing early does not lose it. A run of a room loaded on its own is not recorded.
func record_sketch() -> void:
	if run == null or run.wing.resource_path.is_empty():
		print("[Game] Sketch not recorded: the run has no wing file")
		return
	var id := Content.wing_id(run.wing.resource_path)
	if Save.record_sketch(save, id):
		print("[Game] Sketch found for %s" % id)
		write_save()


## The visible area in base units: 960x540, or larger on one axis (aspect expand).
func visible_rect() -> Rect2:
	return screen.visible_rect()


## The part of the visible area clear of notches and rounded corners, in base units.
func safe_rect() -> Rect2:
	return screen.safe_rect()


## Where the 960x540 base sits on screen (ScreenFit.world_offset).
func world_offset() -> Vector2:
	return screen.world_offset()


func is_rotate_overlay_shown() -> bool:
	return screen.is_rotate_overlay_shown()


## Measures the visible area and its safe part again (on every viewport resize), moves the
## world to world_offset() and shows or hides the rotate overlay.
func fit_screen() -> void:
	screen.fit()


## Shakes the world `strength` base units about, easing to rest over `seconds`; nothing
## under Reduce Motion.
func shake(strength: float, seconds: float) -> void:
	if not setting("reduce_motion"):
		screen.shake(strength, seconds)


## Zooms the world in by `zoom` (0.04 is 4 %) about its centre, easing back over `seconds`;
## nothing under Reduce Motion.
func punch(zoom: float, seconds: float) -> void:
	if not setting("reduce_motion"):
		screen.punch(zoom, seconds)


## Whether Reduce Motion is on, for a node that has no Game handle (a rig, a gimmick, a
## decoration); a node outside the tree (a test's loose one) moves.
static func reduce_motion_for(node: Node) -> bool:
	if not node.is_inside_tree():
		return false
	var game := node.get_node_or_null(AUTOLOAD_PATH) as GameState
	return game != null and game.setting("reduce_motion")


## Whether a shake or a punch is moving the world.
func jolting() -> bool:
	return screen.jolting()


## Changes to `flow`'s scene behind a wipe: an iris closing to the museum's dark and opening
## again (a fade under Reduce Motion; touches are blocked until it has opened).
## Ignored while another change runs; a missing scene is reported and nothing changes.
func goto(flow: Flow) -> void:
	var to_name: String = Flow.keys()[flow]
	var path := scene_paths[flow]
	if _transitioning:
		print("[Game] Ignored goto %s while a transition is running" % to_name)
		return
	if not ResourceLoader.exists(path):
		report_error("Cannot go to %s: scene '%s' does not exist" % [to_name, path])
		return
	_transitioning = true
	screen.stop_jolts()
	print("[Game] %s -> %s (%s)" % [Flow.keys()[state], to_name, path])
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		# The new scene enters the tree (and runs its _ready) at the end of this frame.
		await get_tree().scene_changed
		# A change from the pause menu leaves its pause behind; under the rotate overlay the
		# tree stays paused until landscape.
		if screen.is_rotate_overlay_shown():
			screen.paused_by_rotate = true
		else:
			get_tree().paused = false
	else:
		report_error("Failed to load scene '%s' for %s: %s" % [path, to_name, error_string(error)])
	await _fade(0.0)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	if error == OK:
		transition_finished.emit(flow)


## Loads the wing at `path` (a Content.WINGS entry) and plays it; a wing whose data is
## broken is reported and not played. Returns whether it plays.
func play_wing_file(path: String) -> bool:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	for problem in problems:
		report_error("Wing data: " + problem)
	if wing == null:
		return false
	play_wing(wing)
	return true


## Starts `wing` afresh in its room 0. Ignored while a screen change runs.
func play_wing(wing: WingData) -> void:
	if _transitioning:
		print("[Game] Ignored play_wing while a transition is running")
		return
	run = WingRun.new(wing)
	scene_paths[Flow.ROOM] = wing.rooms[0]
	print("[Game] Playing the %s wing" % wing.painting)
	goto(Flow.ROOM)


## Replays the playtest bot's run of the wing at `path` (the hideout's replay): the ghost
## mime walks its rooms in the bot's order, alone (Room in WingRun.replaying), and the replay
## ends back in the hideout. A broken wing is reported and not replayed; ignored while a
## screen change runs.
func replay_ghost(path: String) -> void:
	if _transitioning:
		print("[Game] Ignored replay_ghost while a transition is running")
		return
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	for problem in problems:
		report_error("Wing data: " + problem)
	if wing == null:
		return
	run = WingRun.new(wing)
	run.replaying = true
	scene_paths[Flow.ROOM] = wing.rooms[0]
	print("[Game] Replaying the bot's run of the %s wing" % wing.painting)
	goto(Flow.ROOM)


## Moves the run to its room `index`, coming from the room it is in. Ignored while a screen
## change runs.
func enter_room(index: int) -> void:
	if _transitioning:
		print("[Game] Ignored enter_room %d while a transition is running" % index)
		return
	run.came_from = run.room
	run.room = index
	scene_paths[Flow.ROOM] = run.wing.rooms[index]
	goto(Flow.ROOM)


## Plays the run's wing again from its start (the results' replay).
func replay() -> void:
	if run == null:
		goto(Flow.ROOM)
	else:
		play_wing(run.wing)


func is_transitioning() -> bool:
	return _transitioning


func _fade(alpha: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cover, "color:a", alpha, FADE_TIME)
	await tween.finished


## Called by each flow state's scene once it is ready.
func arrive(flow: Flow) -> void:
	state = flow
	screen.centred = flow != Flow.TITLE
	screen.place_world()
	audio.play_music(music_for(flow))
	print("[Game] Arrived at %s (%s)" % [Flow.keys()[flow], scene_paths[flow]])


## The loop of `flow`: in a wing's rooms its era's (wing_NN by its painting's place in
## Paintings.IDS, the wings' order), the results' fanfare in the finale, the caper everywhere
## else.
func music_for(flow: Flow) -> String:
	if flow == Flow.ROOM and run != null:
		return "wing_%02d" % (Paintings.IDS.find(StringName(run.wing.painting)) + 1)
	if flow == Flow.FINALE:
		return "results"
	return "caper"


func report_error(message: String) -> void:
	errors.append(message)
	if quiet_errors:
		print("[Game] Error (quiet): " + message)
	else:
		push_error(message)
		audio.play(&"error")
	_error_badge.visible = true


func error_badge_visible() -> bool:
	return _error_badge.visible
