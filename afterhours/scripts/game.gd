class_name GameState
extends Node
## The one autoload (Game): the flow state, screen changes (goto: an iris wipe to the
## museum's dark, a fade under Reduce Motion, that blocks touches while it runs), the wing
## being played (run: play_wing starts one in its room 0, enter_room moves to another of its
## rooms; ROOM's scene is the run's current room), the save (progress and settings: Save, in save_path; loaded at start and
## written on every change; a corrupt one is reported, kept as backup_path() and replaced by
## defaults), the screen fit (visible_rect, safe_rect; the museum's worlds, laid out on the
## 960x540 base, are centred on the safe area through the canvas transform; a portrait screen
## shows the wordless rotate overlay and pauses the tree) and wordless error reporting.
## Every error goes to the log (push_error) and shows the cracked-frame ErrorBadge,
## never text (CLAUDE.md, "Errors are visible without words").

enum Flow { TITLE, ROOM, HUB, HIDEOUT }

## Scripts reach the autoload through this path (get_node(GameState.AUTOLOAD_PATH)), never
## the bare Game name, which tool runs (--script) cannot compile against.
const AUTOLOAD_PATH := ^"/root/Game"
## Seconds to close the wipe, and again to open it, on a screen change.
const FADE_TIME := 0.25
## A desktop window opens at this share of the usable screen, kept 16:9 (the 960x540 base
## is tiny on a high-DPI screen, where window sizes count physical pixels).
const WINDOW_SCREEN_SHARE := 0.85
const SAVE_PATH := "user://save.json"
## Tool runs (tests, the bot, the project check) start from defaults and write here, never
## over the player's save.
const TOOL_SAVE_PATH := "user://tool_save.json"

## A pressed button dips to this scale and springs back over PRESS_TIME.
const PRESS_SCALE := 0.9
const PRESS_TIME := 0.14

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
}
var state := Flow.TITLE
## The wing being played (null before any; a room loaded on its own makes a one-room run).
var run: WingRun
## Every error reported this run, oldest first.
var errors: Array[String] = []
## While true, report_error logs with print instead of push_error, so a test that
## provokes an error on purpose does not fail validate.sh's ERROR scan.
var quiet_errors := false
## Tests set this (base units) to stand in for a notched screen's safe area; it applies from
## the next fit_screen(). An empty rect means the display's own safe area.
var safe_area_override := Rect2()
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
var _transitioning := false
var _visible_rect := Rect2()
var _safe_rect := Rect2()
## Whether the rotate overlay paused the tree (it then unpauses on hiding).
var _paused_by_rotate := false
## The running screen shake (strength in base units) and camera punch (extra zoom), each
## easing to rest over its time (shake, punch).
var _shake_strength := 0.0
var _shake_time := 0.0
var _shake_left := 0.0
var _punch_zoom := 0.0
var _punch_time := 0.0
var _punch_left := 0.0

@onready var _error_badge: TextureRect = $ErrorLayer/ErrorBadge
@onready var _cover: ColorRect = $CoverLayer/Cover
@onready var _rotate_overlay: Control = $RotateLayer/RotateOverlay


func _ready() -> void:
	audio = Audio.new()
	audio.name = "Audio"
	add_child(audio)
	get_tree().node_added.connect(_on_node_added)
	_fit_window()
	get_viewport().size_changed.connect(fit_screen)
	fit_screen()
	# Tool runs drive the tree from a SceneTree script.
	if get_tree().get_script() != null:
		save_path = TOOL_SAVE_PATH
		_apply_settings()
	else:
		load_save()


## Reads the save from save_path (defaults when there is none). A corrupt one is reported,
## moved to backup_path() and replaced by a fresh save.
func load_save() -> void:
	save = Save.defaults()
	if not FileAccess.file_exists(save_path):
		print("[Game] No save at %s; starting fresh" % save_path)
		_apply_settings()
		return
	var problems: Array[String] = []
	var loaded := Save.parse(FileAccess.get_file_as_string(save_path), problems)
	if loaded.is_empty():
		var moved := DirAccess.rename_absolute(save_path, backup_path())
		report_error("Save '%s' is corrupt (%s); %s, and a fresh save replaces it" % [save_path, "; ".join(problems), "it was moved to '%s'" % backup_path() if moved == OK else "it could not be moved to '%s' (%s)" % [backup_path(), error_string(moved)]])
		_apply_settings()
		write_save()
		return
	save = loaded
	print("[Game] Loaded the save from %s: %d wing(s) finished, settings %s" % [save_path, save["wings"].size(), save["settings"]])
	_apply_settings()


