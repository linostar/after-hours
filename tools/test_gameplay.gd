extends SceneTree
## Headless gameplay tests. Run with --fixed-fps 60 so one frame = one physics tick:
##   "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/test_gameplay.gd"
## Prints "test_gameplay: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Tests run in that order on one SceneTree, so
## each one restores whatever it changes (Game.quiet_errors, Game.errors, the badge).

const TITLE_PATH := "res://scenes/title.tscn"
const ROOM_PATH := "res://scenes/room.tscn"
const HUB_PATH := "res://scenes/hub.tscn"
const CANVAS_PATH := "res://scenes/forgery_canvas.tscn"
## Every synthetic touch uses this index: a web build's index is the browser's
## Touch.identifier, which iOS Safari makes large and never 0.
const TOUCH_INDEX := 7
## The slice room's partition footprint (room coordinates), which the mime never enters.
const PARTITION_FOOTPRINT := Rect2(400, 300, 160, 60)
## The walkable floor's top edge (the back wall's foot) in the slice room's navmesh.
const FLOOR_TOP := 180.0
const EXPORT_PRESETS_PATH := "res://export_presets.cfg"
const BASE_WINDOW := Vector2i(960, 540)
## The CSS html/head_include must set so the browser never pulls to refresh, zooms on a
## double tap, selects text or opens a long-press menu.
const TOUCH_CSS: Array[String] = ["touch-action: none", "overscroll-behavior: none", "user-select: none", "-webkit-user-select: none", "-webkit-touch-callout: none"]
## The GDScript warnings project.godot raises to errors (level 2): with them, any warning
## fails the strict compile in check_project.gd.
const STRICT_WARNINGS: Array[String] = [
	"unassigned_variable", "unassigned_variable_op_assign", "unused_variable", "unused_local_constant",
	"unused_private_class_variable", "unused_parameter", "unused_signal", "shadowed_variable",
	"shadowed_variable_base_class", "shadowed_global_identifier", "unreachable_code", "unreachable_pattern",
	"standalone_expression", "standalone_ternary", "incompatible_ternary", "untyped_declaration",
	"unsafe_void_return", "static_called_on_instance", "missing_tool", "redundant_static_unload",
	"redundant_await", "assert_always_true", "assert_always_false", "integer_division", "narrowing_conversion",
	"int_as_enum_without_cast", "int_as_enum_without_match", "enum_variable_without_default", "empty_file",
	"deprecated_keyword", "confusable_identifier", "confusable_local_declaration", "confusable_local_usage",
	"confusable_capture_reassignment", "confusable_temporary_modification", "property_used_as_function",
	"constant_used_as_function", "function_used_as_property",
]
## Real-time limit for the whole run; a test stuck on an await fails instead of hanging.
const WATCHDOG_MSEC := 60000

var _game: GameState
var _failures: Array[String] = []
var _checks := 0
var _deadline_msec := 0


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_MSEC
	_game = root.get_node_or_null("Game") as GameState
	if _game == null:
		printerr("test_gameplay: FAILED: Game autoload not found")
		quit(1)
		return
	_run.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		# The checks that failed before the stuck test (it may hang because of one of them).
		for failure in _failures:
			printerr("test_gameplay: FAIL " + failure)
		printerr("test_gameplay: FAILED watchdog: tests did not finish within %d ms" % WATCHDOG_MSEC)
		quit(1)
	return false


## A gimmick whose light, slowing and loudness the tests set (the same everywhere), and
## which counts its ticks.
class TestGimmick extends Gimmick:
	var light := 1.0
	var slow := 1.0
	var noise := 0.0
	var ticks := 0
	## A clue to show the next guard that asks, once.
	var clue := Vector2.INF

	func light_at(_point: Vector2) -> float:
		return light

	func slow_at(_point: Vector2) -> float:
		return slow

	func noise_at(_point: Vector2) -> float:
		return noise

	func noise_sound(_point: Vector2) -> StringName:
		return &"splash"

	func clue_seen_by(_guard: Guard) -> Vector2:
		var shown := clue
		clue = Vector2.INF
		return shown

	func tick(_delta: float) -> void:
		ticks += 1


func _tests() -> Array[Callable]:
	return [
		_test_project_display_and_input,
		_test_project_strict_warnings,
		_test_web_export_preset,
		_test_title_arrives,
		_test_report_error_shows_badge,
		_test_sfx_files,
		_test_sfx_on_actions,
		_test_guards_take_voices,
		_test_keyboard_steps_sound,
		_test_detection_cone,
		_test_detection_suspicion,
		_test_detection_light,
		_test_stars,
		_test_save_shape,
		_test_save_load_write_and_corrupt,
		_test_guard_brain_priorities,
		_test_guard_brain_chase_and_noise,
		_test_forgery_scoring,
		_test_forgery_grades,
		_test_paintings_registry,
		_test_canvas_traces_and_grades,
		_test_canvas_close_keeps_strokes,
		_test_canvas_assist_paints_good,
		_test_room_tap_walks_around_partition,
		_test_room_tap_on_wall_stops_at_floor,
		_test_guard_patrols,
		_test_guard_sees_and_tosses,
		_test_glimpse_keeps_unseen_star,
		_test_guard_partition_blocks_sight,
		_test_guard_ignores_behind,
		_test_guard_chase_search_return,
		_test_tilt_decoy_investigated,
		_test_tilted_frame_seen_and_straightened,
		_test_decoy_pulls_nearest_guard,
		_test_hiding_checks_every_guard,
		_test_second_guard_catches_and_resets_all,
		_test_fake_found_out_by_one_guard,
		_test_hide_unseen_and_step_out,
		_test_hide_view_fills_screen,
		_test_hide_unknown_painting_reports,
		_test_guard_saw_hiding_pulls_out,
		_test_guard_loses_mime_after_hiding,
		_test_guard_ignores_unseen_hiding,
		_test_investigate_without_frame,
		_test_close_noise_straighten_takes_time,
		_test_guard_returns_to_reached_goals,
		_test_off_mesh_noise_and_chase_repath,
		_test_intent_icons_and_overlay,
		_test_keyboard_walks_and_interacts,
		_test_guard_pauses_facing_its_leg,
		_test_guard_turns_smoothly,
		_test_catches_during_swap_and_while_carrying,
		_test_title_play_opens_hub,
		_test_title_logo_sways,
		_test_wipe_follows_reduce_motion,
		_test_hub_doors_unlock_and_enter,
		_test_hideout_hangs_originals,
		_test_hideout_replays_ghost,
		_test_pause_and_settings,
		_test_hub_settings,
		_test_goto_missing_scene_reports,
		_test_room_swap_and_escape,
		_test_room_swap_cancel_and_locked_exit,
		_test_room_easel_paints_fake,
		_test_room_catch_while_painting,
		_test_canvas_leaves_approach_visible,
		_test_sloppy_fake_starts_search,
		_test_good_and_perfect_fakes_pass,
		_test_catch_cuts_inspection_short,
		_test_results_buttons,
		_test_guard_bad_route_reports,
		_test_room_timer_waits_for_fade,
		_test_mime_carrying_before_ready,
		_test_room_paintings_framed,
		_test_room_layout_optional_and_checked,
		_test_navmesh_baked_around_partitions,
		_test_content_validates_wings,
		_test_wings_are_complete,
		_test_wing_doors_carry_the_run,
		_test_gimmick_shade_and_light,
		_test_gimmick_slows_and_ticks,
		_test_gimmick_loud_floor,
		_test_gimmick_clue_investigated,
		_test_gimmick_mix_combines,
		_test_wing_gimmicks,
		_test_guards_wade,
		_test_puddles_checked_and_wired,
		_test_unknown_painting_reports,
		_test_screen_fit,
		_test_rotate_overlay_pauses,
		_test_juice_on_actions,
		_test_rig_views,
		_test_rig_walk_cycle,
		_test_rig_joints_bend,
		_test_mime_faces_its_way,
		_test_ghost_faces_travel,
		_test_no_flash_rates,
		_test_ghost_replay_visits,
		_test_ghost_mime_until_escape,
	]


func _run() -> void:
	# The headless window is 64x64 (a 960x960 visible area under aspect expand), and the
	# engine resets a size set in _initialize: test at the base size from here on.
	root.size = BASE_WINDOW
	var tests := _tests()
	for test in tests:
		await test.call()
	if _failures.is_empty():
		print("test_gameplay: OK (%d tests, %d checks)" % [tests.size(), _checks])
		quit(0)
		return
	for failure in _failures:
		printerr("test_gameplay: FAIL " + failure)
	printerr("test_gameplay: FAILED with %d failure(s)" % _failures.size())
	quit(1)


func _test_project_display_and_input() -> void:
	var name := "project_display_and_input"
	var expected := {
		"display/window/size/viewport_width": BASE_WINDOW.x,
		"display/window/size/viewport_height": BASE_WINDOW.y,
		"display/window/stretch/mode": "canvas_items",
		"display/window/stretch/aspect": "expand",
		"display/window/handheld/orientation": DisplayServer.SCREEN_SENSOR_LANDSCAPE,
		"input_devices/pointing/emulate_touch_from_mouse": true,
		"input_devices/pointing/emulate_mouse_from_touch": false,
		"rendering/renderer/rendering_method": "gl_compatibility",
		"rendering/renderer/rendering_method.mobile": "gl_compatibility",
		"application/run/main_scene": TITLE_PATH,
		# Navigation maps sync on a fixed frame, so tests and the bot's replays repeat exactly.
		"navigation/world/map_use_async_iterations": false,
		"navigation/world/region_use_async_iterations": false,
	}
	for setting: String in expected:
		var value: Variant = ProjectSettings.get_setting(setting)
		_check(value == expected[setting], name, "%s is %s, expected %s" % [setting, value, expected[setting]])
	_check(str(ProjectSettings.get_setting("gui/theme/custom", "")).is_empty(), name, "a project theme is set (the game ships no fonts)")


func _test_project_strict_warnings() -> void:
	for warning in STRICT_WARNINGS:
		var setting := "debug/gdscript/warnings/" + warning
		_check(int(ProjectSettings.get_setting(setting, 0)) == 2, "project_strict_warnings", "%s is not raised to an error (2)" % setting)


func _test_web_export_preset() -> void:
	var name := "web_export_preset"
	var presets := ConfigFile.new()
	var error := presets.load(EXPORT_PRESETS_PATH)
	_check(error == OK, name, "cannot load %s: %s" % [EXPORT_PRESETS_PATH, error_string(error)])
	if error != OK:
		return
	_check(presets.get_value("preset.0", "platform", "") == "Web", name, "preset.0 is not the Web preset")
	_check(presets.get_value("preset.0", "export_path", "") == "../build/web/index.html", name, "export_path is not ../build/web/index.html")
	_check(presets.get_value("preset.0.options", "variant/thread_support", true) == false, name, "thread support is on (itch needs single-threaded)")
	var head: String = presets.get_value("preset.0.options", "html/head_include", "")
	for rule in TOUCH_CSS:
		_check(rule in head, name, "html/head_include lacks '%s'" % rule)


## The title (the main scene) tells Game it arrived and shows only wordless art.
func _test_title_arrives() -> void:
	var name := "title_arrives"
	var error := change_scene_to_file(TITLE_PATH)
	_check(error == OK, name, "cannot load %s: %s" % [TITLE_PATH, error_string(error)])
	await process_frame
	await process_frame
	_check(current_scene != null and current_scene.scene_file_path == TITLE_PATH, name, "the title is not the running scene")
	_check(_game.state == GameState.Flow.TITLE, name, "Game.state is %s, expected TITLE" % GameState.Flow.keys()[_game.state])
	_check(_game.scene_paths[GameState.Flow.TITLE] == TITLE_PATH, name, "Game.scene_paths[TITLE] is not %s" % TITLE_PATH)
	var frame := current_scene.get_node_or_null("Frame") as TextureRect
	_check(frame != null and frame.texture != null and frame.is_visible_in_tree(), name, "the title's Frame art is missing or hidden")
	_check(not _game.error_badge_visible(), name, "the error badge shows on a clean start (errors: %s)" % [_game.errors])


## report_error records the error and shows the cracked-frame badge (never text).
func _test_report_error_shows_badge() -> void:
	var name := "report_error_shows_badge"
	var badge := _game.get_node("ErrorLayer/ErrorBadge") as TextureRect
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	_game.report_error("test: a provoked error")
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and _game.errors[-1] == "test: a provoked error", name, "the error was not recorded")
	_check(_game.error_badge_visible(), name, "the error badge is hidden after report_error")
	await process_frame
	var rect := badge.get_global_rect()
	_check(rect.size.x >= 44.0 and rect.size.y >= 44.0, name, "the badge is %s, smaller than 44x44" % rect.size)
	_check(Rect2(Vector2.ZERO, Vector2(BASE_WINDOW)).encloses(rect), name, "the badge at %s leaves the screen" % rect)
	_check(badge.mouse_filter == Control.MOUSE_FILTER_IGNORE, name, "the badge blocks touches")
	_game.errors.resize(errors_before)
	badge.visible = false


func _test_detection_cone() -> void:
	var name := "detection_cone"
	var origin := Vector2(100, 100)
	var right := Vector2.RIGHT
	var half := deg_to_rad(30.0)
	_check(Detection.in_cone(origin, right, Vector2(200, 100), 150.0, half), name, "a point straight ahead within range is outside the cone")
	_check(Detection.in_cone(origin, right, origin, 150.0, half), name, "the guard's own position is outside the cone")
	_check(not Detection.in_cone(origin, right, Vector2(260, 100), 150.0, half), name, "a point beyond the range is inside the cone")
	_check(not Detection.in_cone(origin, right, Vector2(0, 100), 150.0, half), name, "a point behind the guard is inside the cone")
	# 29 degrees off the facing is inside a 30-degree half angle, 31 degrees is not.
	_check(Detection.in_cone(origin, right, origin + Vector2.from_angle(deg_to_rad(29.0)) * 100.0, 150.0, half), name, "29 degrees off is outside a 30-degree cone")
	_check(not Detection.in_cone(origin, right, origin + Vector2.from_angle(deg_to_rad(-31.0)) * 100.0, 150.0, half), name, "31 degrees off is inside a 30-degree cone")
	# The facing need not be normalised.
	_check(Detection.in_cone(origin, Vector2(0, 5), Vector2(100, 200), 150.0, half), name, "an unnormalised facing changes the cone")


func _test_detection_suspicion() -> void:
	var name := "detection_suspicion"
	var far := Detection.suspicion_after(0.0, true, 150.0, 150.0, 0.1)
	var near := Detection.suspicion_after(0.0, true, 0.0, 150.0, 0.1)
	_check(is_equal_approx(far, Detection.FILL_FAR * 0.1), name, "at the cone's edge suspicion rose to %f, expected %f" % [far, Detection.FILL_FAR * 0.1])
	_check(is_equal_approx(near, (Detection.FILL_FAR + Detection.FILL_NEAR) * 0.1), name, "at the guard's feet suspicion rose to %f" % near)
	_check(near > far, name, "suspicion does not fill faster up close")
	_check(is_equal_approx(Detection.suspicion_after(0.5, false, 0.0, 150.0, 0.1), 0.5 - Detection.DRAIN * 0.1), name, "suspicion does not drain while unseen")
	_check(Detection.suspicion_after(0.01, false, 0.0, 150.0, 1.0) == 0.0, name, "suspicion drains below 0")
	_check(Detection.suspicion_after(0.99, true, 0.0, 150.0, 1.0) == 1.0, name, "suspicion fills above 1")
	_check(Detection.is_full(1.0) and not Detection.is_full(0.999), name, "full is not exactly suspicion 1")
	# Seen point-blank from nothing, a catch takes 1 / (FILL_FAR + FILL_NEAR) seconds at 60 ticks per second.
	var suspicion := 0.0
	var ticks := 0
	while not Detection.is_full(suspicion) and ticks < 600:
		suspicion = Detection.suspicion_after(suspicion, true, 0.0, 150.0, 1.0 / 60.0)
		ticks += 1
	var expected := ceili(60.0 / (Detection.FILL_FAR + Detection.FILL_NEAR))
	_check(absi(ticks - expected) <= 1, name, "a point-blank catch took %d ticks, expected about %d" % [ticks, expected])


func _test_stars() -> void:
	var name := "stars"
	_check(Stars.earned(false, 50.0, 60.0) == [true, true, true], name, "an unseen escape under par does not earn all three stars")
	_check(Stars.earned(true, 50.0, 60.0) == [true, false, true], name, "a seen escape still earns the unseen star")
	_check(Stars.earned(false, 60.0, 60.0)[Stars.Star.PAR], name, "an escape exactly at par misses the par star")
	_check(not Stars.earned(false, 60.1, 60.0)[Stars.Star.PAR], name, "an escape over par earns the par star")
	_check(Stars.count(Stars.earned(true, 99.0, 60.0)) == 1, name, "a seen, slow escape does not earn exactly the swap star")


## Audio.SFX_IDS and the files tools/sfx.py writes agree, as do Audio.MUSIC_TRACKS and
## tools/music.py's loops (each imported looping); every sound loads as audio on the SFX bus's
## players, the music on the Music bus's; play logs the id; an unknown sound or track is
## reported and changes nothing; music_for picks the caper outside the wings and each wing's
## era in its rooms.
func _test_sfx_files() -> void:
	var name := "sfx_files"
	var files: Array[StringName] = []
	for file in DirAccess.get_files_at("res://audio/sfx"):
		if file.get_extension() == "wav":
			files.append(StringName(file.get_basename()))
	var ids := Audio.SFX_IDS.duplicate()
	ids.sort()
	files.sort()
	_check(files == ids, name, "audio/sfx holds %s, Audio.SFX_IDS lists %s" % [files, ids])
	for id in Audio.SFX_IDS:
		_check(load(Audio.SFX_PATH % id) is AudioStream, name, "sound %s does not load as audio" % id)
	var audio := _game.audio
	_check((audio.get_node("Sfx0") as AudioStreamPlayer).bus == Audio.SFX_BUS and (audio.get_node("Sfx%d" % (Audio.VOICES - 1)) as AudioStreamPlayer).bus == Audio.SFX_BUS, name, "the sound players are not on the SFX bus")
	audio.play(&"tilt")
	_check(audio.played.back() == &"tilt", name, "play does not log the sound")
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	audio.play(&"no_such_sound")
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and audio.played.back() == &"tilt", name, "an unknown sound is not reported, or it was played")
	var loops: Array[String] = []
	for file in DirAccess.get_files_at("res://audio/music"):
		if file.get_extension() == "mp3":
			loops.append(file.get_basename())
	var tracks := Audio.MUSIC_TRACKS.duplicate()
	tracks.sort()
	loops.sort()
	_check(loops == tracks, name, "audio/music holds %s, Audio.MUSIC_TRACKS lists %s" % [loops, tracks])
	for track in Audio.MUSIC_TRACKS:
		var stream := load(Audio.MUSIC_PATH % track) as AudioStreamMP3
		_check(stream != null and stream.loop, name, "loop %s does not load as a looping MP3" % track)
	_check((audio.get_node("Music0") as AudioStreamPlayer).bus == Audio.MUSIC_BUS and (audio.get_node("Music1") as AudioStreamPlayer).bus == Audio.MUSIC_BUS, name, "the music players are not on the Music bus")
	var playing := audio.music
	_game.quiet_errors = true
	audio.play_music("no_such_track")
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 2 and audio.music == playing, name, "an unknown track is not reported, or the music changed")
	var lines: Array[String] = []
	for voice in Audio.GUARD_VOICES:
		for event in Audio.VOICE_EVENTS:
			for n in Audio.LINES_PER_EVENT:
				var path := Audio.VOICE_PATH % [voice, event, n + 1]
				lines.append(path.get_file())
				_check(load(path) is AudioStream, name, "voice line %s does not load as audio" % path)
	var spoken: Array[String] = []
	for file in DirAccess.get_files_at("res://audio/voice"):
		if file.get_extension() == "mp3":
			spoken.append(file)
	lines.sort()
	spoken.sort()
	_check(spoken == lines, name, "audio/voice holds %s, the voices and events make %s" % [spoken, lines])
	audio.say(&"rookie", &"hear")
	audio.say(&"rookie", &"hear")
	audio.say(&"rookie", &"hear")
	_check(audio.said.slice(-3) == [&"rookie_hear_1", &"rookie_hear_2", &"rookie_hear_1"], name, "a voice does not take its lines in turn: %s" % [audio.said])
	_game.quiet_errors = true
	audio.say(&"nobody", &"hear")
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 3, name, "an unknown voice is not reported")
	var was_run := _game.run
	_game.run = null
	_check(_game.music_for(GameState.Flow.HUB) == "caper" and _game.music_for(GameState.Flow.ROOM) == "caper", name, "outside a wing the caper does not play")
	for i in Content.WINGS.size():
		_game.run = WingRun.new(load(Content.WINGS[i]) as WingData)
		_check(_game.music_for(GameState.Flow.ROOM) == "wing_%02d" % (i + 1), name, "wing %d's rooms play %s" % [i + 1, _game.music_for(GameState.Flow.ROOM)])
	_game.run = was_run
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false