## Where a corrupt save is kept (one backup: the latest corrupt save replaces it).
func backup_path() -> String:
	return save_path.get_basename() + ".corrupt.json"


## Writes the save to save_path through a temporary file, so a failed write leaves the last
## good save; returns whether it worked (a failure is reported).
func write_save() -> bool:
	var temp := save_path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		report_error("Cannot open '%s' to write the save: %s; '%s' is unchanged" % [temp, error_string(FileAccess.get_open_error()), save_path])
		return false
	var written := file.store_string(Save.to_json(save))
	file.close()
	var replaced := DirAccess.rename_absolute(temp, save_path) if written else FAILED
	if replaced != OK:
		DirAccess.remove_absolute(temp)
		report_error("Cannot write the save to '%s' (%s); it is unchanged" % [save_path, error_string(replaced)])
		return false
	print("[Game] Saved to %s: %d wing(s) finished, settings %s" % [save_path, save["wings"].size(), save["settings"]])
	return true


## Mutes the Music and SFX buses as the settings say, and makes the screen change's iris
## a plain fade under Reduce Motion.
func _apply_settings() -> void:
	for bus: String in ["Music", "SFX"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			report_error("Audio bus '%s' is missing (default_bus_layout.tres)" % bus)
			continue
		AudioServer.set_bus_mute(index, not setting("music" if bus == "Music" else "sound"))
	(_cover.material as ShaderMaterial).set_shader_parameter("fade", setting("reduce_motion"))


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


## Records the run's escape (its stars and time) for its wing and writes the save when it
## is a best. A run of a room loaded on its own (no wing file) is not recorded.
func record_escape(stars: Array[bool], time: float) -> void:
	if run == null or run.wing.resource_path.is_empty():
		print("[Game] Escape not recorded: the run has no wing file")
		return
	var id := Content.wing_id(run.wing.resource_path)
	if Save.record(save, id, stars, time):
		print("[Game] New best for %s: %d star(s), %.2f s" % [id, Save.stars_of(save, id), save["wings"][id]["time"]])
		write_save()


## Grows the desktop window to WINDOW_SCREEN_SHARE of the usable screen at 16:9 and centres
## it. The web canvas fills its page and headless runs have no screen, so both are skipped.
func _fit_window() -> void:
	if OS.has_feature("web") or DisplayServer.get_name() == "headless":
		return
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var base := Vector2(window.content_scale_size)
	var scale := minf(usable.size.x / base.x, usable.size.y / base.y) * WINDOW_SCREEN_SHARE
	window.size = Vector2i(base * scale)
	window.position = usable.position + Vector2i(Vector2(usable.size - window.size) / 2.0)
	print("[Game] Window %s on a usable screen of %s" % [window.size, usable.size])


## The visible area in base units: 960x540, or larger on one axis (aspect expand).
func visible_rect() -> Rect2:
	return _visible_rect


## The part of the visible area clear of notches and rounded corners, in base units.
func safe_rect() -> Rect2:
	return _safe_rect


## Where the 960x540 base sits on screen: centred on the safe area (whole units), but kept
## inside the visible area, so a safe area shorter than the base (a phone's home-indicator
## inset) never crops the world.
func world_offset() -> Vector2:
	var centred := (_safe_rect.get_center() - Content.BASE / 2.0).round()
	return centred.clamp(_visible_rect.position, (_visible_rect.end - Content.BASE).max(_visible_rect.position))


## Converts the screen-pixel safe area to base units and clips it to `visible`. An empty
## safe area (headless, some browsers) means the whole visible rect.
static func safe_rect_in(visible: Rect2, safe_pixels: Rect2i, window_position: Vector2i, stretch: Transform2D) -> Rect2:
	if safe_pixels.size.x <= 0 or safe_pixels.size.y <= 0:
		return visible
	var local := Rect2(Vector2(safe_pixels.position - window_position), Vector2(safe_pixels.size))
	var clipped := (stretch.affine_inverse() * local).intersection(visible)
	return clipped if clipped.has_area() else visible


## Whether a visible area of `area` needs the rotate overlay: taller than wide.
static func is_portrait(area: Vector2) -> bool:
	return area.y > area.x


func is_rotate_overlay_shown() -> bool:
	return _rotate_overlay.visible


## Measures the visible area and its safe part again (on every viewport resize), moves the
## world to world_offset() and shows or hides the rotate overlay.
func fit_screen() -> void:
	var window := get_window()
	var visible := get_viewport().get_visible_rect()
	var safe := safe_area_override if safe_area_override.has_area() else safe_rect_in(visible, DisplayServer.get_display_safe_area(), window.position, window.get_final_transform())
	if visible.is_equal_approx(_visible_rect) and safe.is_equal_approx(_safe_rect):
		return
	_visible_rect = visible
	_safe_rect = safe
	print("[Game] Screen fit: visible %s, safe %s, world at %s" % [visible, safe, world_offset()])
	_place_world()
	_update_rotate_overlay()
	screen_fit_changed.emit()


## The museum's worlds (every flow but the title, a Control that fills the screen) are
## drawn at world_offset(); the title at the origin. A running shake moves it about and a
## punch zooms it about the world's centre.
func _place_world() -> void:
	var offset := world_offset() if state != Flow.TITLE else Vector2.ZERO
	var zoom := 1.0
	if _punch_left > 0.0:
		zoom += _punch_zoom * _punch_left / _punch_time
	if _shake_left > 0.0:
		# Fixed waves, not random: runs stay repeatable.
		var t := _shake_time - _shake_left
		offset += Vector2(sin(t * 53.0), cos(t * 41.0)) * _shake_strength * _shake_left / _shake_time
	var centre := Content.BASE / 2.0
	get_viewport().canvas_transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, offset + centre * (1.0 - zoom))