## Keyboard walking sounds too: tiptoes on quiet floor, the floor's own sound (the gimmick's
## noise_sound) on noisy floor, where the room's loud step (a path walk's) does not count it.
func _test_keyboard_steps_sound() -> void:
	var name := "keyboard_steps_sound"
	_game.run = null
	var gimmick := TestGimmick.new()
	var room := await _load_room_with_gimmick(gimmick)
	var played := _game.audio.played
	for noisy: bool in [false, true]:
		gimmick.noise = 1.0 if noisy else 0.0
		played.clear()
		for i in 40:
			room.mime.nudge(Vector2.LEFT if i < 20 else Vector2.RIGHT, 1.0 / 60.0)
			await physics_frame
		var want := &"splash" if noisy else &"tiptoe"
		_check(want in played and not (&"tiptoe" if noisy else &"splash") in played, name, "keyboard steps on %s floor played %s, not only %s" % ["noisy" if noisy else "quiet", played, want])
	room.queue_free()
	_game.run = null
	await process_frame


## A room hands its guards the voices in turn (wing 6's salon has three: watchman, rookie,
## watchman).
func _test_guards_take_voices() -> void:
	var name := "guards_take_voices"
	_game.run = null
	var room := (load("res://scenes/wings/wing_06_salon.tscn") as PackedScene).instantiate() as Room
	root.add_child(room)
	var voices: Array[StringName] = []
	for each in room.guards:
		voices.append(each.voice)
	_check(voices.size() >= 2 and voices[0] == &"watchman" and voices[1] == &"rookie", name, "the salon's guards speak as %s" % [voices])
	room.queue_free()
	_game.run = null
	await process_frame


## Every action sounds (AC 35): walking tiptoes; a tilt; hiding and stepping out; the swap;
## a guard's chase alert; a catch's bonk, toss and landing; the pause button's tap with the
## pause and resume; the escape and each results star.
func _test_sfx_on_actions() -> void:
	var name := "sfx_on_actions"
	_game.run = null
	var room := await _load_room()
	if room == null:
		return
	_check(_game.audio.music == "wing_04", name, "the slice room (The Starry Night) plays %s, not wing_04's loop" % _game.audio.music)
	var played := _game.audio.played
	played.clear()
	room.mime.walk_to(room.mime.position + Vector2(-60, 0))
	for i in 30:
		await physics_frame
	room._tilt(room.get_node("Frames").get_child(0) as TiltFrame)
	room._hide_in(room.get_node("Portraits").get_child(0) as HidingPortrait)
	room._step_out()
	room._swap()
	room.guard.intent = GuardBrain.Intent.CHASE
	room.guard._show_intent()
	var shout: StringName = _game.audio.said.back()
	room._on_caught()
	await create_timer(Room.TOSS_SHAKE + Room.TOSS_FLIGHT + 0.2).timeout
	(room.get_node("PauseButton") as Button).pressed.emit()
	room.pause_menu.resume()
	_check(str(shout).begins_with("%s_chase_" % room.guard.voice), name, "the chasing guard did not shout: %s" % [_game.audio.said])
	for id: StringName in [&"tiptoe", &"tilt", &"hide", &"unhide", &"swap", &"guard_alert", &"caught", &"toss", &"land", &"ui_tap", &"pause", &"resume"]:
		_check(id in played, name, "%s did not sound; played %s" % [id, played])
	played.clear()
	room._escape()
	await create_timer((Results.STAR_GAP + Results.POP_TIME) * 3.0 + 0.1).timeout
	_check(played.count(&"escape") == 1 and played.count(&"star") + played.count(&"no_star") == 3, name, "the escape and its three stars did not sound once each: %s" % [played])
	_check(_game.audio.music == "results", name, "the results play %s, not the results loop" % _game.audio.music)
	# The swap and escape are this room's run's: the next room starts a fresh one. The
	# results overlay would cover the next test's loose canvas, so the room goes.
	_game.run = null
	room.queue_free()
	await process_frame


func _test_save_shape() -> void:
	var name := "save_shape"
	var problems: Array[String] = []
	var data := Save.defaults()
	_check(Save.record(data, "wing_01", [true, false, true] as Array[bool], 80.0), name, "a first escape is not a best")
	_check(not Save.record(data, "wing_01", [true, false, false] as Array[bool], 90.0), name, "a worse escape counts as a best")
	_check(Save.record(data, "wing_01", [true, true, true] as Array[bool], 95.0) and data["wings"]["wing_01"] == {"stars": 3, "time": 80.0}, name, "the best stars and best time are not kept apart: %s" % data["wings"])
	data["settings"]["assist"] = true
	var back := Save.parse(Save.to_json(data), problems)
	_check(problems.is_empty() and back == data, name, "a save does not read back as written: %s, %s" % [back, problems])
	var ids := Content.wing_ids()
	_check(ids[0] == "wing_01" and ids.size() == Content.WINGS.size(), name, "wing ids are %s" % [ids])
	_check(Save.unlocked(data, ids, 0) and Save.unlocked(data, ids, 1) and not Save.unlocked(data, ids, 2) and not Save.unlocked(data, ids, 6), name, "after wing 1, only wings 1 and 2 should be open")
	_check(Save.unlocked(Save.defaults(), ids, 0) and not Save.unlocked(Save.defaults(), ids, 1), name, "a fresh save opens more than wing 1")
	var older := Save.parse('{"version": 1, "wings": {}, "settings": {"music": false}}', problems)
	_check(problems.is_empty() and older["settings"] == {"music": false, "sound": true, "reduce_motion": false, "assist": false}, name, "a missing setting does not take its default: %s" % [older])
	for bad: String in ["{", "[]", '{"version": 2, "wings": {}}', '{"version": 1, "wings": []}', '{"version": 1, "wings": {"wing_01": {"stars": 4, "time": 1}}}',
			'{"version": 1, "wings": {"wing_01": {"stars": 1.5, "time": 1}}}', '{"version": 1, "wings": {}, "settings": {"music": 1}}']:
		problems.clear()
		_check(Save.parse(bad, problems).is_empty() and problems.size() == 1, name, "save '%s' is not refused with one problem: %s" % [bad, problems])


func _test_save_load_write_and_corrupt() -> void:
	var name := "save_load_write_and_corrupt"
	_check(_game.save_path == GameState.TOOL_SAVE_PATH, name, "a tool run uses the save at %s" % _game.save_path)
	var errors_before := _game.errors.size()
	DirAccess.remove_absolute(_game.save_path)
	DirAccess.remove_absolute(_game.backup_path())
	_game.load_save()
	_check(_game.save == Save.defaults(), name, "no save does not start from defaults")
	_game.set_setting("music", false)
	_check(FileAccess.file_exists(_game.save_path) and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and not AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), name, "turning music off does not mute only the Music bus and write the save")
	_game.save = Save.defaults()
	_game.load_save()
	_check(not _game.setting("music"), name, "the music setting does not survive a load")
	var file := FileAccess.open(_game.save_path, FileAccess.WRITE)
	file.store_string("{ not json")
	file.close()
	_game.quiet_errors = true
	_game.load_save()
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and _game.error_badge_visible(), name, "a corrupt save is not reported with the badge")
	_check(FileAccess.get_file_as_string(_game.backup_path()) == "{ not json", name, "the corrupt save is not kept as %s" % _game.backup_path())
	var problems: Array[String] = []
	_check(Save.parse(FileAccess.get_file_as_string(_game.save_path), problems) == Save.defaults() and _game.setting("music"), name, "the corrupt save is not replaced by defaults")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	DirAccess.remove_absolute(_game.save_path)
	DirAccess.remove_absolute(_game.backup_path())
	_game.save = Save.defaults()
	_game.set_setting("music", true)
	DirAccess.remove_absolute(_game.save_path)


## A swirl ghost: an outward spiral of `turns` turns around `center`, 48 points a turn.
func _spiral(center: Vector2, turns: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in int(turns * 48.0) + 1:
		var angle := TAU * i / 48.0
		points.append(center + Vector2.from_angle(angle) * (20.0 + 8.0 * angle))
	return points


## A sweeping-curve ghost: the upper half circle of `radius` around `center`, 48 points.
func _arc(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 49:
		points.append(center + Vector2.from_angle(PI + PI * i / 48.0) * radius)
	return points


## A GuardBrain.Senses with `fields` set (name: value).
func _senses(fields: Dictionary) -> GuardBrain.Senses:
	var senses := GuardBrain.Senses.new()
	for field: String in fields:
		senses.set(field, fields[field])
	return senses


func _intent_name(intent: GuardBrain.Intent) -> String:
	return GuardBrain.Intent.keys()[intent]


## Each intent wins alone, and the priority order holds when they compete.
func _test_guard_brain_priorities() -> void:
	var name := "guard_brain_priorities"
	var cases := [
		[{}, GuardBrain.Intent.PATROL],
		[{"tilted_frame_known": true}, GuardBrain.Intent.STRAIGHTEN],
		[{"noise_heard": true, "noise_distance": 0.0}, GuardBrain.Intent.INVESTIGATE],
		[{"fake_in_view": true}, GuardBrain.Intent.INSPECT],
		[{"search_left": 3.0}, GuardBrain.Intent.SEARCH],
		[{"suspicion": 1.0}, GuardBrain.Intent.CHASE],
		[{"tilted_frame_known": true, "noise_heard": true, "noise_distance": 10.0}, GuardBrain.Intent.INVESTIGATE],
		[{"noise_heard": true, "fake_in_view": true}, GuardBrain.Intent.INSPECT],
		[{"fake_in_view": true, "search_left": 1.0}, GuardBrain.Intent.SEARCH],
		[{"search_left": 1.0, "suspicion": 1.0, "fake_in_view": true, "noise_heard": true, "tilted_frame_known": true}, GuardBrain.Intent.CHASE],
	]
	for case: Array in cases:
		var scores := GuardBrain.scores(_senses(case[0]))
		var chosen := GuardBrain.choose(scores)
		_check(chosen == case[1], name, "senses %s chose %s, not %s (scores %s)" % [case[0], _intent_name(chosen), _intent_name(case[1]), scores])
		for intent: GuardBrain.Intent in scores:
			_check(scores[intent] >= 0.0 and scores[intent] <= 1.0, name, "%s scored %.2f, outside 0..1" % [_intent_name(intent), scores[intent]])
	var tied: Dictionary[GuardBrain.Intent, float] = {GuardBrain.Intent.PATROL: 0.5, GuardBrain.Intent.SEARCH: 0.5, GuardBrain.Intent.INSPECT: 0.5}
	_check(GuardBrain.choose(tied) == GuardBrain.Intent.PATROL, name, "a tie did not go to the earlier intent")


## A chase outlasts a lost sight for CHASE_MEMORY; a nearer noise scores higher, one
## beyond hearing scores nothing, and a far one loses to a known tilted frame.
func _test_guard_brain_chase_and_noise() -> void:
	var name := "guard_brain_chase_and_noise"
	var memory := GuardBrain.CHASE_MEMORY
	_check(GuardBrain.choose(GuardBrain.scores(_senses({"chasing": true, "lost_sight_for": memory - 0.01}))) == GuardBrain.Intent.CHASE, name, "a chase ended before CHASE_MEMORY")
	_check(GuardBrain.choose(GuardBrain.scores(_senses({"chasing": true, "lost_sight_for": memory}))) == GuardBrain.Intent.PATROL, name, "a chase outlasted CHASE_MEMORY")
	var near := GuardBrain.scores(_senses({"noise_heard": true, "noise_distance": 50.0}))[GuardBrain.Intent.INVESTIGATE]
	var far := GuardBrain.scores(_senses({"noise_heard": true, "noise_distance": 400.0}))[GuardBrain.Intent.INVESTIGATE]
	_check(near > far and far > 0.0, name, "a noise at 50 scored %.2f, at 400 %.2f (expected near > far > 0)" % [near, far])
	_check(GuardBrain.scores(_senses({"noise_heard": true, "noise_distance": GuardBrain.HEARING_RANGE}))[GuardBrain.Intent.INVESTIGATE] == 0.0, name, "a noise at the edge of hearing was heard")
	_check(GuardBrain.choose(GuardBrain.scores(_senses({"noise_heard": true, "noise_distance": 400.0, "tilted_frame_known": true}))) == GuardBrain.Intent.STRAIGHTEN, name, "a far noise beat a known tilted frame")


func _test_forgery_scoring() -> void:
	var name := "forgery_scoring"
	var line := PackedVector2Array([Vector2(0, 0), Vector2(100, 0)])
	var resampled := Forgery.resample(line)
	_check(resampled.size() == 14 and resampled[1].is_equal_approx(Vector2(8, 0)) and resampled[13] == Vector2(100, 0), name, "a 100-long line does not resample to 14 points 8 apart ending on its end: %s" % resampled)
	var swirl := _spiral(Vector2(200, 150), 2.0)
	var exact := Forgery.stroke_quality(swirl, swirl)
	_check(exact > 0.98, name, "tracing the swirl exactly scores %.3f, not about 1" % exact)
	var shaky := PackedVector2Array()
	for point in Forgery.resample(swirl):
		shaky.append(point + Vector2(0, 6.0 if shaky.size() % 2 == 0 else -6.0))
	# A sweeping curve, and traces running 10 and 30 outside it (radially, so truly that far).
	var curve := _arc(Vector2(200, 200), 120.0)
	var near := Forgery.stroke_quality(curve, _arc(Vector2(200, 200), 130.0))
	_check(Forgery.grade(near) == Forgery.Grade.GOOD, name, "a trace 10 off the curve grades %s (%.3f), not Good" % [Forgery.Grade.keys()[Forgery.grade(near)], near])
	var off := Forgery.stroke_quality(curve, _arc(Vector2(200, 200), 150.0))
	_check(Forgery.grade(off) == Forgery.Grade.SLOPPY, name, "a trace 30 off the curve grades %s (%.3f), not Sloppy" % [Forgery.Grade.keys()[Forgery.grade(off)], off])
	var wobbly := Forgery.stroke_quality(swirl, shaky)
	_check(wobbly < exact and Forgery.grade(wobbly) != Forgery.Grade.PERFECT, name, "a shaky trace hugging the swirl (%.3f) is not below an exact one (%.3f) or grades Perfect" % [wobbly, exact])
	var dab := PackedVector2Array([Vector2(50, 50)])
	_check(is_equal_approx(Forgery.stroke_quality(dab, dab), 1.0), name, "an exact dab does not score 1")
	_check(is_equal_approx(Forgery.stroke_quality(dab, PackedVector2Array([Vector2(70, 50)])), 0.625), name, "a dab 20 off does not score half accuracy (0.625)")
	_check(Forgery.stroke_quality(swirl, PackedVector2Array()) == 0.0, name, "an untraced stroke does not score 0")
	_check(Forgery.stroke_quality(swirl, PackedVector2Array([swirl[0]])) == 0.0, name, "a tap on a swirl's start scores %.3f, not 0" % Forgery.stroke_quality(swirl, PackedVector2Array([swirl[0]])))
	var half := curve.slice(0, 25)
	_check(Forgery.stroke_quality(curve, half) <= 0.5 * Forgery.stroke_quality(curve, curve) + 0.01, name, "half a curve scores %.3f, more than half a full trace" % Forgery.stroke_quality(curve, half))
	var ghosts: Array[PackedVector2Array] = [swirl, dab]
	var traced: Array[PackedVector2Array] = [swirl]
	_check(is_equal_approx(Forgery.quality(ghosts, traced), Forgery.stroke_quality(swirl, swirl) / 2.0), name, "a fake missing its second stroke does not score half the first")
	_check(Forgery.quality([] as Array[PackedVector2Array], traced) == 0.0, name, "a fake of no ghosts does not score 0")


func _test_forgery_grades() -> void:
	var name := "forgery_grades"
	var cases := {0.0: Forgery.Grade.SLOPPY, 0.549: Forgery.Grade.SLOPPY, 0.55: Forgery.Grade.GOOD, 0.849: Forgery.Grade.GOOD, 0.85: Forgery.Grade.PERFECT, 1.0: Forgery.Grade.PERFECT}
	for fake_quality: float in cases:
		_check(Forgery.grade(fake_quality) == cases[fake_quality], name, "quality %.3f does not grade %s" % [fake_quality, Forgery.Grade.keys()[cases[fake_quality]]])
	_check(Forgery.grade(Forgery.ASSIST_QUALITY) == Forgery.Grade.GOOD, name, "Assist's quality does not grade Good")
	_check(Forgery.is_noticed(Forgery.Grade.SLOPPY, 1), name, "a Sloppy fake survives its first inspection")
	_check(not Forgery.is_noticed(Forgery.Grade.GOOD, 1) and Forgery.is_noticed(Forgery.Grade.GOOD, 2), name, "a Good fake does not survive exactly one inspection")
	_check(not Forgery.is_noticed(Forgery.Grade.PERFECT, 99), name, "a Perfect fake is noticed")


## Every painting id has its scan, credited in SOURCES.json, and its style shader; the
## registry and the credits list the same six ids; an unknown id has no style.
func _test_paintings_registry() -> void:
	var name := "paintings_registry"
	var credited: Array[StringName] = []
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://art/scans/SOURCES.json")):
		credited.append(StringName(entry["id"]))
		_check(entry["file"] == "%s.webp" % entry["id"], name, "credit '%s' names file '%s'" % [entry["id"], entry["file"]])
	_check(credited == Paintings.IDS, name, "SOURCES.json ids %s are not Paintings.IDS %s" % [credited, Paintings.IDS])
	for id in Paintings.IDS:
		_check(Paintings.SCANS.get(id) != null, name, "%s has no scan" % id)
		var material := Paintings.style(id, true)
		_check(material != null and material.shader == Paintings.STYLES[id] and material.get_shader_parameter(&"use_screen") == true, name, "%s's screen style is not its shader reading the screen" % id)
	_check(Paintings.style(&"no_such_painting") == null, name, "an unknown id has a style")
	for script: Script in [FramedPainting, TiltFrame, HidingPortrait]:
		var hint := ""
		for property in script.get_script_property_list():
			if property["name"] == "painting":
				hint = property["hint_string"]
		var listed: Array[StringName] = []
		for id in hint.split(","):
			listed.append(StringName(id))
		_check(listed == Paintings.IDS, name, "%s's painting choices %s are not Paintings.IDS" % [script.resource_path, hint])

## A finger pressed at the first of `points` (canvas base units), dragged through the
## rest and lifted at the last, one event a frame.
func _drag_along(points: PackedVector2Array) -> void:
	var press := InputEventScreenTouch.new()
	press.index = TOUCH_INDEX
	press.position = root.get_final_transform() * points[0]
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	for i in range(1, points.size()):
		var drag := InputEventScreenDrag.new()
		drag.index = TOUCH_INDEX
		drag.position = root.get_final_transform() * points[i]
		drag.relative = (points[i] - points[i - 1]) * root.get_final_transform().get_scale()
		Input.parse_input_event(drag)
		await process_frame
	var release := InputEventScreenTouch.new()
	release.index = TOUCH_INDEX
	release.position = root.get_final_transform() * points[points.size() - 1]
	Input.parse_input_event(release)
	await process_frame


## A forgery canvas on its own, tracing a sweep then a dab; `painted` lands in `result`.
func _make_canvas(result: Array[float]) -> ForgeryCanvas:
	var canvas := (load(CANVAS_PATH) as PackedScene).instantiate() as ForgeryCanvas
	canvas.ghosts = [_arc(Vector2(160, 200), 110.0), PackedVector2Array([Vector2(260, 50)])]
	canvas.painted.connect(func(fake_quality: float) -> void: result.append(fake_quality))
	root.add_child(canvas)
	return canvas


## `points` (pad-local) in canvas base units.
func _on_pad(canvas: ForgeryCanvas, points: PackedVector2Array) -> PackedVector2Array:
	var origin := (canvas.get_node("Pad") as Control).get_global_rect().position
	var moved := PackedVector2Array()
	for point in points:
		moved.append(origin + point)
	return moved


## Tracing every ghost exactly grades Perfect: the icon pops, holds, and the canvas
## closes with painted; a touch off the pad paints nothing; reopening starts afresh.
func _test_canvas_traces_and_grades() -> void:
	var name := "canvas_traces_and_grades"
	var result: Array[float] = []
	var canvas := _make_canvas(result)
	await process_frame
	_check(not canvas.visible, name, "the canvas shows before it is opened")
	canvas.open()
	await process_frame
	_check(canvas.visible and (canvas.get_node("CloseButton") as Button).has_focus(true), name, "the open canvas does not focus its put-down-brush button with a visible ring")
	await _tap_at(Vector2(200, 450))
	_check(canvas.traced.is_empty(), name, "a tap off the pad painted a stroke")
	await _drag_along(_on_pad(canvas, Forgery.resample(canvas.ghosts[0])))
	_check(canvas.traced.size() == 1 and canvas.visible and result.is_empty(), name, "after the first stroke: %d traced, visible %s, painted %s" % [canvas.traced.size(), canvas.visible, result])
	await _tap_at(_on_pad(canvas, canvas.ghosts[1])[0])
	var grade := canvas.get_node("Grade") as TextureRect
	_check(grade.visible and grade.texture == ForgeryCanvas.GRADE_ICONS[Forgery.Grade.PERFECT], name, "an exact fake does not show the Perfect icon")
	_check(await _wait_until(func() -> bool: return not result.is_empty(), 120), name, "painted never came after the last stroke")
	_check(not result.is_empty() and Forgery.grade(result[0]) == Forgery.Grade.PERFECT, name, "an exact fake painted %s, not Perfect" % [result])
	_check(not canvas.visible, name, "the canvas stays open after painting")
	canvas.open()
	_check(canvas.traced.is_empty(), name, "reopening a finished canvas keeps the old strokes")
	canvas.queue_free()
	await process_frame


## Putting the brush down (by tap or by key) keeps the finished strokes; reopening
## resumes; putting it down during the grade's hold delivers the fake at once (only
## once); the start dot pulses under the 2 Hz flash limit; a canvas without ghosts is
## reported and stays shut.
func _test_canvas_close_keeps_strokes() -> void:
	var name := "canvas_close_keeps_strokes"
	var result: Array[float] = []
	var canvas := _make_canvas(result)
	await process_frame
	canvas.open()
	await _drag_along(_on_pad(canvas, Forgery.resample(canvas.ghosts[0])))
	await _tap_control(canvas.get_node("CloseButton") as Button)
	_check(not canvas.visible and canvas.traced.size() == 1, name, "putting the brush down: visible %s, %d traced (expected hidden, 1)" % [canvas.visible, canvas.traced.size()])
	canvas.open()
	_check(canvas.visible and canvas.traced.size() == 1, name, "reopening does not resume at the second stroke")
	await process_frame
	await _press_accept()
	_check(not canvas.visible and canvas.traced.size() == 1, name, "ui_accept on the focused put-down-brush button did not leave the canvas, keeping the stroke")
	canvas.open()
	# The dab tapped 100 off: (1 + 0.25) / 2 is Good.
	await _tap_at(_on_pad(canvas, canvas.ghosts[1])[0] + Vector2(-100, 0))
	_check(result.is_empty() and canvas.visible, name, "painted came before the grade's hold")
	canvas.close()
	_check(result.size() == 1 and not canvas.visible, name, "putting the brush down during the grade's hold did not deliver the fake at once (painted %s)" % [result])
	for i in ceili((ForgeryCanvas.GRADE_POP + ForgeryCanvas.GRADE_HOLD) * 60.0) + 10:
		await physics_frame
	_check(result.size() == 1 and Forgery.grade(result[0]) == Forgery.Grade.GOOD, name, "an exact sweep and a dab 100 off painted %s, not Good once" % [result])
	_check(ForgeryCanvas.PULSE_HZ < 2.0, name, "the start dot pulses at %.1f Hz, not under 2 Hz" % ForgeryCanvas.PULSE_HZ)
	canvas.ghosts = []
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	canvas.open()
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and "no ghost strokes" in _game.errors[-1], name, "a canvas without ghosts was not reported")
	_check(not canvas.visible, name, "a canvas without ghosts opens")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	canvas.queue_free()
	await process_frame


## Presses and releases ui_accept (Enter / Space on the focused button), as a keyboard would.
func _press_accept() -> void:
	for pressed: bool in [true, false]:
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = pressed
		Input.parse_input_event(accept)
		await process_frame


## Assist mode: the assist button is hidden by default; on, it shows with the visible
## focus, and one keyboard ui_accept paints the remaining strokes at exactly Good.
func _test_canvas_assist_paints_good() -> void:
	var name := "canvas_assist_paints_good"
	var result: Array[float] = []
	var canvas := _make_canvas(result)
	await process_frame
	var assist := canvas.get_node("AssistButton") as Button
	canvas.open()
	_check(not assist.visible, name, "the assist button shows with Assist mode off")
	canvas.close()
	_game.assist = true
	canvas.open()
	await process_frame
	_check(assist.visible and assist.has_focus(true), name, "with Assist mode on, the assist button is hidden or lacks the visible focus")
	_check(assist.accessibility_name != "" and assist.get_global_rect().size.x >= 44.0, name, "the assist button has no accessibility name or is under 44 wide")
	await _drag_along(_on_pad(canvas, Forgery.resample(canvas.ghosts[0])))
	await _press_accept()
	_game.assist = false
	_check(await _wait_until(func() -> bool: return not result.is_empty(), 120), name, "ui_accept on the assist button never painted")
	_check(not result.is_empty() and result[0] == Forgery.ASSIST_QUALITY and Forgery.grade(result[0]) == Forgery.Grade.GOOD, name, "Assist painted %s, not exactly ASSIST_QUALITY (Good)" % [result])
	_check(canvas.traced == canvas.ghosts, name, "Assist did not paint every stroke")
	canvas.queue_free()
	await process_frame


## Loads the slice room and waits until the navigation map has synced its navmesh.
func _load_room() -> Room:
	var error := change_scene_to_file(ROOM_PATH)
	if error != OK:
		_check(false, "load_room", "cannot load %s: %s" % [ROOM_PATH, error_string(error)])
		return null
	for i in 3:
		await physics_frame
	var room := current_scene as Room
	var map := room.get_world_2d().navigation_map
	if not await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60):
		_check(false, "load_room", "the room's navigation map never synced")
	return room


## The slice room with a second guard ("Guard2", walking `route`) added under Actors
## before it enters the tree, made the current scene.
func _load_two_guard_room(route: PackedVector2Array) -> Room:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	var second := (load("res://scenes/guard.tscn") as PackedScene).instantiate() as Guard
	second.name = "Guard2"
	second.route = route
	room.get_node("Actors").add_child(second)
	var old := current_scene
	root.add_child(room)
	current_scene = room
	if old != null:
		old.queue_free()
	for i in 3:
		await physics_frame
	var map := room.get_world_2d().navigation_map
	if not await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60):
		_check(false, "load_two_guard_room", "the room's navigation map never synced")
	return room


## Stands `guard` still at `at`, facing `facing`.
func _stand(guard: Guard, at: Vector2, facing: Vector2) -> void:
	guard.patrolling = false
	guard.position = at
	guard.facing = facing


## A pressed then released touch at `at` (canvas base units), as a finger would.
func _tap_at(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var touch := InputEventScreenTouch.new()
		touch.index = TOUCH_INDEX
		touch.position = root.get_final_transform() * at
		touch.pressed = pressed
		Input.parse_input_event(touch)
		await process_frame


## Waits until the mime stops walking (at most `max_frames` physics frames) and returns
## every position it passed through.
func _walk_trace(mime: Mime, max_frames: int) -> Array[Vector2]:
	var trace: Array[Vector2] = [mime.position]
	for i in max_frames:
		await physics_frame
		trace.append(mime.position)
		if not mime.walking:
			break
	return trace


## From the door, a tap across the partition walks the mime around it to the tap.
func _test_room_tap_walks_around_partition() -> void:
	var name := "room_tap_walks_around_partition"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	_check(_game.state == GameState.Flow.ROOM, name, "Game.state is %s, expected ROOM" % GameState.Flow.keys()[_game.state])
	_check(room.mime.position == room.entrance, name, "the mime starts at %s, not the entrance %s" % [room.mime.position, room.entrance])
	var target := Vector2(720, 330)
	await _tap_at(target)
	_check(room.mime.walking, name, "a floor tap did not start a walk")
	var trace := await _walk_trace(room.mime, 600)
	_check(not room.mime.walking, name, "the mime was still walking after 600 frames")
	_check(room.mime.position.distance_to(target) <= 6.0, name, "the mime stopped at %s, not at the tap %s" % [room.mime.position, target])
	var inside := trace.filter(func(point: Vector2) -> bool: return PARTITION_FOOTPRINT.has_point(point))
	_check(inside.is_empty(), name, "the mime walked through the partition at %s" % [inside.slice(0, 3)])
	var detour := trace.any(func(point: Vector2) -> bool: return point.y < PARTITION_FOOTPRINT.position.y or point.y > PARTITION_FOOTPRINT.end.y)
	_check(detour, name, "the mime never left the partition's row (no detour around it)")


## A tap on the back wall walks the mime to the nearest floor point below it.
func _test_room_tap_on_wall_stops_at_floor() -> void:
	var name := "room_tap_on_wall_stops_at_floor"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	await _tap_at(Vector2(200, 60))
	await _walk_trace(room.mime, 600)
	_check(not room.mime.walking, name, "the mime was still walking after 600 frames")
	_check(absf(room.mime.position.y - FLOOR_TOP) <= 6.0 and absf(room.mime.position.x - 200.0) <= 6.0, name, "the mime stopped at %s, expected about (200, %d)" % [room.mime.position, FLOOR_TOP])


## Stands the room's guard still at `at`, facing `facing`, and puts the mime at `mime_at`.
func _stage_guard(room: Room, at: Vector2, facing: Vector2, mime_at: Vector2) -> void:
	room.guard.patrolling = false
	room.guard.position = at
	room.guard.facing = facing
	room.mime.place_at(mime_at)


## The guard walks its route's first leg, facing the way it walks.
func _test_guard_patrols() -> void:
	var name := "guard_patrols"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var start := room.guard.position
	# _load_room waits 3 physics frames, which the guard spends walking.
	_check(start.distance_to(room.guard.route[0]) <= 3.0 * Guard.PATROL_SPEED / 60.0 + 0.01, name, "the guard starts at %s, not at its route's first point %s" % [start, room.guard.route[0]])
	for i in 60:
		await physics_frame
	var leg := (room.guard.route[1] - room.guard.route[0]).normalized()
	var moved := room.guard.position - start
	_check(moved.length() > 0.5 * Guard.PATROL_SPEED and is_equal_approx(moved.normalized().dot(leg), 1.0), name, "after 1 s the guard moved %s, not along its first leg %s" % [moved, leg])
	_check(room.guard.facing.is_equal_approx(leg), name, "the guard faces %s while walking %s" % [room.guard.facing, leg])


## A glimpse (suspicion below Detection.SEEN_AT) keeps the unseen star; seen until the eye
## is half full, the mime counts as seen.
func _test_glimpse_keeps_unseen_star() -> void:
	var name := "glimpse_keeps_unseen_star"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(200, 460), Vector2.RIGHT, Vector2(370, 460))
	await _wait_until(func() -> bool: return room.guard.suspicion > 0.1, 60)
	room.mime.visible = false
	await physics_frame
	_check(room.guard.suspicion > 0.0 and not room.ever_seen, name, "a glimpse (suspicion %.2f) cost the unseen star" % room.guard.suspicion)
	room.mime.visible = true
	var seen := await _wait_until(func() -> bool: return room.ever_seen, 120)
	_check(seen and room.guard.suspicion >= Detection.SEEN_AT and room.guard.suspicion < 1.0, name, "the mime was not counted as seen when the eye reached half (suspicion %.2f, seen %s)" % [room.guard.suspicion, room.ever_seen])


## Seen in the open, the mime is caught and tossed to the entrance; taps are ignored
## during the toss; then the guard restarts its route and the timer has kept running.
func _test_guard_sees_and_tosses() -> void:
	var name := "guard_sees_and_tosses"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(200, 460), Vector2.RIGHT, Vector2(300, 460))
	var frames := 0
	while not room.tossing and frames < 120:
		await physics_frame
		frames += 1
	_check(room.tossing and room.catches == 1, name, "a mime 100 units ahead in the open was not caught within 2 s (suspicion %.2f)" % room.guard.suspicion)
	_check(room.ever_seen, name, "the room did not record that the mime was seen")
	_check(not room.guard.active, name, "the guard keeps looking during the toss")
	var caught_at := room.elapsed
	await _tap_at(Vector2(600, 480))
	_check(not room.mime.walking, name, "a tap during the toss started a walk")
	frames = 0
	while room.tossing and frames < 180:
		await physics_frame
		frames += 1
	_check(not room.tossing, name, "the toss did not end within 3 s")
	_check(room.mime.position == room.entrance and room.mime.rotation == 0.0, name, "after the toss the mime is at %s (rotation %f), not upright at the entrance" % [room.mime.position, room.mime.rotation])
	_check(room.guard.active and room.guard.suspicion == 0.0 and room.guard.position == room.guard.route[0], name, "the guard was not reset to its route's start, calm")
	_check(room.elapsed - caught_at >= Room.TOSS_SHAKE + Room.TOSS_FLIGHT - 0.05, name, "the timer stopped during the toss (%.2f s passed)" % (room.elapsed - caught_at))


## The partition blocks sight: a mime behind it within range is never seen, while the
## same distance across open floor is.
func _test_guard_partition_blocks_sight() -> void:
	var name := "guard_partition_blocks_sight"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(390, 330), Vector2.RIGHT, Vector2(566, 330))
	for i in 90:
		await physics_frame
	_check(room.guard.suspicion == 0.0 and not room.ever_seen, name, "the guard saw the mime through the partition (suspicion %.2f)" % room.guard.suspicion)
	room.guard.position = Vector2(390, 470)
	_check(room.guard.can_see(Vector2(566, 470)), name, "the guard cannot see the same distance across open floor (the control case)")


## At a waypoint the guard pauses still facing the leg it walked, then turns to the next
## standing before it walks on.
func _test_guard_pauses_facing_its_leg() -> void:
	var name := "guard_pauses_facing_its_leg"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var corner := room.guard.route[1]
	var reached := await _wait_until(func() -> bool: return room.guard.position == corner, 600)
	_check(reached, name, "the guard never reached its second waypoint %s" % corner)
	var first_leg := (corner - room.guard.route[0]).normalized()
	for i in roundi(Guard.WAYPOINT_PAUSE * 60.0) - 4:
		await physics_frame
	_check(room.guard.position == corner and room.guard.facing.is_equal_approx(first_leg), name, "during the pause the guard faces %s, not its finished leg %s" % [room.guard.facing, first_leg])
	for i in 6:
		await physics_frame
	var next_leg := (room.guard.route[2] - corner).normalized()
	# It turns toward the next leg at TURN_RATE: not snapped, and there within the turn's time.
	_check(not room.guard.facing.is_equal_approx(next_leg), name, "the guard snapped to its next leg instead of turning")
	_check(room.guard.position == corner, name, "the guard walked off at %s mid-turn (sideways to the way it faces)" % room.guard.position)
	for i in ceili(absf(first_leg.angle_to(next_leg)) / Guard.TURN_RATE * 60.0) + 2:
		await physics_frame
	_check(room.guard.facing.is_equal_approx(next_leg), name, "after the pause and its turn the guard faces %s, not its next leg %s" % [room.guard.facing, next_leg])


## A guard turns toward a new heading at TURN_RATE, never snapping: a noise behind it turns
## it round on the spot (until within TURN_IN_PLACE), then it walks; its sight
## and its drawing turn with it.
func _test_guard_turns_smoothly() -> void:
	var name := "guard_turns_smoothly"
	var room := await _load_room()
	if room == null:
		return
	room.mime.place_at(Vector2(70, 470))
	room.mime.visible = false
	_stand(room.guard, Vector2(700, 470), Vector2.RIGHT)
	await physics_frame
	var noise := Vector2(400, 470)
	room.guard.hear(noise)
	await physics_frame
	await physics_frame
	var turned := absf(Vector2.RIGHT.angle_to(room.guard.facing))
	_check(turned > 0.0 and turned < PI / 2.0, name, "two frames after a noise behind it the guard has turned %.2f rad (snapped, or not turning)" % turned)
	_check(room.guard.position == Vector2(700, 470), name, "the guard walked off before turning round (at %s)" % room.guard.position)
	_check(room.guard.can_see(Vector2(780, 470)), name, "mid-turn the guard no longer sees straight ahead where it still half faces")
	for i in ceili(PI / Guard.TURN_RATE * 60.0) + 2:
		await physics_frame
	_check(room.guard.facing.is_equal_approx(Vector2.LEFT) and room.guard.position.x < 700.0, name, "after a half turn's time the guard faces %s at %s, not walking left to the noise" % [room.guard.facing, room.guard.position])
	_check(room.guard.can_see(Vector2(620, 470)) and not room.guard.can_see(Vector2(780, 470)), name, "the guard's sight did not turn with it")
	_check(room.guard.rig.view == CharacterRig.View.LEFT and room.guard.rig.stride > 0.0, name, "walking left the guard's drawing shows %s (stride %.2f)" % [CharacterRig.View.keys()[room.guard.rig.view], room.guard.rig.stride])
	room.mime.visible = true


## A catch mid-swap cancels the swap. A catch while carrying keeps the original (only the
## guard resets): the mime still escapes, and being seen costs the unseen star.
func _test_catches_during_swap_and_while_carrying() -> void:
	var name := "catches_during_swap_and_while_carrying"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room._on_painted(Forgery.ASSIST_QUALITY)
	await _tap_at(room.painting_rect().get_center())
	await _wait_until(func() -> bool: return room.mime.swap_progress > 0.3, 900)
	await _tap_at(room.painting_rect().get_center())
	_check(room.mime.swap_progress > 0.3 and room.swap_intent, name, "a second tap on the painting restarted the swap")
	room.guard.active = true
	_stage_guard(room, room.mime.position + Vector2(-80, 0), Vector2.RIGHT, room.mime.position)
	await _wait_until(func() -> bool: return room.tossing, 120)
	_check(room.tossing and room.mime.swap_progress == 0.0 and not room.swap_intent, name, "a catch mid-swap did not cancel it")
	await _wait_until(func() -> bool: return not room.tossing, 180)
	room.guard.active = false
	room.mime.place_at(room.swap_spot())
	room._on_painted(Forgery.ASSIST_QUALITY)
	room.swap_intent = true
	await _wait_until(func() -> bool: return room.mime.carrying, 180)
	room.guard.active = true
	_stage_guard(room, Vector2(700, 330), Vector2.RIGHT, Vector2(780, 330))
	await _wait_until(func() -> bool: return room.tossing, 120)
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_check(room.mime.carrying and room.exit_door.glowing, name, "a catch while carrying took the original away")
	room.guard.active = false
	await _tap_at(Vector2(950, 330))
	var escaped := await _wait_until(func() -> bool: return room.finished, 900)
	_check(escaped and room.stars[Stars.Star.SWAP] and not room.stars[Stars.Star.UNSEEN], name, "after being seen the escape earned %s (escaped %s)" % [room.stars, escaped])


func _test_guard_ignores_behind() -> void:
	var name := "guard_ignores_behind"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(300, 460), Vector2.RIGHT, Vector2(220, 460))
	for i in 60:
		await physics_frame
	_check(room.guard.suspicion == 0.0 and not room.ever_seen, name, "the guard saw the mime behind it (suspicion %.2f)" % room.guard.suspicion)


## Full suspicion starts a chase at CHASE_SPEED (slower than the mime); out of sight
## behind the partition for CHASE_MEMORY, the guard searches the last-seen spot, gives up
## after SEARCH_TIME and walks back onto its route.
func _test_guard_chase_search_return() -> void:
	var name := "guard_chase_search_return"
	_check(Guard.CHASE_SPEED < Mime.SPEED, name, "the guard chases at %.0f, not slower than the mime (%.0f)" % [Guard.CHASE_SPEED, Mime.SPEED])
	var room := await _load_room()
	if room == null:
		return
	room.guard.position = Vector2(300, 250)
	room.guard.facing = Vector2.RIGHT
	room.mime.place_at(Vector2(420, 250))
	var chasing := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.CHASE, 120)
	_check(chasing, name, "a guard watching the mime never gave chase (suspicion %.2f)" % room.guard.suspicion)
	var seen_at := room.guard.last_seen
	# Behind the partition, out of the guard's sight.
	room.mime.place_at(Vector2(480, 420))
	var from := room.guard.position
	for i in 15:
		await physics_frame
	var moved := room.guard.position.distance_to(from)
	_check(absf(moved - Guard.CHASE_SPEED * 0.25) < 4.0, name, "the chasing guard moved %.1f in 0.25 s, not CHASE_SPEED (%.1f)" % [moved, Guard.CHASE_SPEED * 0.25])
	var searching := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.SEARCH, ceili(GuardBrain.CHASE_MEMORY * 60.0) + 30)
	_check(searching and room.guard.search_point == seen_at, name, "out of sight the guard is %s around %s, not searching where it last saw the mime (%s)" % [_intent_name(room.guard.intent), room.guard.search_point, seen_at])
	_check(not room.tossing, name, "the guard caught a mime it could not see")
	var patrolling := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.PATROL, ceili(Guard.SEARCH_TIME * 60.0) + 240)
	_check(patrolling, name, "the search never ended (intent %s)" % _intent_name(room.guard.intent))
	var next_waypoint := room.guard.route[1]
	var back := await _wait_until(func() -> bool: return room.guard.position.is_equal_approx(next_waypoint), 600)
	_check(back, name, "the guard did not walk back to its next waypoint %s (at %s)" % [next_waypoint, room.guard.position])


## Tapping a frame walks the mime under it and tilts it; a guard in earshot investigates,
## straightens it and goes back to patrolling; one out of earshot hears nothing, and a
## tilted frame is not a tilt target.
func _test_tilt_decoy_investigated() -> void:
	var name := "tilt_decoy_investigated"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	_stage_guard(room, Vector2(660, 430), Vector2.LEFT, room.entrance)
	var frame := room.get_node("Frames/FrameB") as TiltFrame
	await _tap_at(frame.position)
	_check(room.tilt_target == frame, name, "a tap on the frame did not make it the tilt target")
	_check(await _wait_until(func() -> bool: return frame.tilted, 600), name, "the mime never tilted the frame (at %s)" % room.mime.position)
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.INVESTIGATE, 10), name, "the guard in earshot did not investigate (intent %s)" % _intent_name(room.guard.intent))
	await _tap_at(frame.position)
	_check(room.tilt_target == null, name, "a tilted frame became a tilt target")
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.STRAIGHTEN, 900), name, "the guard never went to straighten the frame (intent %s, at %s)" % [_intent_name(room.guard.intent), room.guard.position])
	var straighten_frames := 0
	while frame.tilted and straighten_frames < 600:
		await physics_frame
		straighten_frames += 1
	_check(not frame.tilted, name, "the guard never straightened the frame (intent %s, at %s)" % [_intent_name(room.guard.intent), room.guard.position])
	_check(straighten_frames >= roundi(Guard.STRAIGHTEN_TIME * 60.0) - 2, name, "the frame was straightened %d frames after STRAIGHTEN began, under STRAIGHTEN_TIME" % straighten_frames)
	await physics_frame
	_check(room.guard.intent == GuardBrain.Intent.PATROL, name, "after straightening the guard is %s, not patrolling" % _intent_name(room.guard.intent))
	room.guard.position = Vector2(900, 500)
	_check(not room.guard.hear(Vector2(100, 180)), name, "a guard %.0f away heard a noise (range %.0f)" % [Vector2(900, 500).distance_to(Vector2(100, 180)), GuardBrain.HEARING_RANGE])