## Shakes the world `strength` base units about, easing to rest over `seconds`; nothing
## under Reduce Motion.
func shake(strength: float, seconds: float) -> void:
	if setting("reduce_motion"):
		return
	_shake_strength = strength
	_shake_time = seconds
	_shake_left = seconds


## Zooms the world in by `zoom` (0.04 is 4 %) about its centre, easing back over `seconds`;
## nothing under Reduce Motion.
func punch(zoom: float, seconds: float) -> void:
	if setting("reduce_motion"):
		return
	_punch_zoom = zoom
	_punch_time = seconds
	_punch_left = seconds


## Whether a shake or a punch is moving the world.
func jolting() -> bool:
	return _shake_left > 0.0 or _punch_left > 0.0


func _process(delta: float) -> void:
	if not jolting():
		return
	_shake_left = maxf(_shake_left - delta, 0.0)
	_punch_left = maxf(_punch_left - delta, 0.0)
	_place_world()


## Every button dips when pressed (touch, click or key), whatever screen it is on.
func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		button.button_down.connect(_press.bind(button))


func _press(button: BaseButton) -> void:
	button.pivot_offset = button.size / 2.0
	# A press that pauses the tree (the pause button) still springs back.
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_TIME / 2.0)
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_TIME / 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Shows the rotate overlay and pauses the tree while the visible area is portrait; hides
## it and restores the pause state when it is landscape again.
func _update_rotate_overlay() -> void:
	var portrait := is_portrait(_visible_rect.size)
	if portrait == _rotate_overlay.visible:
		return
	var tree := get_tree()
	if portrait:
		_paused_by_rotate = not tree.paused
		tree.paused = true
		_rotate_overlay.show()
		# Keys must not press a focused button hidden behind the overlay.
		get_viewport().gui_disable_input = true
		print("[Game] Rotate overlay shown (visible %s); tree paused" % _visible_rect.size)
	else:
		_rotate_overlay.hide()
		get_viewport().gui_disable_input = false
		if _paused_by_rotate:
			tree.paused = false
		print("[Game] Rotate overlay hidden (visible %s); tree %s" % [_visible_rect.size, "unpaused" if _paused_by_rotate else "stays paused"])
		_paused_by_rotate = false


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
	_shake_left = 0.0
	_punch_left = 0.0
	print("[Game] %s -> %s (%s)" % [Flow.keys()[state], to_name, path])
	_cover.mouse_filter = Control.MOUSE_FILTER_STOP
	await _fade(1.0)
	var error := get_tree().change_scene_to_file(path)
	if error == OK:
		# The new scene enters the tree (and runs its _ready) at the end of this frame.
		await get_tree().scene_changed
		# A change from the pause menu leaves its pause behind; under the rotate overlay the
		# tree stays paused until landscape.
		if _rotate_overlay.visible:
			_paused_by_rotate = true
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
	_place_world()
	audio.play_music(music_for(flow))
	print("[Game] Arrived at %s (%s)" % [Flow.keys()[flow], scene_paths[flow]])


## The loop of `flow`: in a wing's rooms its era's (wing_NN by its painting's place in
## Paintings.IDS, the wings' order), the caper everywhere else.
func music_for(flow: Flow) -> String:
	if flow == Flow.ROOM and run != null:
		return "wing_%02d" % (Paintings.IDS.find(StringName(run.wing.painting)) + 1)
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