## A tilted frame pulls only the nearest guard in earshot (AC 23); with that one out of
## action the next nearest hears it, and nobody beyond HEARING_RANGE does.
func _test_decoy_pulls_nearest_guard() -> void:
	var name := "decoy_pulls_nearest_guard"
	var room := await _load_two_guard_room(PackedVector2Array([Vector2(300, 430), Vector2(300, 250)]))
	if room == null:
		return
	var near := room.guard
	var far := room.get_node("Actors/Guard2") as Guard
	_check(room.guards == ([near, far] as Array[Guard]), name, "the room's guards are %s" % [room.guards])
	for each in room.guards:
		each.target = null
	_stand(near, Vector2(660, 430), Vector2.DOWN)
	_stand(far, Vector2(300, 430), Vector2.DOWN)
	room.mime.place_at(room.entrance)
	var frame := room.get_node("Frames/FrameB") as TiltFrame
	await _tap_at(frame.position)
	_check(await _wait_until(func() -> bool: return frame.tilted, 600), name, "the mime never tilted the frame")
	await physics_frame
	_check(near.senses.noise_heard and near.intent == GuardBrain.Intent.INVESTIGATE, name, "the nearest guard did not investigate (intent %s)" % _intent_name(near.intent))
	_check(not far.senses.noise_heard and far.intent == GuardBrain.Intent.PATROL, name, "the farther guard in earshot was pulled too (intent %s)" % _intent_name(far.intent))
	near.active = false
	_check(room.nearest_in_earshot(frame.view_point()) == far, name, "with the nearest guard out of action the next nearest is not pulled")
	far.position = Vector2(900, 520)
	_check(room.nearest_in_earshot(Vector2(100, 180)) == null, name, "a guard beyond HEARING_RANGE was pulled")


## Stepping into a portrait is checked against every guard: one that sees it (not the
## first) chases to it, the mime counts as seen, and a guard that saw nothing stays calm.
func _test_hiding_checks_every_guard() -> void:
	var name := "hiding_checks_every_guard"
	var room := await _load_two_guard_room(PackedVector2Array([Vector2(250, 250), Vector2(400, 250)]))
	if room == null:
		return
	var blind := room.guard
	var watching := room.get_node("Actors/Guard2") as Guard
	_stand(blind, Vector2(660, 430), Vector2.RIGHT)
	_stand(watching, Vector2(240, 230), Vector2.LEFT)
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	room.mime.place_at(portrait.spot())
	room.hide_target = portrait
	await physics_frame
	_check(room.hidden_in == portrait, name, "the mime did not step into the portrait")
	_check(room.ever_seen and watching.senses.chasing, name, "the second guard saw the mime step in but does not chase (seen %s)" % room.ever_seen)
	_check(not blind.senses.chasing, name, "the guard facing away chases")


## A catch by any guard tosses the mime, and the toss resets every guard to its route.
func _test_second_guard_catches_and_resets_all() -> void:
	var name := "second_guard_catches_and_resets_all"
	var route := PackedVector2Array([Vector2(500, 450), Vector2(800, 450)])
	var room := await _load_two_guard_room(route)
	if room == null:
		return
	var second := room.get_node("Actors/Guard2") as Guard
	room.guard.position = Vector2(400, 400)
	second.position = Vector2(600, 300)
	second.caught.emit()
	_check(room.tossing and room.catches == 1, name, "a catch by the second guard did not toss the mime")
	_check(await _wait_until(func() -> bool: return not room.tossing, 120), name, "the toss never ended")
	_check(room.guard.position.is_equal_approx(room.guard.route[0]) and second.position.is_equal_approx(route[0]), name, "after the toss the guards are at %s and %s, not their routes' starts" % [room.guard.position, second.position])
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	_check(canvas.watchers == room.guards, name, "the canvas eye does not watch every guard")


## Every guard watches the hung fake; the one whose inspection finds it out searches, the
## other does not, and nobody watches it after.
func _test_fake_found_out_by_one_guard() -> void:
	var name := "fake_found_out_by_one_guard"
	var room := await _load_two_guard_room(PackedVector2Array([Vector2(500, 450), Vector2(800, 450)]))
	if room == null:
		return
	var second := room.get_node("Actors/Guard2") as Guard
	room.fake_quality = 0.1
	room.mime.has_fake = true
	room._swap()
	_check(room.guard.watches_fake and second.watches_fake, name, "not every guard watches the hung fake")
	room._on_inspected(second)
	_check(room.found_out and second.senses.search_left > 0.0, name, "the guard who found the Sloppy fake out does not search")
	_check(room.guard.senses.search_left == 0.0, name, "the other guard searches too")
	_check(not room.guard.watches_fake and not second.watches_fake, name, "a guard still watches a found-out fake")


## A guard that sees a tilted frame without hearing it walks over and straightens it.
func _test_tilted_frame_seen_and_straightened() -> void:
	var name := "tilted_frame_seen_and_straightened"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var frame := room.get_node("Frames/FrameA") as TiltFrame
	frame.tilt()
	_stage_guard(room, Vector2(frame.position.x, 260), Vector2.UP, room.entrance)
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.STRAIGHTEN, 10), name, "a guard facing a tilted frame did not go to straighten it (intent %s)" % _intent_name(room.guard.intent))
	var straightened := await _wait_until(func() -> bool: return not frame.tilted, ceili(Guard.STRAIGHTEN_TIME * 60.0) + 120)
	_check(straightened and not room.guard.senses.tilted_frame_known, name, "the seen frame was not straightened")


## Hiding unseen: the mime steps into the portrait (gone, its face on the sitter) and a
## guard staring at it from close by builds no suspicion; a floor tap steps it out.
func _test_hide_unseen_and_step_out() -> void:
	var name := "hide_unseen_and_step_out"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(500, 430), Vector2.RIGHT, room.entrance)
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	await _tap_at(portrait.position)
	var hid := await _wait_until(func() -> bool: return room.hidden_in == portrait, 600)
	_check(hid and not room.mime.visible and portrait.occupied and (portrait.get_node("MimeFace") as Sprite2D).visible, name, "tapping the portrait did not hide the mime in it (hidden in %s, visible %s)" % [room.hidden_in, room.mime.visible])
	var view := room.get_node("StyleLayer/StyleView") as ColorRect
	var style := view.material as ShaderMaterial
	_check(view.visible and style != null and style.shader == Paintings.STYLES[StringName(portrait.painting)] and style.get_shader_parameter(&"use_screen") == true, name, "inside the portrait the room is not seen in its %s style" % portrait.painting)
	room.guard.position = portrait.spot() + Vector2(100, 0)
	room.guard.facing = Vector2.LEFT
	for i in 60:
		await physics_frame
	_check(room.guard.suspicion == 0.0 and not room.guard.senses.chasing, name, "a guard facing the hidden mime from 100 away grew suspicious (%.2f)" % room.guard.suspicion)
	room.guard.position = Vector2(500, 430)
	room.guard.facing = Vector2.RIGHT
	await _tap_at(Vector2(300, 480))
	_check(room.hidden_in == null and room.mime.visible and not portrait.occupied and room.mime.walking and not view.visible, name, "a floor tap did not step the mime out (and out of the style view) and walk it")


## The view from inside a portrait covers the whole visible screen, not just the 960x540
## base (expand aspect shows more on wide phones).
func _test_hide_view_fills_screen() -> void:
	var name := "hide_view_fills_screen"
	var room := await _load_room()
	if room == null:
		return
	var view := room.get_node("StyleLayer/StyleView") as ColorRect
	root.size = Vector2i(1170, 540)
	await process_frame
	var visible_rect := room.get_viewport().get_visible_rect()
	_check(view.get_global_rect().is_equal_approx(visible_rect), name, "on a 19.5:9 screen the view is %s, not the visible %s" % [view.get_global_rect(), visible_rect])
	root.size = BASE_WINDOW
	await process_frame


## A portrait naming an unknown painting still hides the mime, but reports the painting and
## never covers the room with the view's bare rect.
func _test_hide_unknown_painting_reports() -> void:
	var name := "hide_unknown_painting_reports"
	var room := await _load_room()
	if room == null:
		return
	_stage_guard(room, Vector2(500, 430), Vector2.RIGHT, room.entrance)
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	portrait.painting = "no_such_painting"
	await _tap_at(portrait.position)
	var hid := await _wait_until(func() -> bool: return room.hidden_in == portrait, 600)
	_game.quiet_errors = false
	var reported := _game.errors.slice(errors_before).any(func(e: String) -> bool: return "has no style" in e and "no_such_painting" in e)
	_check(hid and reported, name, "hiding in a portrait with an unknown painting was not reported (hid %s, errors %s)" % [hid, _game.errors.slice(errors_before)])
	_check(not (room.get_node("StyleLayer/StyleView") as ColorRect).visible, name, "the style view covers the room without a style")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false


## A guard who sees the mime step into a portrait chases it there and pulls it out (a
## catch); after the toss the mime is out and visible.
func _test_guard_saw_hiding_pulls_out() -> void:
	var name := "guard_saw_hiding_pulls_out"
	var room := await _load_room()
	if room == null:
		return
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	_stage_guard(room, portrait.spot() + Vector2(110, 0), Vector2.LEFT, portrait.spot())
	await _tap_at(portrait.position)
	_check(await _wait_until(func() -> bool: return room.hidden_in == portrait, 30), name, "the mime did not hide")
	_check(room.guard.senses.chasing, name, "the guard that watched the mime hide did not give chase")
	_check(room.ever_seen, name, "being seen going in did not cost the unseen star")
	_check(await _wait_until(func() -> bool: return room.tossing, 240), name, "the guard never pulled the hidden mime out (intent %s, at %s)" % [_intent_name(room.guard.intent), room.guard.position])
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_check(room.mime.visible and room.hidden_in == null and not portrait.occupied and not (room.get_node("StyleLayer/StyleView") as ColorRect).visible, name, "after the toss the mime is still hidden")


## The guard's intent icon pops in for each intent but patrol; the debug overlay is off
## unless asked for, and draws the guards' paths and scores without errors when on.
func _test_intent_icons_and_overlay() -> void:
	var name := "intent_icons_and_overlay"
	var room := await _load_room()
	if room == null:
		return
	var icon := room.guard.get_node("IntentIcon") as Sprite2D
	_check(not icon.visible, name, "a patrolling guard shows an intent icon")
	_check(room.get_node_or_null("DebugOverlay") == null, name, "the debug overlay is on without --debug-overlay")
	var overlay := room.add_debug_overlay()
	room.guard.target = null
	room.guard.position = Vector2(660, 430)
	room.guard.hear(Vector2(610, 180))
	for i in 20:
		await physics_frame
	_check(room.guard.intent == GuardBrain.Intent.INVESTIGATE and icon.visible and icon.texture == Guard.INTENT_ICONS[GuardBrain.Intent.INVESTIGATE] and icon.scale.is_equal_approx(Vector2.ONE * Guard.ICON_SCALE), name, "an investigating guard does not show the ear icon at full size (intent %s)" % _intent_name(room.guard.intent))
	_check(room.guard.nav_path().size() > 1 and overlay.guards == [room.guard], name, "the overlay has no guard path to draw")
	await process_frame
	_check(_game.errors.is_empty(), name, "drawing the overlay reported errors: %s" % [_game.errors])


## A physical key pressed or released, as a keyboard would.
func _key(keycode: Key, pressed: bool) -> void:
	var key := InputEventKey.new()
	key.physical_keycode = keycode
	key.pressed = pressed
	Input.parse_input_event(key)
	await process_frame


## The arrows walk the mime at SPEED; W walks it up but never off the navmesh; E opens the
## easel's canvas next to it, hides it in a portrait next to it, and steps it out again.
func _test_keyboard_walks_and_interacts() -> void:
	var name := "keyboard_walks_and_interacts"
	# A nudge while the map holds no navmesh (its queries answer (0, 0) then) leaves the
	# mime where it is.
	if current_scene != null:
		current_scene.free()
	# The map drops the freed room's navmesh at the sync after the next physics step.
	await physics_frame
	await physics_frame
	var lone := (load("res://scenes/mime.tscn") as PackedScene).instantiate() as Mime
	root.add_child(lone)
	lone.place_at(Vector2(70, 330))
	lone.nudge(Vector2.RIGHT, 1.0 / 60.0)
	_check(lone.position == Vector2(70, 330), name, "a nudge without a navmesh moved the mime to %s" % lone.position)
	lone.free()
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var from := room.mime.position
	Input.action_press("ui_right")
	for i in 30:
		await physics_frame
	Input.action_release("ui_right")
	var moved := room.mime.position - from
	_check(absf(moved.x - Mime.SPEED * 0.5) < 4.0 and absf(moved.y) < 0.5, name, "holding right for 0.5 s moved the mime %s, not %.0f right" % [moved, Mime.SPEED * 0.5])
	await _key(KEY_W, true)
	for i in 120:
		await physics_frame
	await _key(KEY_W, false)
	_check(room.mime.position.y < from.y - 100.0 and room.mime.position.y >= FLOOR_TOP - 0.5, name, "holding W left the mime at %s (expected well up, but on the floor)" % room.mime.position)
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	room.mime.place_at(room.easel.spot() + Vector2(40, 0))
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	_check(await _wait_until(func() -> bool: return canvas.visible, 120), name, "E beside the easel did not open the canvas")
	canvas.close()
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	room.mime.place_at(portrait.spot() + Vector2(40, 0))
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	_check(await _wait_until(func() -> bool: return room.hidden_in == portrait, 120), name, "E beside the portrait did not hide the mime in it")
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	_check(room.hidden_in == null and room.mime.visible, name, "E while hidden did not step the mime out")
	# Out of reach of everything usable, E shrugs with a sound and goes nowhere.
	var lonely := Vector2(300, 470)
	var in_reach := room._usables().filter(func(usable: Array) -> bool: return lonely.distance_to(usable[0]) <= Room.INTERACT_REACH)
	_check(in_reach.is_empty(), name, "the test's lonely spot %s has something in reach: %s" % [lonely, in_reach])
	room.mime.place_at(lonely)
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	var rig := room.mime.rig
	var shrugged := await _wait_until(func() -> bool: return rig.squash.y < 1.0, 10)
	_check(shrugged and _game.audio.played.slice(-4).has(&"shrug"), name, "E with nothing in reach did not shrug with its sound")
	_check(not room.mime.walking, name, "E with nothing in reach walked the mime")
	_check(await _wait_until(func() -> bool: return rig.squash == Vector2.ONE, ceili(Mime.SHRUG_TIME * 60.0) + 10), name, "the shrug did not settle")


## A guard that saw the mime hide loses it like any other once it steps out and gets away
## unseen: it searches the hiding place instead of chasing forever.
func _test_guard_loses_mime_after_hiding() -> void:
	var name := "guard_loses_mime_after_hiding"
	var room := await _load_room()
	if room == null:
		return
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	_stage_guard(room, portrait.spot() + Vector2(110, 0), Vector2.LEFT, portrait.spot())
	await _tap_at(portrait.position)
	_check(await _wait_until(func() -> bool: return room.hidden_in == portrait, 30) and room.guard.senses.chasing, name, "the guard did not see the mime hide")
	# Out again and behind the partition, out of the guard's sight.
	room._step_out()
	room.mime.place_at(Vector2(480, 380))
	var searching := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.SEARCH, ceili(GuardBrain.CHASE_MEMORY * 60.0) + 120)
	_check(searching and not room.tossing, name, "after the mime stepped out unseen the guard is %s (tossing %s), not searching" % [_intent_name(room.guard.intent), room.tossing])


## A chasing guard that did not see the mime hide passes the portrait it hides in: no
## catch, and it gives up into a search.
func _test_guard_ignores_unseen_hiding() -> void:
	var name := "guard_ignores_unseen_hiding"
	var room := await _load_room()
	if room == null:
		return
	var portrait := room.get_node("Portraits/PortraitA") as HidingPortrait
	_stage_guard(room, portrait.spot() + Vector2(150, 0), Vector2.RIGHT, portrait.spot())
	await _tap_at(portrait.position)
	_check(await _wait_until(func() -> bool: return room.hidden_in == portrait, 30) and not room.guard.senses.chasing, name, "the mime did not hide unseen")
	room.guard.senses.chasing = true
	room.guard.senses.lost_sight_for = 0.0
	room.guard.last_seen = portrait.spot()
	var searching := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.SEARCH, ceili(GuardBrain.CHASE_MEMORY * 60.0) + 60)
	_check(searching and not room.tossing and room.hidden_in == portrait, name, "a guard that never saw the mime hide caught it (tossing %s, intent %s)" % [room.tossing, _intent_name(room.guard.intent)])


## A noise with nothing to straighten there: the guard walks to it, looks, and goes back
## to patrolling.
func _test_investigate_without_frame() -> void:
	var name := "investigate_without_frame"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	_stage_guard(room, Vector2(660, 430), Vector2.LEFT, room.entrance)
	room.guard.hear(Vector2(450, 200))
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.INVESTIGATE, 10), name, "the guard did not investigate the noise")
	var done := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.PATROL, 600)
	_check(done and not room.guard.senses.noise_heard and room.guard.position.distance_to(Vector2(450, 200)) < 10.0, name, "the guard did not reach the noise and go back to patrolling (intent %s, at %s)" % [_intent_name(room.guard.intent), room.guard.position])


## A tilt heard from close by (investigating beats straightening): the guard walks right
## under the frame, and straightening there still takes STRAIGHTEN_TIME.
func _test_close_noise_straighten_takes_time() -> void:
	var name := "close_noise_straighten_takes_time"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var frame := room.get_node("Frames/FrameB") as TiltFrame
	_stage_guard(room, frame.view_point() + Vector2(0, 150), Vector2.DOWN, room.entrance)
	frame.tilt()
	room.guard.hear(frame.view_point())
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.INVESTIGATE, 10), name, "a close noise did not start an investigation (intent %s)" % _intent_name(room.guard.intent))
	_check(await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.STRAIGHTEN, 600), name, "the guard never went to straighten the frame")
	var frames := 0
	while frame.tilted and frames < 600:
		await physics_frame
		frames += 1
	_check(not frame.tilted and frames >= roundi(Guard.STRAIGHTEN_TIME * 60.0) - 2, name, "the frame was straightened %d frames after STRAIGHTEN began, under STRAIGHTEN_TIME" % frames)


## A goal reached once is walked to again, not "arrived at" on the spot: the same noise
## investigated twice, and the same frame straightened twice, from across the room.
func _test_guard_returns_to_reached_goals() -> void:
	var name := "guard_returns_to_reached_goals"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	room.guard.patrolling = false
	var noise := Vector2(450, 200)
	for visit in 2:
		room.guard.position = Vector2(660, 430)
		room.guard.hear(noise)
		var reached := await _wait_until(func() -> bool: return not room.guard.senses.noise_heard, 600)
		_check(reached and room.guard.position.distance_to(noise) < 10.0, name, "investigation %d ended at %s, not at the noise %s" % [visit + 1, room.guard.position, noise])
	var frame := room.get_node("Frames/FrameA") as TiltFrame
	for visit in 2:
		frame.tilt()
		room.guard.position = Vector2(frame.position.x, 340)
		room.guard.facing = Vector2.UP
		var straightened := await _wait_until(func() -> bool: return not frame.tilted, 600)
		_check(straightened and room.guard.position.distance_to(frame.view_point()) < 10.0, name, "straighten %d happened with the guard at %s, not under the frame" % [visit + 1, room.guard.position])


## A noise off the navmesh (on the wall) is investigated at the nearest floor point and
## ends; a chase re-plans its path only as the mime moves CHASE_REPATH, not every tick.
func _test_off_mesh_noise_and_chase_repath() -> void:
	var name := "off_mesh_noise_and_chase_repath"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	_stage_guard(room, Vector2(450, 260), Vector2.UP, room.entrance)
	room.guard.hear(Vector2(450, 100))
	var done := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.PATROL and not room.guard.senses.noise_heard, 300)
	_check(done and room.guard.position.y < 190.0, name, "a noise on the wall was not investigated at the wall's foot and ended (intent %s, at %s)" % [_intent_name(room.guard.intent), room.guard.position])
	room.guard.target = room.mime
	_stage_guard(room, Vector2(300, 460), Vector2.RIGHT, Vector2(400, 460))
	await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.CHASE, 120)
	var agent := room.guard.get_node("Agent") as NavigationAgent2D
	var paths: Array[int] = [0]
	agent.path_changed.connect(func() -> void: paths[0] += 1)
	room.mime.walk_to(Vector2(900, 460))
	for i in 30:
		await physics_frame
	var expected := ceili(Mime.SPEED * 0.5 / Guard.CHASE_REPATH) + 2
	_check(paths[0] > 0 and paths[0] <= expected, name, "the chase changed its path %d times in 30 ticks (expected 1..%d)" % [paths[0], expected])
	room.mime.place_at(room.mime.position)


## Taps the centre of `control`, as a finger would.
func _tap_control(control: Control) -> void:
	await _tap_at(control.get_global_rect().get_center())


## Waits (at most `max_frames` frames) until `done` returns true; returns whether it did.
func _wait_until(done: Callable, max_frames: int) -> bool:
	for i in max_frames:
		if done.call():
			return true
		await physics_frame
	return done.call()


## The title hangs the logo, swaying gently on its nail; Reduce Motion holds it still.
func _test_title_logo_sways() -> void:
	var name := "title_logo_sways"
	change_scene_to_file(TITLE_PATH)
	await process_frame
	await process_frame
	var logo := current_scene.get_node_or_null("Logo") as TextureRect
	_check(logo != null and logo.texture != null and logo.visible, name, "the title shows no logo")
	if logo == null:
		return
	for i in 30:
		await process_frame
	_check(absf(logo.rotation) > 0.0, name, "the logo does not sway")
	var limit: float = (current_scene.get_script() as Script).get_script_constant_map()["SWAY_DEGREES"]
	_check(absf(logo.rotation) <= deg_to_rad(limit) + 0.0001, name, "the logo sways %.2f degrees, past its %.1f" % [rad_to_deg(absf(logo.rotation)), limit])
	_game.save["settings"]["reduce_motion"] = true
	await process_frame
	_check(logo.rotation == 0.0, name, "the logo still sways under Reduce Motion")
	_game.save["settings"]["reduce_motion"] = false


## Every action answers at once: a tap ripples where it lands, the walking mime bobs and
## settles when it stops, a pressed button dips and springs back (even when it pauses the
## tree), a swap punches the camera in and a catch shakes the screen, both easing back to
## the world's place; Reduce Motion stops the shake and the punch.
func _test_juice_on_actions() -> void:
	var name := "juice_on_actions"
	var room := await _load_room()
	room.guard.active = false
	var target := room.mime.position + Vector2(160, 0)
	await _tap_at(target)
	var ripple := room.get_node_or_null("TapRipple") as TapRipple
	_check(ripple != null and ripple.position.is_equal_approx(target), name, "a floor tap left no ripple where it landed")
	var bobbed := false
	for i in 20:
		await physics_frame
		await process_frame
		bobbed = bobbed or room.get_node("Actors/Mime/Rig/Body").position.y < 0.0
	_check(bobbed, name, "the walking mime does not bob")
	await _walk_trace(room.mime, 300)
	for i in 6:
		await process_frame
	_check(room.get_node("Actors/Mime/Rig/Body").position.y == 0.0, name, "the mime still bobs standing still")
	_check(room.get_node_or_null("TapRipple") == null, name, "the ripple outlived its %.2f s" % TapRipple.LIFE)
	var pause_button := room.get_node("PauseButton") as Button
	pause_button.button_down.emit()
	await process_frame
	await process_frame
	_check(pause_button.scale.x < 1.0, name, "a pressed button does not dip")
	room.pause()
	for i in ceili(GameState.PRESS_TIME * 60.0) + 4:
		await process_frame
	_check(pause_button.scale.is_equal_approx(Vector2.ONE), name, "a button pressed into a pause did not spring back (scale %s)" % pause_button.scale)
	room.pause_menu.resume()
	var rest := Transform2D(0.0, _game.world_offset())
	room.mime.has_fake = true
	room._swap()
	await process_frame
	await process_frame
	_check(_game.jolting() and get_root().canvas_transform.get_scale().x > 1.0, name, "the swap did not punch the camera in")
	await _wait_until(func() -> bool: return not _game.jolting(), 60)
	_check(get_root().canvas_transform.is_equal_approx(rest), name, "the punch did not settle back to the world's place")
	room.guard.caught.emit()
	# process_frame comes before the nodes' _process: the second one follows Game's.
	await process_frame
	await process_frame
	_check(_game.jolting() and not get_root().canvas_transform.origin.is_equal_approx(rest.origin), name, "a catch did not shake the screen")
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_check(get_root().canvas_transform.is_equal_approx(rest), name, "the shake did not settle back to the world's place")
	_game.set_setting("reduce_motion", true)
	room._swap()
	room.guard.caught.emit()
	await process_frame
	await process_frame
	_check(not _game.jolting() and get_root().canvas_transform.is_equal_approx(rest), name, "Reduce Motion still shakes or punches")
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_game.set_setting("reduce_motion", false)
	# Reduce Motion switched on mid-shake (from the pause menu) stops it at once.
	_game.shake(Room.CAUGHT_SHAKE, 1.0)
	_game.set_setting("reduce_motion", true)
	_check(not _game.jolting() and get_root().canvas_transform.is_equal_approx(rest), name, "Reduce Motion did not stop a running shake")
	_game.set_setting("reduce_motion", false)
	# The hub ripples a tap, and E with no door in reach shrugs.
	var hub := await _load_hub()
	hub.mime.place_at(Vector2(480, 470))
	await _tap_at(Vector2(560, 470))
	_check(hub.get_node_or_null("TapRipple") != null, name, "a hub tap left no ripple")
	await _key(KEY_E, true)
	await _key(KEY_E, false)
	_check(await _wait_until(func() -> bool: return hub.mime.rig.squash.y < 1.0, 10), name, "E in the hub with no door in reach did not shrug")


## A rig's view follows the heading: down front, up back, right and left the side view
## (mirrored for left); a diagonal near the boundary keeps the current view (hysteresis); a
## zero heading keeps it too.
func _test_rig_views() -> void:
	var name := "rig_views"
	const V := CharacterRig.View
	var cases: Array[Array] = [
		[Vector2.DOWN, V.FRONT, V.FRONT], [Vector2.UP, V.FRONT, V.BACK], [Vector2.RIGHT, V.FRONT, V.RIGHT],
		[Vector2.LEFT, V.FRONT, V.LEFT], [Vector2.ZERO, V.LEFT, V.LEFT], [Vector2(1, 0.9), V.RIGHT, V.RIGHT],
		[Vector2(1, 0.9), V.FRONT, V.FRONT], [Vector2(1, 1.4), V.RIGHT, V.FRONT], [Vector2(1.4, -1), V.BACK, V.RIGHT],
		[Vector2(-1, 0.2), V.RIGHT, V.LEFT],
	]
	for each in cases:
		var got := CharacterRig.view_for(each[0], each[1])
		_check(got == each[2], name, "heading %s from %s gives %s, not %s" % [each[0], V.keys()[each[1]], V.keys()[got], V.keys()[each[2]]])
	var rig := (load("res://scenes/rig_mime.tscn") as PackedScene).instantiate() as CharacterRig
	root.add_child(rig)
	rig.face(Vector2.LEFT)
	_check(rig.scale.x == -1.0 and (rig.get_node("Body") as Sprite2D).texture == rig.body_side, name, "facing left does not mirror the side view")
	_check((rig.get_node("Leg1/Shin") as Sprite2D).texture == rig.leg_lower_side, name, "the side view's shin is not the side shoe")
	rig.face(Vector2.UP)
	_check(rig.scale.x == 1.0 and (rig.get_node("Body") as Sprite2D).texture == rig.body_back, name, "facing up does not show the back")
	_check((rig.get_node("Leg1/Shin") as Sprite2D).texture == rig.leg_lower, name, "the back view's shin is not the front-and-back shoe")
	rig.free()


## A rig's walk cycle moves only with distance: a footfall setting off and every step_length, limbs swinging
## while walking and settling to rest once it stops.
func _test_rig_walk_cycle() -> void:
	var name := "rig_walk_cycle"
	var rig := (load("res://scenes/rig_mime.tscn") as PackedScene).instantiate() as CharacterRig
	root.add_child(rig)
	rig.face(Vector2.RIGHT)
	var steps := [0]
	rig.stepped.connect(func() -> void: steps[0] += 1)
	var leg := rig.get_node("Leg1") as Sprite2D
	var swung := 0.0
	for i in 60:
		rig.walk(rig.step_length / 10.0, 1.0 / 60.0)
		swung = maxf(swung, absf(leg.rotation))
	_check(steps[0] == 7, name, "setting off and walking 6 steps' length gave %d footfalls, not 7" % steps[0])
	_check(swung > rig.leg_swing * 0.8, name, "the side view's leg swung only %.2f rad" % swung)
	var phase := rig.phase
	for i in 30:
		rig.walk(0.0, 1.0 / 60.0)
	_check(rig.phase == phase and rig.stride == 0.0 and leg.rotation == 0.0, name, "standing still the cycle moved or the limbs did not settle (stride %.2f, leg %.2f)" % [rig.stride, leg.rotation])
	rig.free()


## Every limb of both rigs is two parts at a joint (upper arm and forearm, thigh and shin),
## drawn from SVGs imported at ART_SCALE; walking bends every knee and elbow in every view
## (front, back, side, mirrored left), and standing still straightens them all; the bend
## leaves the footfalls' timing as it was.
func _test_rig_joints_bend() -> void:
	var name := "rig_joints_bend"
	const V := CharacterRig.View
	for path: String in ["res://scenes/rig_mime.tscn", "res://scenes/rig_guard.tscn"]:
		var rig := (load(path) as PackedScene).instantiate() as CharacterRig
		root.add_child(rig)
		var joints: Array[Sprite2D] = []
		for limb: String in ["Arm0/Forearm", "Arm1/Forearm", "Leg0/Shin", "Leg1/Shin"]:
			var lower := rig.get_node_or_null(limb) as Sprite2D
			_check(lower != null and lower.get_parent() is Sprite2D, name, "%s has no %s on an upper part" % [path, limb])
			if lower != null:
				joints.append(lower)
		if joints.size() < 4:
			rig.free()
			continue
		var body := rig.get_node("Body") as Sprite2D
		# Imported at 1x the body would be no taller than its feet anchor in base units.
		_check(body.scale == Vector2.ONE / CharacterRig.ART_SCALE and rig.body_front.get_height() > rig.feet_at.y * CharacterRig.ART_SCALE * 0.9, name, "%s's body is not imported at ART_SCALE and drawn back at its inverse (%s, scale %s)" % [path, rig.body_front.get_size(), body.scale])
		for view: V in [V.FRONT, V.BACK, V.RIGHT, V.LEFT]:
			rig.face(([Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT] as Array[Vector2])[view])
			_check(rig.view == view, name, "%s did not turn to %s" % [path, V.keys()[view]])
			var bent: Array[float] = [0.0, 0.0, 0.0, 0.0]
			for i in 120:
				rig.walk(rig.step_length / 15.0, 1.0 / 60.0)
				for j in 4:
					bent[j] = maxf(bent[j], absf(joints[j].rotation))
			for j in 4:
				_check(bent[j] > 0.15, name, "%s walking %s: %s bent only %.2f rad" % [path, V.keys()[view], joints[j].get_parent().name + "/" + joints[j].name, bent[j]])
			for i in 30:
				rig.walk(0.0, 1.0 / 60.0)
			for j in 4:
				_check(joints[j].rotation == 0.0 and (joints[j].get_parent() as Sprite2D).rotation == 0.0, name, "%s standing %s: %s is not straight (%.2f)" % [path, V.keys()[view], joints[j].get_parent().name, joints[j].rotation])
		rig.free()


## The mime faces the way it walks (a path walk and a keyboard nudge), keeps its facing when
## it stops, and faces the easel it paints at; its footfalls are tiptoes.
func _test_mime_faces_its_way() -> void:
	var name := "mime_faces_its_way"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var rig := room.mime.rig
	room.mime.place_at(Vector2(300, 470))
	room.mime.walk_to(Vector2(600, 470))
	await _walk_trace(room.mime, 300)
	_check(rig.view == CharacterRig.View.RIGHT, name, "walking right the mime shows %s" % CharacterRig.View.keys()[rig.view])
	for i in 10:
		await physics_frame
	_check(rig.view == CharacterRig.View.RIGHT, name, "standing still the mime turned to %s" % CharacterRig.View.keys()[rig.view])
	Input.action_press("ui_left")
	for i in 30:
		await physics_frame
	Input.action_release("ui_left")
	_check(rig.view == CharacterRig.View.LEFT and rig.scale.x < 0.0, name, "walking left by keyboard the mime shows %s" % CharacterRig.View.keys()[rig.view])
	_check(_game.audio.played.slice(-6).has(&"tiptoe"), name, "the keyboard walk's footfalls were not tiptoes")
	room.mime.walk_to(Vector2(400, 200))
	await _walk_trace(room.mime, 300)
	_check(rig.view == CharacterRig.View.BACK, name, "walking up the mime shows %s" % CharacterRig.View.keys()[rig.view])
	await _tap_at(room.easel.rect().get_center())
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	await _wait_until(func() -> bool: return canvas.visible, 300)
	var toward := room.easel.position - room.mime.position
	_check(canvas.visible and rig.view == CharacterRig.view_for(toward, rig.view), name, "painting the mime shows %s, not facing the easel (%s away)" % [CharacterRig.View.keys()[rig.view], toward])
	canvas.close()


## The ghost mime faces and walks along its replay's travel: right on a rightward stretch,
## its back on an upward one, limbs at rest where the bot stood.
func _test_ghost_faces_travel() -> void:
	var name := "ghost_faces_travel"
	var ghost := (load("res://scenes/ghost_mime.tscn") as PackedScene).instantiate() as GhostMime
	ghost.samples = [[100.0, 300.0, false], [120.0, 300.0, false], [140.0, 300.0, false], [140.0, 280.0, false], [140.0, 260.0, false], [140.0, 260.0, false], [140.0, 260.0, false], [140.0, 260.0, false]] as Array[Array]
	root.add_child(ghost)
	for i in 10:
		ghost.advance(1.0 / 60.0)
	_check(ghost.rig.view == CharacterRig.View.RIGHT and ghost.rig.stride > 0.0, name, "moving right the ghost shows %s (stride %.2f)" % [CharacterRig.View.keys()[ghost.rig.view], ghost.rig.stride])
	for i in 15:
		ghost.advance(1.0 / 60.0)
	_check(ghost.rig.view == CharacterRig.View.BACK, name, "moving up the ghost shows %s" % CharacterRig.View.keys()[ghost.rig.view])
	for i in 20:
		ghost.advance(1.0 / 60.0)
	_check(ghost.rig.stride == 0.0, name, "standing where the bot stood the ghost still strides (%.2f)" % ghost.rig.stride)
	ghost.free()


## The no-flash audit (jam rule 5, under 2 Hz): every repeating effect runs slower. The
## canvas's start-dot pulse and the logo's sway by their rates; every shader's *speed
## uniform read as cycles per second (its strictest reading: under sin(TIME * speed) it
## is speed / TAU); every wing gimmick's cycle (window light, searchlights, pipe beats) by
## its period.
func _test_no_flash_rates() -> void:
	var name := "no_flash_rates"
	const LIMIT_HZ := 2.0
	_check(ForgeryCanvas.PULSE_HZ < LIMIT_HZ, name, "the canvas's start dot pulses at %.1f Hz" % ForgeryCanvas.PULSE_HZ)
	var title_hz: float = (load("res://scripts/title.gd") as Script).get_script_constant_map()["SWAY_HZ"]
	_check(title_hz < LIMIT_HZ, name, "the logo sways at %.1f Hz" % title_hz)
	var speed := RegEx.create_from_string("uniform float (\\w*speed) = ([0-9.]+)")
	var shaders := 0
	for file in DirAccess.get_files_at("res://shaders"):
		if not file.ends_with(".gdshader"):
			continue
		for found in speed.search_all(FileAccess.get_file_as_string("res://shaders/" + file)):
			shaders += 1
			_check(float(found.get_string(2)) < LIMIT_HZ, name, "%s's %s is %s" % [file, found.get_string(1), found.get_string(2)])
	_check(shaders >= 7, name, "found only %d shader speeds (the regex no longer matches?)" % shaders)
	# Every gimmick's decorative rate (a *_HZ constant: drips, splashes, foam, flow, motes,
	# the glass's glint).
	var rates := 0
	for file in DirAccess.get_files_at("res://scripts/gimmicks"):
		if not file.ends_with(".gd"):
			continue
		var constants := (load("res://scripts/gimmicks/" + file) as Script).get_script_constant_map()
		for constant: String in constants:
			if constant.ends_with("_HZ"):
				rates += 1
				_check(float(constants[constant]) < LIMIT_HZ, name, "%s's %s is %s Hz" % [file, constant, constants[constant]])
	_check(rates >= 6, name, "found only %d gimmick decoration rates" % rates)
	var gimmicks := 0
	for wing_path in Content.WINGS:
		for room_path: String in (load(wing_path) as WingData).rooms:
			var room := (load(room_path) as PackedScene).instantiate()
			var stack: Array[Node] = [room.get_node_or_null("Gimmick")]
			while not stack.is_empty():
				var each := stack.pop_back() as Node
				if each == null:
					continue
				stack.append_array(each.get_children())
				var periods: Array[float] = []
				if each is WindowLight:
					periods.append((each as WindowLight).period)
				elif each is Searchlights:
					periods.append((each as Searchlights).period)
				elif each is Puddles:
					for beat in (each as Puddles).beats:
						periods.append(beat.x)
				for period in periods:
					gimmicks += 1
					_check(period >= 1.0 / LIMIT_HZ, name, "%s's %s repeats every %.2f s" % [room_path, each.name, period])
			room.free()
	_check(gimmicks >= 10, name, "found only %d gimmick cycles in the wings" % gimmicks)


## A ghost replay reads as its samples per visit: the n-th run of samples in a room is the
## bot's n-th stay there; a missing or malformed replay is a problem, not a crash.
func _test_ghost_replay_visits() -> void:
	var name := "ghost_replay_visits"
	var trail: Array = [[0, 1, 1, false], [0, 2, 2, true], [1, 3, 3, false], [0, 4, 4, false], [2, 5, 5, false]]
	_check(GhostMime.visit_samples(trail, 0, 0) == ([[1.0, 1.0, false], [2.0, 2.0, true]] as Array[Array]), name, "room 0's first stay is %s" % [GhostMime.visit_samples(trail, 0, 0)])
	_check(GhostMime.visit_samples(trail, 0, 1) == ([[4.0, 4.0, false]] as Array[Array]), name, "room 0's second stay is %s" % [GhostMime.visit_samples(trail, 0, 1)])
	_check(GhostMime.visit_samples(trail, 0, 2).is_empty() and GhostMime.visit_samples(trail, 3, 0).is_empty(), name, "a stay the bot never made has samples")
	var nexts := [GhostMime.room_after(trail, 0, 0), GhostMime.room_after(trail, 0, 1), GhostMime.room_after(trail, 2, 0), GhostMime.room_after(trail, 0, 2)]
	_check(nexts == [1, 2, -1, -1], name, "the rooms after each stay are %s, not [1, 2, -1, -1]" % [nexts])
	_check(GhostMime.path_for("res://data/wings/wing_03.tres") == "res://data/ghosts/wing_03.ghost.json" and GhostMime.path_for("res://scenes/test/slice_wing.tres") == "res://scenes/test/slice_wing.ghost.json", name, "ghost replay paths differ from where the bot records them")
	for wing_path in Content.WINGS:
		var problems: Array[String] = []
		var replay := GhostMime.load_replay(GhostMime.path_for(wing_path), problems)
		_check(problems.is_empty() and not replay["trail"].is_empty() and is_equal_approx(replay["period"], 0.1), name, "%s's ghost replay does not load: %s" % [wing_path, problems])
	var missing: Array[String] = []
	_check(GhostMime.load_replay("res://data/ghosts/none.ghost.json", missing).is_empty() and missing.size() == 1, name, "a missing replay is not one problem: %s" % [missing])
	var bad_path := "user://bad.ghost.json"
	for content: String in ["not json", '{"gap_frames": 6, "trail": [[0, 1, 2]]}']:
		var file := FileAccess.open(bad_path, FileAccess.WRITE)
		file.store_string(content)
		file.close()
		var problems: Array[String] = []
		_check(GhostMime.load_replay(bad_path, problems).is_empty() and problems.size() == 1, name, "a malformed replay (%s) is not one problem: %s" % [content, problems])
	DirAccess.remove_absolute(bad_path)


## Until a wing is escaped from, a ghost mime walks the bot's recorded route through each of
## its rooms on room time, starts over after a toss, and is gone once the wing has been
## escaped from.
func _test_ghost_mime_until_escape() -> void:
	var name := "ghost_mime_until_escape"
	var saved := _game.save.duplicate(true)
	_game.save = Save.defaults()
	_game.play_wing_file(Content.WINGS[0])
	var room := await _wait_for_room(load(Content.WINGS[0]).rooms[0], 300)
	if room == null or room.ghost == null:
		_check(false, name, "wing 1's first room shows no ghost mime on a fresh save")
		_game.save = saved
		return
	var replay := GhostMime.load_replay(GhostMime.path_for(Content.WINGS[0]), [] as Array[String])
	var samples := GhostMime.visit_samples(replay["trail"], 0, 0)
	_check(room.ghost.samples == samples and room.ghost.position == Vector2(samples[0][0], samples[0][1]), name, "the ghost does not start the bot's first stay in room 0")
	for guard in room.guards:
		guard.active = false
	for i in 30:
		await physics_frame
	var expected := Vector2(samples[5][0], samples[5][1])
	_check(room.ghost.position.distance_to(expected) < 2.0, name, "after 0.5 s of room time the ghost is at %s, not the bot's %s" % [room.ghost.position, expected])
	# Wing 1's foyer has no guard: the catch comes straight to the room.
	room._on_caught()
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_check(room.ghost.time < 0.05 and room.ghost.position == Vector2(samples[0][0], samples[0][1]), name, "the ghost did not start over after the toss (t %.2f)" % room.ghost.time)
	Save.record(_game.save, Content.wing_id(Content.WINGS[0]), [true, false, false] as Array[bool], 99.0)
	_game.replay()
	await _wait_until(func() -> bool: return current_scene != room, 120)
	room = await _wait_for_room(load(Content.WINGS[0]).rooms[0], 300)
	_check(room != null and room.ghost == null, name, "the ghost mime still shows after the wing was escaped from")
	_game.save = saved
	_game.run = null


## Screen changes wipe with the iris shader; Reduce Motion makes it a plain fade.
func _test_wipe_follows_reduce_motion() -> void:
	var name := "wipe_follows_reduce_motion"
	var material := (_game.get_node("CoverLayer/Cover") as ColorRect).material as ShaderMaterial
	_check(material != null and material.shader.resource_path == "res://shaders/iris_wipe.gdshader", name, "the cover has no iris wipe")
	if material == null:
		return
	_check(material.get_shader_parameter("fade") == false, name, "the wipe fades with Reduce Motion off")
	_game.set_setting("reduce_motion", true)
	_check(material.get_shader_parameter("fade") == true, name, "the wipe is still an iris under Reduce Motion")
	_game.set_setting("reduce_motion", false)
	_check(material.get_shader_parameter("fade") == false, name, "the iris did not come back with Reduce Motion off")


## Play on the title opens the hub; a goto during the fade is ignored.
func _test_title_play_opens_hub() -> void:
	var name := "title_play_opens_hub"
	change_scene_to_file(TITLE_PATH)
	await process_frame
	await process_frame
	var play := current_scene.get_node("PlayButton") as Button
	_check(play.has_focus(true), name, "the play button does not have visible keyboard focus (hidden focus shows no ring)")
	await _tap_control(play)
	_check(_game.is_transitioning(), name, "tapping play did not start a screen change")
	_game.goto(GameState.Flow.TITLE)
	var arrived := await _wait_until(func() -> bool: return not _game.is_transitioning(), 120)
	_check(arrived and current_scene is Hub and _game.state == GameState.Flow.HUB, name, "the hub is not running after the fade (a goto during it was not ignored?)")


## The hub's doors follow the save: a fresh save opens wing 1 only (a tap on wing 2 rattles
## its chain and goes nowhere; a tap on wing 1 walks the mime through it into the wing); an
## escape from wing 1 shows its stars and opens wing 2; back in the hub the mime stands in
## front of the wing's door.
func _test_hub_doors_unlock_and_enter() -> void:
	var name := "hub_doors_unlock_and_enter"
	_game.save = Save.defaults()
	_game.run = null
	var hub := await _load_hub()
	_check(hub.wing_doors.size() == Content.WINGS.size(), name, "the hub has %d wing doors, not %d" % [hub.wing_doors.size(), Content.WINGS.size()])
	_check(hub.wing_doors[0].open and hub.wing_doors.slice(1).all(func(door: WingDoor) -> bool: return not door.open), name, "a fresh save does not open wing 1 only")
	_check(hub.wing_doors.all(func(door: WingDoor) -> bool: return not door.broken and not door.finished), name, "a wing door is broken or finished on a fresh save")
	await _tap_at(hub.wing_doors[1].position + Vector2(0, -60))
	for i in 40:
		await physics_frame
	_check(not _game.is_transitioning() and current_scene == hub, name, "a tap on locked wing 2 left the hub")
	await _tap_at(hub.wing_doors[0].position + Vector2(0, -60))
	var entered := await _wait_until(func() -> bool: return _game.state == GameState.Flow.ROOM and not _game.is_transitioning(), 600)
	_check(entered and _game.run != null and _game.run.wing.resource_path == Content.WINGS[0] and current_scene.scene_file_path == _game.run.wing.rooms[0], name, "walking through wing 1's door did not start wing 1 in its first room")
	var room := current_scene as Room
	if room == null:
		return
	for each in room.guards:
		each.active = false
	room.mime.carrying = true
	room.ever_seen = true
	room.exit_door.glowing = true
	room.mime.place_at(room.exit_door.position)
	await _wait_until(func() -> bool: return room.finished, 30)
	_check(Save.stars_of(_game.save, "wing_01") == 2 and FileAccess.file_exists(_game.save_path), name, "the escape from wing 1 was not saved with its 2 stars")
	_game.goto(GameState.Flow.HUB)
	await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 120)
	hub = current_scene as Hub
	_check(hub.wing_doors[0].finished and hub.wing_doors[0].stars == 2 and hub.wing_doors[1].open and not hub.wing_doors[2].open, name, "after wing 1 its door does not show 2 stars and open wing 2 only")
	_check(hub.mime.position.distance_to(hub.wing_doors[0].position + Hub.BACK_FROM_WING) <= 1.0, name, "back from wing 1 the mime is at %s, not in front of its door" % hub.mime.position)
	_game.run = null
	_game.save = Save.defaults()
	DirAccess.remove_absolute(_game.save_path)
	_game.scene_paths[GameState.Flow.ROOM] = ROOM_PATH


## Under each stolen original the hideout offers a replay: the bot's escape from that wing
## with only the ghost mime moving (the mime away, the guards still), room after room in the
## bot's order; a tap leaves it for the hideout.
func _test_hideout_replays_ghost() -> void:
	var name := "hideout_replays_ghost"
	_game.run = null
	_game.save = Save.defaults()
	Save.record(_game.save, "wing_01", [true, true, true] as Array[bool], 60.0)
	change_scene_to_file("res://scenes/hideout.tscn")
	await process_frame
	await process_frame
	var replay := current_scene.get_node_or_null("Replay1") as Button
	_check(replay != null and replay.size.x >= 44.0 and replay.size.y >= 44.0 and not replay.accessibility_name.is_empty(), name, "wing 1's original has no 44x44 named replay button")
	_check(current_scene.get_node_or_null("Replay2") == null, name, "an unrobbed wing offers a replay")
	if replay == null:
		_game.save = Save.defaults()
		return
	await _tap_control(replay)
	var wing := load(Content.WINGS[0]) as WingData
	var room := await _wait_for_room(wing.rooms[0], 300)
	_check(room != null and room.run.replaying and room.ghost != null, name, "the replay did not open wing 1's first room with the ghost")
	if room == null or room.ghost == null:
		_game.save = Save.defaults()
		return
	_check(not room.mime.visible and room.guards.all(func(each: Guard) -> bool: return not each.active), name, "in the replay the mime shows or a guard moves")
	var trail: Array = GhostMime.load_replay(GhostMime.path_for(Content.WINGS[0]), [] as Array[String])["trail"]
	var next := GhostMime.room_after(trail, 0, 0)
	room.ghost.time = (room.ghost.samples.size() - 1) * room.ghost.period
	var then := await _wait_for_room(wing.rooms[next], 300)
	_check(then != null and then.run.replaying and then.ghost != null, name, "after its stay in room 0 the replay did not go on to room %d with the ghost" % next)
	if then != null:
		await _wait_navmesh(then)
		await _tap_at(Vector2(480, 400))
	var back := await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 120)
	_check(back, name, "a tap during the replay did not lead back to the hideout")
	_game.run = null
	_game.save = Save.defaults()


## The hub's hideout door leads to the hideout, where each stolen original hangs alive
## through its style (gilt with three stars, wood otherwise) and an unrobbed wing's frame is
## empty; home goes back to the hub, the mime at the hideout door.
func _test_hideout_hangs_originals() -> void:
	var name := "hideout_hangs_originals"
	_game.run = null
	_game.save = Save.defaults()
	Save.record(_game.save, "wing_01", [true, true, true] as Array[bool], 60.0)
	Save.record(_game.save, "wing_02", [true, false, false] as Array[bool], 200.0)
	var hub := await _load_hub()
	_check(hub.hideout_door.glowing, name, "the hideout door does not glow with originals stolen")
	await _tap_at(hub.hideout_door.position)
	var arrived := await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 600)
	_check(arrived and _game.state == GameState.Flow.HIDEOUT, name, "a tap on the hideout door did not lead to the hideout")
	var hideout := current_scene as Hideout
	if hideout == null:
		return
	var first := hideout.originals[0]
	var second := hideout.originals[1]
	_check(first != null and first.painting == "pearl_earring" and first.gilded and first.picture() != null, name, "wing 1's original does not hang gilded")
	_check(second != null and second.painting == "great_wave" and not second.gilded, name, "wing 2's original does not hang in wood")
	_check(hideout.originals.slice(2).all(func(each: FramedPainting) -> bool: return each == null), name, "unrobbed wings hang an original")
	_check(first != null and (first.get_child(0) as Sprite2D).material != null, name, "wing 1's original is not alive through its style")
	var home := hideout.get_node("HomeButton") as Button
	_check(home.has_focus(true), name, "home does not have visible keyboard focus")
	_game.safe_area_override = Rect2(65, 0, 1040, 511)
	root.size = Vector2i(1170, 540)
	_game.fit_screen()
	var home_rect := home.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, home.size)
	_check(_game.safe_rect().encloses(home_rect), name, "on a notched phone home at %s leaves the safe area %s" % [home_rect, _game.safe_rect()])
	_game.safe_area_override = Rect2()
	root.size = BASE_WINDOW
	_game.fit_screen()
	await _tap_control(home)
	await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 120)
	hub = current_scene as Hub
	_check(hub != null and hub.mime.position.distance_to(hub.hideout_door.arrival_point()) <= 1.0, name, "back from the hideout the mime is not at its door")
	_game.save = Save.defaults()


## Space (or the pause button) pauses the room under the pause menu and Space resumes it;
## the timer stops meanwhile. Its settings toggle and save each setting (music mutes its
## bus, the Off mark shows); Space does nothing while they are open; back returns focus to
## the settings button; home leaves for the hub with the tree running.
func _test_pause_and_settings() -> void:
	var name := "pause_and_settings"
	_game.save = Save.defaults()
	var room := await _load_room()
	for each in room.guards:
		each.active = false
	await _press_key(KEY_SPACE)
	var menu := room.pause_menu
	_check(paused and menu.visible and (menu.get_node("Panel/ResumeButton") as Button).has_focus(true), name, "Space did not pause under the menu with resume focused")
	var at := room.elapsed
	for i in 10:
		await process_frame
	_check(room.elapsed == at, name, "the timer ran while paused")
	await _press_key(KEY_SPACE)
	_check(not paused and not menu.visible, name, "Space did not resume")
	await _tap_control(room.get_node("PauseButton") as Button)
	_check(paused and menu.visible, name, "the pause button did not pause")
	await _tap_control(menu.get_node("Panel/SettingsButton") as Button)
	var settings := menu.get_node("SettingsMenu") as SettingsMenu
	var music := settings.get_node("Panel/MusicToggle") as Button
	_check(settings.visible and music.has_focus(true) and music.button_pressed and not (music.get_node("Off") as CanvasItem).visible, name, "settings did not open with music on and focused")
	await _tap_control(music)
	_check(not _game.setting("music") and (music.get_node("Off") as CanvasItem).visible and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), name, "the music toggle did not turn music off, mark it and mute its bus")
	var problems: Array[String] = []
	_check(not Save.parse(FileAccess.get_file_as_string(_game.save_path), problems)["settings"]["music"], name, "music off was not saved")
	await _tap_control(settings.get_node("Panel/AssistToggle") as Button)
	_check(_game.assist, name, "the assist toggle did not turn assist on")
	var motion := settings.get_node("Panel/MotionToggle") as Button
	_check(motion.button_pressed and not (motion.get_node("Off") as CanvasItem).visible, name, "motion effects do not show on while reduce motion is off")
	await _tap_control(motion)
	_check(_game.setting("reduce_motion") and (motion.get_node("Off") as CanvasItem).visible, name, "crossing out motion did not turn reduce motion on")
	var toggles_before: Dictionary = _game.save["settings"].duplicate()
	await _press_key(KEY_SPACE)
	_check(paused and settings.visible and _game.save["settings"] == toggles_before, name, "Space with the settings open resumed or flipped a toggle")
	await _tap_control(settings.get_node("Panel/BackButton") as Button)
	_check(not settings.visible and (menu.get_node("Panel/SettingsButton") as Button).has_focus(true), name, "back did not close the settings onto the settings button")
	root.size = Vector2i(540, 960)
	_game.fit_screen()
	await _press_key(KEY_SPACE)
	_check(paused and menu.visible, name, "Space resumed the room under the rotate overlay")
	root.size = BASE_WINDOW
	_game.fit_screen()
	_check(paused and menu.visible, name, "landscape again unpaused a room paused before the overlay")
	await _tap_control(menu.get_node("Panel/HomeButton") as Button)
	_check(not menu.visible, name, "the pause menu still shows during home's fade")
	var home := await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 120)
	_check(home and not paused, name, "home did not reach the hub with the tree running")
	_game.save = Save.defaults()
	_game.set_setting("music", true)
	DirAccess.remove_absolute(_game.save_path)
	_game.scene_paths[GameState.Flow.ROOM] = ROOM_PATH


## The hub's gear opens the settings, which take the lobby's taps until back closes them.
func _test_hub_settings() -> void:
	var name := "hub_settings"
	var hub := await _load_hub()
	var gear := hub.get_node("SettingsButton") as Button
	await _tap_control(gear)
	_check(hub.settings.visible, name, "the gear did not open the settings")
	var from := hub.mime.position
	await _tap_at(Vector2(700, 450))
	for i in 20:
		await physics_frame
	_check(hub.mime.position == from, name, "a tap under the open settings walked the mime")
	await _tap_control(hub.settings.get_node("Panel/BackButton") as Button)
	_check(not hub.settings.visible and gear.has_focus(true), name, "back did not close the settings onto the gear")


## A key press and release (physical key `key`), a frame each.
func _press_key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		Input.parse_input_event(event)
		await process_frame


## The hub as the current scene, its navmesh synced.
func _load_hub() -> Hub:
	change_scene_to_file(HUB_PATH)
	for i in 3:
		await physics_frame
	var hub := current_scene as Hub
	var map := hub.get_world_2d().navigation_map
	await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, hub.mime.position).is_valid(), 60)
	return hub


func _test_goto_missing_scene_reports() -> void:
	var name := "goto_missing_scene_reports"
	var saved := _game.scene_paths[GameState.Flow.TITLE]
	var errors_before := _game.errors.size()
	_game.scene_paths[GameState.Flow.TITLE] = "res://scenes/no_such_scene.tscn"
	_game.quiet_errors = true
	_game.goto(GameState.Flow.TITLE)
	_game.quiet_errors = false
	_game.scene_paths[GameState.Flow.TITLE] = saved
	_check(_game.errors.size() == errors_before + 1 and "no_such_scene" in _game.errors[-1], name, "a missing scene was not reported")
	_check(_game.error_badge_visible(), name, "the error badge is hidden after a missing scene")
	_check(not _game.is_transitioning(), name, "a missing scene started a transition")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false


## Tap the masterpiece, stand through the swap, then leave by the exit: all three stars.
func _test_room_swap_and_escape() -> void:
	var name := "room_swap_and_escape"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room._on_painted(Forgery.ASSIST_QUALITY)
	await _tap_at(room.painting_rect().get_center())
	_check(room.swap_intent, name, "a tap on the masterpiece did not mean swap")
	var swapped := await _wait_until(func() -> bool: return room.mime.carrying, 900)
	_check(swapped, name, "the mime never swapped the painting (at %s, progress %.2f)" % [room.mime.position, room.mime.swap_progress])
	_check(room.exit_door.glowing, name, "the exit door does not glow while carrying the original")
	await _tap_at(Vector2(950, 330))
	var escaped := await _wait_until(func() -> bool: return room.finished, 900)
	_check(escaped, name, "the mime never escaped (at %s)" % room.mime.position)
	_check(room.stars == [true, true, true], name, "an unseen escape at %.1f s earned %s" % [room.elapsed, room.stars])
	var results := room.get_node("ResultsLayer/Results") as Results
	_check(results.visible, name, "the results overlay is hidden after the escape")
	# Every star has popped in by 3 x (STAR_GAP + POP_TIME), each gold as earned.
	for i in ceili(3.0 * (Results.STAR_GAP + Results.POP_TIME) * 60.0) + 6:
		await physics_frame
	for i in 3:
		var star := results.get_node("Panel/Star%d" % i) as TextureRect
		_check(star.scale.is_equal_approx(Vector2.ONE) and star.texture == Results.STAR_EARNED, name, "star %d did not pop in gold (scale %s)" % [i, star.scale])
	var finished_at := room.elapsed
	for i in 30:
		await physics_frame
	_check(room.elapsed == finished_at, name, "the timer kept running after the escape")


## Tapping away mid-swap cancels it; the exit does nothing without the original.
func _test_room_swap_cancel_and_locked_exit() -> void:
	var name := "room_swap_cancel_and_locked_exit"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room._on_painted(Forgery.ASSIST_QUALITY)
	await _tap_at(room.painting_rect().get_center())
	var swapping := await _wait_until(func() -> bool: return room.mime.swap_progress > 0.3, 900)
	_check(swapping, name, "the swap never got going")
	await _tap_at(Vector2(950, 330))
	_check(room.mime.swap_progress == 0.0 and not room.swap_intent, name, "tapping away did not cancel the swap")
	await _walk_trace(room.mime, 900)
	_check(room.mime.position.distance_to(room.exit_door.position) <= Door.REACH, name, "the mime did not reach the exit (at %s)" % room.mime.position)
	for i in 10:
		await physics_frame
	_check(not room.finished and not room.mime.carrying, name, "the exit ended the wing without the original")


## Taps the easel and waits (at most 600 frames) for the canvas to open; returns it.
func _open_easel(room: Room) -> ForgeryCanvas:
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	await _tap_at(room.easel.rect().get_center())
	await _wait_until(func() -> bool: return canvas.visible, 600)
	return canvas


## Traces the canvas's ghosts exactly, from its next stroke to the last.
func _trace_rest(canvas: ForgeryCanvas) -> void:
	for i in range(canvas.traced.size(), canvas.ghosts.size()):
		await _drag_along(_on_pad(canvas, Forgery.resample(canvas.ghosts[i])))


## Without a fake the masterpiece is only floor; the glowing easel opens the canvas, which
## takes the room's taps; a painted fake puts the glow out and enables the swap; once
## carrying the original, the easel is only floor too.
func _test_room_easel_paints_fake() -> void:
	var name := "room_easel_paints_fake"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var glow := room.easel.get_node("Glow") as Polygon2D
	_check(glow.visible and not room.mime.has_fake, name, "the easel does not glow at the start, or the mime starts with a fake")
	await _tap_at(room.painting_rect().get_center())
	_check(not room.swap_intent, name, "a tap on the masterpiece without a fake meant swap")
	var canvas := await _open_easel(room)
	_check(canvas.visible and room.mime.position.distance_to(room.easel.spot()) <= Room.SWAP_REACH, name, "tapping the easel did not open the canvas with the mime at the easel (at %s)" % room.mime.position)
	await _tap_at(Vector2(100, 480))
	_check(not room.mime.walking, name, "a tap beside the open canvas walked the mime")
	await _trace_rest(canvas)
	_check(await _wait_until(func() -> bool: return room.mime.has_fake, 120), name, "tracing every ghost gave the mime no fake")
	_check(not glow.visible and not canvas.visible, name, "after painting the easel still glows or the canvas stays open")
	_check(Forgery.grade(room.fake_quality) == Forgery.Grade.PERFECT, name, "an exact trace of the room's painting graded %s (%.2f)" % [Forgery.Grade.keys()[Forgery.grade(room.fake_quality)], room.fake_quality])
	var carried := room.mime.get_node("Carried") as FramedPainting
	_check(carried.visible and carried.modulate == Mime.FAKE_TINT, name, "the carried fake does not show, tinted")
	await _tap_at(room.painting_rect().get_center())
	_check(await _wait_until(func() -> bool: return room.mime.carrying, 900), name, "the fake never swapped for the original")
	_check(not room.mime.has_fake and carried.modulate == Color.WHITE, name, "after the swap the mime still has the fake, or the original shows tinted")
	await _tap_at(room.easel.rect().get_center())
	_check(not room.paint_intent, name, "carrying the original, a tap on the easel meant paint")


## A catch while painting closes the canvas and keeps its finished strokes; after the toss
## the easel resumes at the next stroke.
func _test_room_catch_while_painting() -> void:
	var name := "room_catch_while_painting"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var canvas := await _open_easel(room)
	await _drag_along(_on_pad(canvas, Forgery.resample(canvas.ghosts[0])))
	room.guard.active = true
	_stage_guard(room, room.mime.position + Vector2(80, 0), Vector2.LEFT, room.mime.position)
	await _wait_until(func() -> bool: return room.tossing, 120)
	_check(room.tossing and not canvas.visible and canvas.traced.size() == 1, name, "a catch while painting: tossing %s, canvas visible %s, %d traced (expected 1)" % [room.tossing, canvas.visible, canvas.traced.size()])
	await _wait_until(func() -> bool: return not room.tossing, 180)
	room.guard.active = false
	canvas = await _open_easel(room)
	_check(canvas.visible and canvas.traced.size() == 1, name, "after the toss the easel does not resume at stroke 2")


## The room with a fake of `quality` hung, the mime carrying the original out of sight,
## and the guard standing still on its top leg facing the fake.
func _inspection_room(quality: float) -> Room:
	var room := await _load_room()
	if room == null:
		return null
	room._on_painted(quality)
	room._swap()
	_stage_guard(room, Vector2(640, 250), Vector2.RIGHT, Vector2(100, 480))
	return room


## Waits for the guard's next inspection to start and run out; returns whether it did.
func _await_inspection(room: Room) -> bool:
	var started := await _wait_until(func() -> bool: return room.guard.inspecting, 30)
	# The room shows the "?" on its next tick (it runs before the guard's).
	await physics_frame
	var query_shown := (room.get_node("FakeIcon") as Sprite2D).visible and (room.get_node("FakeIcon") as Sprite2D).texture == Room.QUERY_ICON
	var ended := await _wait_until(func() -> bool: return not room.guard.inspecting, ceili(Guard.INSPECT_TIME * 60.0) + 10)
	await physics_frame
	return started and query_shown and ended


## The guard looks away for a moment, then back at the fake: a new pass.
func _new_pass(room: Room) -> void:
	room.guard.facing = Vector2.LEFT
	for i in 3:
		await physics_frame
	room.guard.facing = Vector2.RIGHT


## A Sloppy fake is found out at the first inspection: "!" over the painting for good,
## the guard searches around it (red cone) and gives up after SEARCH_TIME, and the fake is
## never inspected again.
func _test_sloppy_fake_starts_search() -> void:
	var name := "sloppy_fake_starts_search"
	var room := await _inspection_room(0.2)
	if room == null:
		return
	_check(await _await_inspection(room), name, "the guard facing the hung fake did not inspect it under a \"?\"")
	var icon := room.get_node("FakeIcon") as Sprite2D
	_check(room.found_out and icon.visible and icon.texture == Room.ALARM_ICON, name, "a Sloppy fake was not found out (found_out %s, icon %s)" % [room.found_out, icon.texture])
	await physics_frame
	await physics_frame
	var cone := room.guard.get_node("Cone") as Polygon2D
	_check(room.guard.intent == GuardBrain.Intent.SEARCH and room.guard.search_point == room.fake_view_point(), name, "after a found-out fake the guard is %s around %s, not searching the fake" % [_intent_name(room.guard.intent), room.guard.search_point])
	_check(cone.color == Guard.CONE_ALERT_COLOR, name, "the searching guard's cone is not red")
	var gave_up := await _wait_until(func() -> bool: return room.guard.intent == GuardBrain.Intent.PATROL, ceili(Guard.SEARCH_TIME * 60.0) + 240)
	_check(gave_up, name, "the search never ended (intent %s)" % _intent_name(room.guard.intent))
	await _new_pass(room)
	for i in 30:
		await physics_frame
	_check(room.inspections == 1 and icon.texture == Room.ALARM_ICON and icon.visible, name, "a found-out fake was inspected again or lost its \"!\" (%d inspections)" % room.inspections)


## A Good fake passes its first inspection (and is not re-inspected within the same
## pass) and is found out on the next pass; a Perfect fake passes both.
func _test_good_and_perfect_fakes_pass() -> void:
	var name := "good_and_perfect_fakes_pass"
	for fake_quality: float in [Forgery.ASSIST_QUALITY, 0.95]:
		var room := await _inspection_room(fake_quality)
		if room == null:
			return
		var grade: String = Forgery.Grade.keys()[Forgery.grade(fake_quality)]
		_check(await _await_inspection(room), name, "%s: the first inspection did not run" % grade)
		_check(not room.found_out and not (room.get_node("FakeIcon") as Sprite2D).visible, name, "%s: the first inspection found the fake out" % grade)
		for i in 30:
			await physics_frame
		_check(room.inspections == 1, name, "%s: the guard re-inspected within one pass (%d inspections)" % [grade, room.inspections])
		await _new_pass(room)
		_check(await _await_inspection(room), name, "%s: the second pass did not inspect" % grade)
		var expect_found := Forgery.grade(fake_quality) == Forgery.Grade.GOOD
		_check(room.found_out == expect_found, name, "%s: after the second inspection found_out is %s" % [grade, room.found_out])


## A catch during an inspection cuts it short: it does not count and the "?" goes.
func _test_catch_cuts_inspection_short() -> void:
	var name := "catch_cuts_inspection_short"
	var room := await _inspection_room(0.2)
	if room == null:
		return
	await _wait_until(func() -> bool: return room.guard.inspecting, 30)
	room.mime.place_at(Vector2(720, 230))
	await _wait_until(func() -> bool: return room.tossing, 120)
	_check(room.tossing and room.inspections == 0 and not (room.get_node("FakeIcon") as Sprite2D).visible, name, "a catch mid-inspection: tossing %s, %d inspections, icon shown %s" % [room.tossing, room.inspections, (room.get_node("FakeIcon") as Sprite2D).visible])
	_check(not room.found_out, name, "a cut-short inspection found the fake out")


## The open canvas covers nothing the painter must watch: the easel, the mime painting at
## it, and the guard's legs that lead to it (its left and bottom legs, with the guard's
## height above its feet); it sits over the back wall and the far top-right corner.
func _test_canvas_leaves_approach_visible() -> void:
	var name := "canvas_leaves_approach_visible"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var canvas := await _open_easel(room)
	await process_frame
	var route := room.guard.route
	var guard_height := 110.0
	var watched: Dictionary[String, Rect2] = {
		"the easel": room.easel.rect(),
		"the painting mime": Rect2(room.easel.spot() - Vector2(30, 100), Vector2(60, 104)),
		"the guard's left leg": Rect2(route[0].x - 24, route[0].y - guard_height, 48, route[3].y - route[0].y + guard_height),
		"the guard's bottom leg": Rect2(route[3].x - 24, route[3].y - guard_height, route[2].x - route[3].x + 48, guard_height),
	}
	for child in canvas.get_children():
		var control := child as Control
		if control == null or not control.visible or control == canvas.get_node("Pad"):
			continue
		for what: String in watched:
			_check(not control.get_global_rect().intersects(watched[what]), name, "the canvas's %s %s covers %s %s" % [control.name, control.get_global_rect(), what, watched[what]])


## After an escape, replay starts the room afresh and home returns to the title.
func _test_results_buttons() -> void:
	var name := "results_buttons"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var results := room.get_node("ResultsLayer/Results") as Results
	results.present(Stars.earned(true, 99.0, 45.0))
	await process_frame
	_check((results.get_node("Panel/ReplayButton") as Button).has_focus(true), name, "replay does not have visible keyboard focus after the results show")
	await _tap_control(results.get_node("Panel/ReplayButton") as Button)
	await _wait_until(func() -> bool: return not _game.is_transitioning(), 120)
	var again := current_scene as Room
	_check(again != null and again != room and again.elapsed < 1.0 and not again.finished, name, "replay did not start the room afresh")
	if again == null:
		return
	results = again.get_node("ResultsLayer/Results") as Results
	results.present(Stars.earned(true, 99.0, 45.0))
	await process_frame
	await _tap_control(results.get_node("Panel/HomeButton") as Button)
	await _wait_until(func() -> bool: return not _game.is_transitioning(), 120)
	_check(current_scene is Hub and _game.state == GameState.Flow.HUB, name, "home did not return to the hub")


## A route the guard cannot patrol (under 2 points) is reported through the error badge.
func _test_guard_bad_route_reports() -> void:
	var name := "guard_bad_route_reports"
	var guard := (load("res://scenes/guard.tscn") as PackedScene).instantiate() as Guard
	guard.route = PackedVector2Array([Vector2(100, 100)])
	root.add_child(guard)
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	guard.reset()
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and "1 point(s)" in _game.errors[-1], name, "a one-point route was not reported (errors: %s)" % [_game.errors.slice(errors_before)])
	_check(_game.error_badge_visible(), name, "the error badge is hidden after a bad route")
	_check(guard.position == Vector2(100, 100), name, "the guard does not stand at its one point")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	guard.queue_free()
	await process_frame


## The wing timer does not run while the screen change into the room fades.
func _test_room_timer_waits_for_fade() -> void:
	var name := "room_timer_waits_for_fade"
	change_scene_to_file(TITLE_PATH)
	await process_frame
	await process_frame
	_game.goto(GameState.Flow.ROOM)
	var ticked_during_fade := 0.0
	var saw_room := false
	while _game.is_transitioning():
		var room := current_scene as Room
		if room != null:
			saw_room = true
			ticked_during_fade = maxf(ticked_during_fade, room.elapsed)
		await physics_frame
	_check(saw_room, name, "the room never ran during the fade-in")
	_check(ticked_during_fade == 0.0, name, "the timer ran %.2f s during the fade" % ticked_during_fade)
	for i in 30:
		await physics_frame
	var room_after := current_scene as Room
	_check(room_after != null and room_after.elapsed > 0.4, name, "the timer did not start after the fade")


## Carrying set before the mime is in the tree shows the painting once it is.
func _test_mime_carrying_before_ready() -> void:
	var name := "mime_carrying_before_ready"
	var mime := (load("res://scenes/mime.tscn") as PackedScene).instantiate() as Mime
	mime.carrying = true
	root.add_child(mime)
	_check((mime.get_node("Carried") as FramedPainting).visible, name, "the carried painting is hidden when carrying was set before _ready")
	mime.queue_free()
	await process_frame


## The room hangs its paintings: each frame shows its scan through its own style, and the
## mime carries the room's masterpiece.
func _test_room_paintings_framed() -> void:
	var name := "room_paintings_framed"
	var room := await _load_room()
	var pictures: Dictionary[String, FramedPainting] = {
		"starry_night": room.get_node("Masterpiece"),
		"great_wave": room.get_node("Frames/FrameA/Swing/Picture"),
		"grande_jatte": room.get_node("Frames/FrameB/Swing/Picture"),
		"pearl_earring": room.get_node("Portraits/PortraitA/Picture"),
		"mona_lisa": room.get_node("Portraits/PortraitB/Picture"),
	}
	for id in pictures:
		var picture := pictures[id]
		var sprite := picture.get_child(0) as Sprite2D
		_check(picture.painting == id and picture.picture() == Paintings.SCANS[StringName(id)], name, "%s does not show the %s scan" % [picture.get_path(), id])
		_check(sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == Paintings.STYLES[StringName(id)], name, "%s is not drawn in the %s style" % [picture.get_path(), id])
		var shown := sprite.region_rect.size * sprite.scale
		_check(shown.is_equal_approx(picture.size - Vector2.ONE * picture.moulding * 2.0), name, "%s's picture is %s, not its frame's inside" % [picture.get_path(), shown])
	_check((room.mime.get_node("Carried") as FramedPainting).painting == "starry_night", name, "the mime does not carry the room's masterpiece")
	var frame := room.get_node("Frames/FrameA") as TiltFrame
	var portrait := room.get_node("Portraits/PortraitB") as HidingPortrait
	frame.painting = "earthly_delights"
	portrait.painting = "pearl_earring"
	_check(pictures["great_wave"].painting == "earthly_delights" and pictures["mona_lisa"].painting == "pearl_earring", name, "a frame or portrait given a new painting after _ready still shows the old one")
	var reference := room.get_node("EaselLayer/ForgeryCanvas/Reference") as TextureRect
	var reference_style := reference.material as ShaderMaterial
	_check(reference.texture == Paintings.SCANS[&"starry_night"] and reference_style != null and reference_style.shader == Paintings.STYLES[&"starry_night"], name, "the forgery canvas does not show the masterpiece in its style")


## A room's layout comes from its nodes: one without an easel, a masterpiece or an exit
## still plays (a tap where they would be walks the mime there; nothing is usable), and a
## child of the wrong type under Frames, Portraits or Doors is reported.
func _test_room_layout_optional_and_checked() -> void:
	var name := "room_layout_optional_and_checked"
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	for path: String in ["Actors/Easel", "Masterpiece", "Doors/Exit"]:
		room.get_node(path).free()
	for parent: String in ["Frames", "Portraits", "Doors"]:
		var stray := Node2D.new()
		stray.name = "Stray"
		room.get_node(parent).add_child(stray)
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	var old := current_scene
	root.add_child(room)
	current_scene = room
	if old != null:
		old.queue_free()
	_game.quiet_errors = false
	var reported := _game.errors.slice(errors_before)
	for kind: String in ["not a TiltFrame", "not a HidingPortrait", "not a Door"]:
		_check(reported.any(func(e: String) -> bool: return kind in e and "Stray" in e), name, "a stray child (%s) was not reported (errors: %s)" % [kind, reported])
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	_check(room.easel == null and room.masterpiece == null and room.exit_door == null, name, "a room without them still has an easel, masterpiece or exit")
	_check(room.painting_rect() == Rect2() and room.swap_spot() == Vector2.INF, name, "a room without a masterpiece has somewhere to swap")
	var map := room.get_world_2d().navigation_map
	await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60)
	room.guard.active = false
	room._on_floor_tapped(Vector2(182, 330))
	_check(room.mime.walking and not room.paint_intent, name, "a tap where an easel would be did not just walk the mime")
	room.mime.place_at(Vector2(230, 372))
	room._on_interacted()
	_check(not room.paint_intent and not room.swap_intent, name, "E found something to use in an empty room")


## The room bakes its navmesh from the floor outline less its partitions: the walkable
## floor ends 8 units inside the outline and around the partition's footprint.
func _test_navmesh_baked_around_partitions() -> void:
	var name := "navmesh_baked_around_partitions"
	var room := await _load_room()
	if room == null:
		return
	var map := room.get_world_2d().navigation_map
	var corner := NavigationServer2D.map_get_closest_point(map, Vector2(0, 0))
	_check(corner.is_equal_approx(Vector2(40, 180)), name, "the walkable floor's corner is %s, not (40, 180)" % corner)
	var footprint := Rect2(400, 300, 160, 60)
	var inside := NavigationServer2D.map_get_closest_point(map, footprint.get_center())
	_check(not footprint.has_point(inside), name, "the navmesh reaches %s inside the partition's footprint %s" % [inside, footprint])


## A wing's data passes Content.validate, and each broken field is named in a problem.
func _test_content_validates_wings() -> void:
	var name := "content_validates_wings"
	var good := _test_wing()
	_check(Content.validate(good, "good.tres").is_empty(), name, "a valid wing has problems: %s" % [Content.validate(good, "good.tres")])
	var cases: Dictionary[String, Callable] = {
		"painting": func(w: WingData) -> void: w.painting = "no_such_painting",
		"rooms is empty": func(w: WingData) -> void: w.rooms = [],
		"rooms[1]": func(w: WingData) -> void: w.rooms = [w.rooms[0], "res://scenes/test/missing.tscn"],
		"par_time": func(w: WingData) -> void: w.par_time = 0.0,
		"ghosts is empty": func(w: WingData) -> void: w.ghosts = [],
		"ghosts[0] has no points": func(w: WingData) -> void: w.ghosts = [PackedVector2Array()],
		"off the canvas": func(w: WingData) -> void: w.ghosts = [PackedVector2Array([Vector2(321, 10)])],
		"bot_route is empty": func(w: WingData) -> void: w.bot_route = PackedVector2Array(),
		"off the (960": func(w: WingData) -> void: w.bot_route = PackedVector2Array([Vector2(10, 541)]),
	}
	for field in cases:
		var wing := _test_wing()
		cases[field].call(wing)
		var found := Content.validate(wing, "bad.tres")
		_check(found.size() == 1 and field in found[0] and "bad.tres" in found[0], name, "breaking %s gave %s" % [field, found])
	var edge := _test_wing()
	edge.ghosts = [PackedVector2Array([Vector2(0, 0), Vector2(320, 240)])]
	_check(Content.validate(edge, "edge.tres").is_empty(), name, "ghost points on the canvas's edges are refused")
	var problems: Array[String] = []
	_check(Content.load_wing("res://data/wings/missing.tres", problems) == null and problems.size() == 1, name, "a missing wing file loaded or was not reported: %s" % [problems])
	_check(Content.validate(null, "x.tres") == (["x.tres: is not a WingData"] as Array[String]), name, "a missing WingData was not reported")


## Every wing in Content.WINGS validates, and its rooms make a whole wing: each room loads
## as a Room, every door leads to one of the wing's rooms and has a door back, and the wing
## has exactly one easel, one masterpiece and one exit.
func _test_wings_are_complete() -> void:
	var name := "wings_are_complete"
	_check(not Content.WINGS.is_empty(), name, "Content lists no wings")
	for path in Content.WINGS:
		var problems: Array[String] = []
		var wing := Content.load_wing(path, problems)
		_check(wing != null, name, "%s does not validate: %s" % [path, problems])
		if wing == null:
			continue
		var easels := 0
		var masterpieces := 0
		var exits := 0
		var links: Array[Vector2i] = []
		for i in wing.rooms.size():
			var room := (load(wing.rooms[i]) as PackedScene).instantiate() as Room
			_check(room != null, name, "%s room %d (%s) is not a Room" % [path, i, wing.rooms[i]])
			if room == null:
				continue
			easels += 1 if room.has_node("Actors/Easel") else 0
			masterpieces += 1 if room.has_node("Masterpiece") else 0
			for door in room.get_node("Doors").get_children():
				var to := (door as Door).to_room
				if to == Door.EXIT:
					exits += 1
				else:
					_check(to >= 0 and to < wing.rooms.size() and to != i, name, "%s room %d's door %s leads to room %d" % [path, i, door.name, to])
					links.append(Vector2i(i, to))
			room.free()
		for link in links:
			_check(Vector2i(link.y, link.x) in links, name, "%s: room %d leads to room %d, which has no door back" % [path, link.x, link.y])
		_check(easels == 1 and masterpieces == 1 and exits == 1, name, "%s has %d easel(s), %d masterpiece(s) and %d exit(s), not one each" % [path, easels, masterpieces, exits])


## A valid two-room wing on the test halls (scenes/test): the easel and the exit in hall A,
## the masterpiece in hall B.
func _test_wing() -> WingData:
	var wing := WingData.new()
	wing.painting = "great_wave"
	wing.rooms = ["res://scenes/test/hall_a.tscn", "res://scenes/test/hall_b.tscn"]
	wing.par_time = 60.0
	wing.ghosts = [PackedVector2Array([Vector2(160, 120)])]
	wing.bot_route = PackedVector2Array([Vector2(182, 315)])
	return wing


## A wing plays across its rooms: the mime goes through a door (a tap on it) to the next
## room, coming in at the door that leads back; the timer, the fake and the original go
## with it; the hung fake is still there on a later visit; the exit ends the wing; replay
## starts it again from room 0.
func _test_wing_doors_carry_the_run() -> void:
	var name := "wing_doors_carry_the_run"
	var wing := _test_wing()
	_game.play_wing(wing)
	await _wait_until(func() -> bool: return not _game.is_transitioning() and current_scene is Room, 120)
	var hall_a := current_scene as Room
	_check(hall_a.scene_file_path == wing.rooms[0] and hall_a.run == _game.run and hall_a.mime.position == hall_a.entrance, name, "the wing did not start in room 0 at its entrance")
	_check((hall_a.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas).ghosts == wing.ghosts, name, "the canvas does not trace the wing's ghosts")
	hall_a._on_painted(0.9)
	var to_b := hall_a.get_node("Doors/ToHallB") as Door
	await _wait_navmesh(hall_a)
	await _tap_at(to_b.position)
	var hall_b := await _wait_for_room(wing.rooms[1], 900) as Room
	if hall_b == null:
		_check(false, name, "the mime never went through to room 1 (at %s)" % hall_a.mime.position)
		return
	var back := hall_b.get_node("Doors/ToHallA") as Door
	_check(hall_b.mime.position.is_equal_approx(back.arrival_point()), name, "in room 1 the mime is at %s, not inside the door back (%s)" % [hall_b.mime.position, back.arrival_point()])
	_check(hall_b.elapsed > 0.5 and hall_b.mime.has_fake and is_equal_approx(hall_b.fake_quality, 0.9), name, "the timer or the fake did not come along (t %.2f, fake %s)" % [hall_b.elapsed, hall_b.mime.has_fake])
	_check(hall_b.masterpiece.painting == "great_wave" and hall_b.mime.painting == "great_wave", name, "room 1 does not hang the wing's painting")
	hall_b._swap()
	await _wait_navmesh(hall_b)
	await _tap_at(back.position)
	hall_a = await _wait_for_room(wing.rooms[0], 900) as Room
	if hall_a == null:
		_check(false, name, "the mime never went back to room 0")
		return
	_check(hall_a.mime.carrying and hall_a.exit_door.glowing and not hall_a.easel.glowing, name, "back in room 0 the original, the exit's glow or the spent easel is wrong")
	_check(_game.run.hung[1]["fake_hung"] == true, name, "room 1 did not remember its hung fake")
	await _wait_navmesh(hall_a)
	await _tap_at(hall_a.exit_door.position)
	_check(await _wait_until(func() -> bool: return hall_a.finished, 900), name, "the mime never escaped through room 0's exit")
	_check(hall_a.stars[Stars.Star.SWAP], name, "the escape did not earn the swap star")
	_game.replay()
	var again := await _wait_for_room(wing.rooms[0], 120) as Room
	_check(again != null and again != hall_a and again.elapsed < 1.0 and not again.mime.carrying, name, "replay did not start the wing afresh in room 0")
	_game.run = null
	_game.scene_paths[GameState.Flow.ROOM] = ROOM_PATH


## Waits (at most `max_frames` physics frames) until the current scene is a ready room
## loaded from `path` and no screen change runs; returns it, or null.
func _wait_for_room(path: String, max_frames: int) -> Room:
	var arrived := await _wait_until(func() -> bool: return current_scene is Room and current_scene.scene_file_path == path and current_scene.is_node_ready() and not _game.is_transitioning(), max_frames)
	return current_scene as Room if arrived else null


## Waits until `room`'s navigation map holds its navmesh.
func _wait_navmesh(room: Room) -> void:
	var map := room.get_world_2d().navigation_map
	await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60)


## Light scales how fast a seen mime fills suspicion; in shade (light 0) it drains as if
## unseen.
func _test_detection_light() -> void:
	var name := "detection_light"
	var lit := Detection.suspicion_after(0.0, true, 0.0, 180.0, 0.1)
	var bright := Detection.suspicion_after(0.0, true, 0.0, 180.0, 0.1, 2.0)
	_check(is_equal_approx(bright, lit * 2.0), name, "light 2 filled %.3f, not twice %.3f" % [bright, lit])
	_check(is_equal_approx(Detection.suspicion_after(0.5, true, 0.0, 180.0, 0.1, 0.0), 0.5 - Detection.DRAIN * 0.1), name, "a seen mime in shade did not drain like an unseen one")


## The slice room with a TestGimmick (named Gimmick) added before it enters the tree.
func _load_room_with_gimmick(gimmick: TestGimmick) -> Room:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	gimmick.name = "Gimmick"
	room.add_child(gimmick)
	var old := current_scene
	root.add_child(room)
	current_scene = room
	if old != null:
		old.queue_free()
	await _wait_navmesh(room)
	return room


## In the gimmick's shade a guard staring at the mime never grows suspicious; lit, it does.
func _test_gimmick_shade_and_light() -> void:
	var name := "gimmick_shade_and_light"
	var gimmick := TestGimmick.new()
	gimmick.light = 0.0
	var room := await _load_room_with_gimmick(gimmick)
	_check(room.gimmick == gimmick and room.guard.gimmick == gimmick and room.mime.gimmick == gimmick, name, "the room did not hand its gimmick to the guard and the mime")
	_stage_guard(room, Vector2(600, 250), Vector2.RIGHT, Vector2(680, 250))
	for i in 30:
		await physics_frame
	_check(room.guard.suspicion == 0.0, name, "a guard grew suspicious (%.2f) of a mime in shade" % room.guard.suspicion)
	gimmick.light = 1.0
	for i in 10:
		await physics_frame
	_check(room.guard.suspicion > 0.0, name, "a guard staring at a lit mime stayed calm")


## The gimmick's slowing scales the mime's walk, and the room ticks it each frame it runs,
## not after the escape.
func _test_gimmick_slows_and_ticks() -> void:
	var name := "gimmick_slows_and_ticks"
	var gimmick := TestGimmick.new()
	gimmick.slow = 0.5
	var room := await _load_room_with_gimmick(gimmick)
	room.guard.active = false
	room.mime.place_at(Vector2(100, 450))
	room.mime.walk_to(Vector2(800, 450))
	var ticks_before := gimmick.ticks
	for i in 60:
		await physics_frame
	var walked := room.mime.position.x - 100.0
	_check(absf(walked - Mime.SPEED * 0.5) < 6.0, name, "at half speed the mime walked %.1f in a second, not %.1f" % [walked, Mime.SPEED * 0.5])
	_check(gimmick.ticks - ticks_before == 60, name, "the gimmick ticked %d times in 60 frames" % (gimmick.ticks - ticks_before))
	room.finished = true
	var ticks_done := gimmick.ticks
	await physics_frame
	_check(gimmick.ticks == ticks_done, name, "the gimmick ticked after the escape")


## Walking on loud floor makes noises the nearest guard in earshot investigates; quiet
## floor does not carry to a far guard.
func _test_gimmick_loud_floor() -> void:
	var name := "gimmick_loud_floor"
	var gimmick := TestGimmick.new()
	gimmick.noise = 0.2
	var room := await _load_room_with_gimmick(gimmick)
	room.guard.target = null
	_stage_guard(room, Vector2(700, 450), Vector2.RIGHT, Vector2(100, 450))
	room.mime.walk_to(Vector2(300, 450))
	for i in 60:
		await physics_frame
	_check(not room.guard.senses.noise_heard, name, "quiet steps %.0f away were heard (reach %.0f)" % [room.guard.position.distance_to(room.mime.position), GuardBrain.HEARING_RANGE * 0.2])
	gimmick.noise = 1.0
	room.mime.walk_to(Vector2(500, 450))
	_check(await _wait_until(func() -> bool: return room.guard.senses.noise_heard, 60), name, "loud steps in earshot were not heard (guard at %s, mime at %s)" % [room.guard.position, room.mime.position])
	_check(room.guard.noise_point.distance_to(room.mime.position) < 100.0, name, "the guard heard the step at %s, not near the mime at %s" % [room.guard.noise_point, room.mime.position])


## A clue the gimmick shows a guard sends it to investigate there; a chasing guard is not
## shown clues.
func _test_gimmick_clue_investigated() -> void:
	var name := "gimmick_clue_investigated"
	var gimmick := TestGimmick.new()
	var room := await _load_room_with_gimmick(gimmick)
	_check(gimmick.mime == room.mime, name, "the room did not hand its mime to the gimmick")
	room.guard.target = null
	_stage_guard(room, Vector2(600, 450), Vector2.LEFT, room.entrance)
	gimmick.clue = Vector2(300, 450)
	await physics_frame
	await physics_frame
	_check(room.guard.senses.noise_heard and room.guard.noise_point == Vector2(300, 450), name, "the guard shown a clue did not investigate it (heard %s at %s)" % [room.guard.senses.noise_heard, room.guard.noise_point])
	room.guard.senses = GuardBrain.Senses.new()
	room.guard.senses.chasing = true
	gimmick.clue = Vector2(200, 450)
	await physics_frame
	_check(gimmick.clue == Vector2(200, 450), name, "a chasing guard was shown a clue")


## GimmickMix applies all its parts: light and slowing multiply (any shade hides), the
## loudest noise wins, the first part's clue is shown, and every part ticks and learns the
## mime.
func _test_gimmick_mix_combines() -> void:
	var name := "gimmick_mix_combines"
	var mix := GimmickMix.new()
	var a := TestGimmick.new()
	var b := TestGimmick.new()
	mix.add_child(a)
	mix.add_child(b)
	root.add_child(mix)
	a.light = 2.0
	b.light = 0.5
	a.slow = 0.5
	b.slow = 0.8
	a.noise = 0.3
	b.noise = 0.9
	_check(is_equal_approx(mix.light_at(Vector2.ZERO), 1.0) and is_equal_approx(mix.slow_at(Vector2.ZERO), 0.4) and is_equal_approx(mix.noise_at(Vector2.ZERO), 0.9), name, "mixed light %.2f, slow %.2f, noise %.2f (expected 1, 0.4, 0.9)" % [mix.light_at(Vector2.ZERO), mix.slow_at(Vector2.ZERO), mix.noise_at(Vector2.ZERO)])
	b.light = 0.0
	_check(mix.light_at(Vector2.ZERO) == 0.0, name, "one part's shade does not hide the mime")
	b.clue = Vector2(7, 7)
	_check(mix.clue_seen_by(null) == Vector2(7, 7), name, "the mix did not show its part's clue")
	a.clue = Vector2(1, 1)
	b.clue = Vector2(2, 2)
	_check(mix.clue_seen_by(null) == Vector2(1, 1) and b.clue == Vector2(2, 2), name, "the mix did not show the first part's clue (only)")
	var mime := (load("res://scenes/mime.tscn") as PackedScene).instantiate() as Mime
	mix.mime = mime
	mix.tick(0.1)
	_check(a.ticks == 1 and b.ticks == 1 and a.mime == mime and b.mime == mime, name, "a tick did not reach every part with the mime")
	mime.free()
	mix.queue_free()
	await process_frame


## Each wing's gimmick keeps its rules: the window band is lit and drifts; a burst pipe's
## puddle grows while it gushes and dries back to a damp patch, and its water slows and
## splashes (also inside the finale's mix); a parasol shades and walking prints the lawn (prints
## fade, and a catch wipes them); a searchlight pool lights and reveals the mime once, to a
## guard in earshot only.
func _test_wing_gimmicks() -> void:
	var name := "wing_gimmicks"
	var window := WindowLight.new()
	var band := Vector2(window.band_x(300.0), 300.0)
	_check(window.light_at(band) == WindowLight.LIT and window.light_at(band + Vector2(window.width, 0)) == WindowLight.DIM, name, "the window band is not lit with dim around it")
	window.tick(window.period / 4.0)
	_check(not is_equal_approx(window.band_x(300.0), band.x), name, "the window band does not drift")
	window.free()
	var pipes := Puddles.new()
	pipes.puddles = PackedVector3Array([Vector3(400, 300, 80)])
	pipes.beats = PackedVector2Array([Vector2(10.0, 0.0)])
	_check(pipes.gushing(0) and is_equal_approx(pipes.radius(0), 80.0 * Puddles.DAMP), name, "a pipe does not start gushing over a damp patch (radius %.1f)" % pipes.radius(0))
	var rim := Vector2(400 + 60.0, 300)
	_check(pipes.slow_at(rim) == 1.0 and pipes.noise_at(rim) == 0.0, name, "the floor beyond the damp patch is wet")
	pipes.tick(2.5)
	_check(pipes.gushing(0) and pipes.radius(0) > 80.0 * Puddles.DAMP and pipes.radius(0) < 80.0, name, "the puddle does not grow while the pipe gushes (radius %.1f)" % pipes.radius(0))
	pipes.tick(2.5)
	_check(not pipes.gushing(0) and is_equal_approx(pipes.radius(0), 80.0), name, "at half its rhythm the puddle is not full (%.1f) or the pipe still gushes" % pipes.radius(0))
	_check(pipes.slow_at(rim) == Puddles.SLOW and pipes.noise_at(rim) == Puddles.LOUD, name, "the full puddle does not slow and splash")
	_check(pipes.slow_at(Vector2(400, 300 + 80.0 * Puddles.FLATTEN + 2.0)) == 1.0 and pipes.slow_at(Vector2(400 + 82.0, 300)) == 1.0, name, "floor just outside the flat ellipse is wet")
	pipes.tick(4.0)
	_check(not pipes.gushing(0) and pipes.radius(0) < 40.0, name, "the puddle does not dry back while the pipe drips (radius %.1f)" % pipes.radius(0))
	var mix := GimmickMix.new()
	var in_mix := Puddles.new()
	in_mix.puddles = pipes.puddles
	in_mix.beats = PackedVector2Array([Vector2(10.0, 0.5)])
	mix.add_child(in_mix)
	_check(mix.slow_at(Vector2(400, 300)) == Puddles.SLOW and mix.noise_at(Vector2(400, 300)) == Puddles.LOUD, name, "the finale's mix does not take the puddle's slowing and splash")
	mix.free()
	pipes.free()
	var mime := (load("res://scenes/mime.tscn") as PackedScene).instantiate() as Mime
	root.add_child(mime)
	var lawn := Footprints.new()
	lawn.parasols = PackedVector3Array([Vector3(300, 300, 50)])
	lawn.mime = mime
	_check(lawn.light_at(Vector2(310, 300)) == 0.0 and lawn.light_at(Vector2(500, 300)) == 1.0, name, "the parasol does not shade, or the sun does not light")
	mime.place_at(Vector2(500, 400))
	mime.walking = true
	lawn.tick(0.1)
	mime.position = Vector2(500 + Footprints.PRINT_GAP, 400)
	lawn.tick(0.1)
	_check(lawn._prints.size() == 2, name, "walking %.0f printed %d prints, not 2" % [Footprints.PRINT_GAP, lawn._prints.size()])
	mime.walking = false
	lawn.tick(Footprints.PRINT_LIFE + 0.01)
	_check(lawn._prints.is_empty(), name, "prints did not fade after PRINT_LIFE")
	# A catch wipes the trail, also through the finale's mix.
	var trail_mix := GimmickMix.new()
	trail_mix.add_child(lawn)
	trail_mix.mime = mime
	mime.position = Vector2(700, 400)
	mime.walking = true
	trail_mix.tick(0.1)
	_check(lawn._prints.size() == 1, name, "the trail_mix did not pass its tick to the lawn")
	trail_mix.forget()
	_check(lawn._prints.is_empty(), name, "a catch (forget) did not wipe the prints through the trail_mix")
	mime.walking = false
	trail_mix.free()
	var lights := Searchlights.new()
	lights.orbits = PackedVector3Array([Vector3(400, 350, 0)])
	lights.mime = mime
	var near := (load("res://scenes/guard.tscn") as PackedScene).instantiate() as Guard
	var far := (load("res://scenes/guard.tscn") as PackedScene).instantiate() as Guard
	root.add_child(near)
	root.add_child(far)
	near.global_position = Vector2(500, 350)
	far.global_position = Vector2(400 + GuardBrain.HEARING_RANGE + 10.0, 350)
	mime.position = Vector2(400, 350)
	_check(lights.light_at(mime.position) == Searchlights.LIT and lights.light_at(Vector2(700, 350)) == Searchlights.NIGHT, name, "the pool is not lit with night around it")
	_check(lights.clue_seen_by(far) == Vector2.INF, name, "a guard out of earshot was shown the lit mime")
	_check(lights.clue_seen_by(near) == mime.position and lights.clue_seen_by(near) == Vector2.INF, name, "the lit mime was not revealed exactly once")
	mime.position = Vector2(700, 350)
	lights.tick(0.0)
	mime.position = Vector2(400, 350)
	_check(lights.clue_seen_by(near) == mime.position, name, "stepping into the pool again did not reveal the mime again")
	lights.free()
	near.free()
	far.free()
	mime.free()
	await process_frame


## A guard wades where the gimmick slows the floor: its patrol stride shrinks by slow_at.
func _test_guards_wade() -> void:
	var name := "guards_wade"
	var strides: Array[float] = []
	for slow: float in [1.0, Puddles.SLOW]:
		var gimmick := TestGimmick.new()
		gimmick.slow = slow
		var room := await _load_room_with_gimmick(gimmick)
		room.mime.place_at(Vector2(100, 480))
		var guard := room.guard
		guard.route = PackedVector2Array([Vector2(200, 260), Vector2(800, 260)])
		guard.reset()
		for i in 60:
			await physics_frame
		var from := guard.position
		for i in 30:
			await physics_frame
		strides.append(from.distance_to(guard.position))
	_check(strides[0] > 20.0 and is_equal_approx(strides[1] / strides[0], Puddles.SLOW), name, "a guard in water walked %.1f against %.1f on dry floor, not %.2f of it" % [strides[1], strides[0], Puddles.SLOW])


## A pipe with broken data (radius 0, period 0) is reported once each and left dry while a
## good one works; wing 2's rooms and wing 6's salon and grand gallery use Puddles (wing 6
## inside its mix), and no wing uses anything named after the old tide.
func _test_puddles_checked_and_wired() -> void:
	var name := "puddles_checked_and_wired"
	var pipes := Puddles.new()
	pipes.puddles = PackedVector3Array([Vector3(200, 300, 80), Vector3(500, 300, 0), Vector3(800, 300, 60)])
	pipes.beats = PackedVector2Array([Vector2(10, 0.5), Vector2(10, 0.5), Vector2(0, 0)])
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	root.add_child(pipes)
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 2, name, "broken pipes reported %d error(s), not 2" % (_game.errors.size() - errors_before))
	_check(pipes.wet(Vector2(200, 300)) and not pipes.wet(Vector2(500, 300)) and not pipes.wet(Vector2(800, 300)), name, "the good pipe is not wet or a broken one is")
	pipes.tick(0.1)
	await process_frame
	# The foam, streaks, crests and drops (and every gimmick's decoration) run on flourish:
	# room time, still under Reduce Motion.
	_check(pipes.flourish(1.5) == 1.5, name, "the decoration's clock is %.2f, not room time" % pipes.flourish(1.5))
	_game.set_setting("reduce_motion", true)
	_check(pipes.flourish(1.5) == 0.0, name, "Reduce Motion does not still the gimmick decoration")
	_game.set_setting("reduce_motion", false)
	pipes.free()
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	var rooms: Array[String] = []
	rooms.append_array((load(Content.WINGS[1]) as WingData).rooms)
	rooms.append_array(["res://scenes/wings/wing_06_salon.tscn", "res://scenes/wings/wing_06_gallery.tscn"])
	for path in rooms:
		var room := (load(path) as PackedScene).instantiate()
		var gimmick := room.get_node_or_null("Gimmick")
		var has_pipes := gimmick is Puddles or (gimmick is GimmickMix and (gimmick as GimmickMix).parts().any(func(part: Gimmick) -> bool: return part is Puddles))
		_check(has_pipes, name, "%s does not use Puddles" % path)
		room.free()


## A frame naming an unknown painting is reported and stays empty.
func _test_unknown_painting_reports() -> void:
	var name := "unknown_painting_reports"
	var picture := FramedPainting.new()
	_check(picture.picture() == null, name, "a painting has a picture before it is in the tree")
	picture.painting = "no_such_painting"
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	root.add_child(picture)
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and "no_such_painting" in _game.errors[-1], name, "an unknown painting was not reported (errors: %s)" % [_game.errors.slice(errors_before)])
	_check(picture.picture() == null, name, "an unknown painting shows a picture")
	var canvas := (load("res://scenes/forgery_canvas.tscn") as PackedScene).instantiate() as ForgeryCanvas
	root.add_child(canvas)
	var canvas_errors := _game.errors.size()
	_game.quiet_errors = true
	canvas.painting = "no_such_painting"
	_game.quiet_errors = false
	_check(_game.errors.size() == canvas_errors + 1 and "Forgery canvas" in _game.errors[-1], name, "the forgery canvas did not report an unknown painting (errors: %s)" % [_game.errors.slice(canvas_errors)])
	_check((canvas.get_node("Reference") as TextureRect).texture == null, name, "the forgery canvas shows a picture for an unknown painting")
	canvas.queue_free()
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	picture.queue_free()
	await process_frame


func _check(condition: bool, test_name: String, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [test_name, detail])


## On 16:9, 19.5:9 and 4:3 windows (and a notched safe area) the room is centred on the safe
## area, nothing of its 960x540 is cropped, a tap lands where the world is drawn, and every
## button of the results and the forgery canvas is at least 44x44 inside the safe area.
func _test_screen_fit() -> void:
	var name := "screen_fit"
	var room := await _load_room()
	room.guard.active = false
	var results := room.get_node("ResultsLayer/Results") as Results
	results.present([true, true, true] as Array[bool])
	var cases: Array[Array] = [
		[Vector2i(960, 540), Rect2()],
		[Vector2i(1170, 540), Rect2()],
		[Vector2i(720, 540), Rect2()],
		# A notched phone on its side: insets left and right, the home indicator below.
		[Vector2i(1170, 540), Rect2(65, 0, 1040, 511)],
	]
	for each in cases:
		_game.safe_area_override = each[1]
		root.size = each[0]
		_game.fit_screen()
		await process_frame
		var visible := _game.visible_rect()
		var safe := _game.safe_rect()
		var label := "window %s, safe %s" % [each[0], safe]
		var world := Rect2(root.canvas_transform * Vector2.ZERO, Content.BASE)
		_check(visible.encloses(world), name, "%s: the room at %s is cropped by the visible %s" % [label, world, visible])
		_check(absf(world.get_center().x - safe.get_center().x) <= 1.0, name, "%s: the room at %s is not centred on the safe area" % [label, world])
		var buttons: Array[Control] = [results.get_node("Panel/ReplayButton"), results.get_node("Panel/HomeButton"),
			room.get_node("EaselLayer/ForgeryCanvas/CloseButton"), room.get_node("EaselLayer/ForgeryCanvas/AssistButton"),
			room.get_node("PauseButton")]
		for menu_button in room.pause_menu.find_children("*", "Button"):
			buttons.append(menu_button)
		for button in buttons:
			var rect := button.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, button.size)
			_check(safe.grow(0.5).encloses(rect) and rect.size.x >= 44.0 and rect.size.y >= 44.0, name, "%s: %s at %s is not a 44x44 target inside the safe area" % [label, button.name, rect])
	results.hide()
	room.mime.place_at(Vector2(200, 400))
	await _tap_at(root.canvas_transform * Vector2(300, 420))
	await _wait_until(func() -> bool: return not room.mime.walking, 120)
	_check(room.mime.position.distance_to(Vector2(300, 420)) <= 4.0, name, "a tap on the drawn floor at (300, 420) walked the mime to %s" % room.mime.position)
	_game.safe_area_override = Rect2()
	root.size = BASE_WINDOW
	_game.fit_screen()
	_check(root.canvas_transform == Transform2D.IDENTITY, name, "back at 960x540 the room is not at the origin")


## A portrait window shows the rotate overlay and pauses the tree; landscape hides it and
## unpauses (a tree paused before stays paused).
func _test_rotate_overlay_pauses() -> void:
	var name := "rotate_overlay_pauses"
	root.size = Vector2i(540, 960)
	_game.fit_screen()
	_check(_game.is_rotate_overlay_shown() and paused, name, "a portrait window does not show the overlay and pause")
	var icon := _game.get_node("RotateLayer/RotateOverlay/Icon") as TextureRect
	_check(icon.texture != null and _game.visible_rect().encloses(icon.get_global_rect()), name, "the rotate icon is missing or off screen")
	root.size = BASE_WINDOW
	_game.fit_screen()
	_check(not _game.is_rotate_overlay_shown() and not paused, name, "landscape again does not hide the overlay and unpause")
	paused = true
	root.size = Vector2i(540, 960)
	_game.fit_screen()
	root.size = BASE_WINDOW
	_game.fit_screen()
	_check(paused, name, "a tree paused before the overlay was unpaused by it")
	paused = false
