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
		_test_cone_warms_with_suspicion,
		_test_stars,
		_test_save_shape,
		_test_save_load_write_and_corrupt,
		_test_guard_brain_priorities,
		_test_guard_brain_chase_and_noise,
		_test_forgery_scoring,
		_test_forgery_grades,
		_test_paintings_registry,
		_test_decoys_unique_per_wing,
		_test_canvas_traces_and_grades,
		_test_canvas_close_keeps_strokes,
		_test_grade_badge_shows_each_wing,
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
		_test_tilted_frame_straightened_after_catch,
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
		_test_keyboard_stays_on_its_floor,
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
		_test_escape_beat_skips,
		_test_room_hud,
		_test_room_decor,
		_test_sketch_found,
		_test_hint_after_catches,
		_test_wings_have_hints,
		_test_room_swap_cancel_and_locked_exit,
		_test_room_easel_paints_fake,
		_test_room_catch_while_painting,
		_test_canvas_leaves_approach_visible,
		_test_sloppy_fake_starts_search,
		_test_good_and_perfect_fakes_pass,
		_test_catch_cuts_inspection_short,
		_test_results_buttons,
		_test_new_best_detected,
		_test_results_celebrate,
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
		_test_room_at_night,
		_test_wing_floors,
		_test_puddles_clear_of_partitions,
		_test_guards_patrol_round_partitions,
		_test_patrol_paths_clear_walls,
		_test_rig_walk_cycle,
		_test_rig_rest_life,
		_test_rig_joints_bend,
		_test_mime_faces_its_way,
		_test_ghost_faces_travel,
		_test_no_flash_rates,
		_test_ghost_replay_visits,
		_test_ghost_mime_until_escape,
		_test_tension_stems,
		_test_tension_eases,
		_test_chase_sting_once,
		_test_room_drives_tension,
		_test_dash_double_tap,
		_test_dash_shift,
		_test_dash_footfalls_heard,
		_test_close_call_heartbeat,
		_test_near_miss,
		_test_routes_never_double_tap,
		_test_finale_due_once,
		_test_finale_skips_and_returns,
		_test_hideout_replays_finale,
		_test_challenges_judged,
		_test_save_challenges,
		_test_record_escape_challenges,
		_test_results_challenge_badges,
		_test_hub_challenge_pips,
		_test_hideout_challenge_badges,
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
	# The museum at night behind it, the mime sneaking across; the play button's focus ring the
	# theme's gilt glow (a round border, not the engine's white box).
	var night := current_scene.get_node_or_null("Night") as TitleScene
	var walked_from := night.mime.phase if night != null else 0.0
	for i in 30:
		await process_frame
	_check(night != null and night.mime.phase != walked_from, name, "the title has no night scene with the mime sneaking across")
	var focus := (current_scene.get_node("PlayButton") as Button).get_theme_stylebox("focus") as StyleBoxFlat
	_check(focus != null and not focus.draw_center and focus.border_width_top > 0 and focus.border_color.r > 0.9 and focus.border_color.b < 0.5 and focus.corner_radius_top_left >= 64, name, "the play button's focus ring is not the round gilt glow (%s)" % focus)
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
	# Under the guard's nose the mime is seen at once; a glimpse's grace is only for the far
	# reach, and shade still hides it.
	_check(Detection.close_seen(0.1, true, Detection.CLOSE_RANGE) == Detection.SEEN_AT and Detection.close_seen(0.8, true, 10.0) == 0.8, name, "a mime within CLOSE_RANGE is not seen at once")
	_check(Detection.close_seen(0.1, true, Detection.CLOSE_RANGE + 1.0) == 0.1 and Detection.close_seen(0.1, false, 10.0) == 0.1 and Detection.close_seen(0.1, true, 10.0, 0.0) == 0.1, name, "close_seen raised suspicion beyond reach, unseen or in shade")
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
	for track in Audio.MUSIC_TRACKS:
		if Audio.stem_for(track) != "":
			tracks.append(Audio.stem_for(track))
	tracks.append(Audio.STING)
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
	for id: StringName in [&"tiptoe", &"tilt", &"hide", &"unhide", &"swap", &"guard_alert", &"caught", &"toss", &"splat", &"ui_tap", &"pause", &"resume"]:
		_check(id in played, name, "%s did not sound; played %s" % [id, played])
	played.clear()
	room._escape()
	await create_timer(Room.escape_beat_time() + (Results.STAR_GAP + Results.POP_TIME) * 3.0 + 0.1).timeout
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
	# A version 1 save (before sketches) upgrades: every best and setting kept, no sketch yet.
	var v1 := Save.parse('{"version": 1, "wings": {"wing_01": {"stars": 3, "time": 61.5}, "wing_02": {"stars": 1, "time": 140}}, "settings": {"music": false, "sound": true, "reduce_motion": true, "assist": false}}', problems)
	_check(problems.is_empty() and v1["version"] == Save.VERSION and v1["wings"] == {"wing_01": {"stars": 3, "time": 61.5}, "wing_02": {"stars": 1, "time": 140.0}} and v1["sketches"] == {}
			and v1["settings"] == {"music": false, "sound": true, "reduce_motion": true, "assist": false}, name, "a version 1 save does not upgrade with its bests and settings: %s, %s" % [v1, problems])
	_check(Save.record_sketch(data, "wing_02") and not Save.record_sketch(data, "wing_02") and Save.has_sketch(data, "wing_02") and not Save.has_sketch(data, "wing_01"), name, "a found sketch is not kept once: %s" % [data["sketches"]])
	back = Save.parse(Save.to_json(data), problems)
	_check(problems.is_empty() and back == data, name, "a save with a sketch does not read back as written: %s, %s" % [back, problems])
	for bad: String in ["{", "[]", '{"version": 4, "wings": {}}', '{"version": 1, "wings": []}', '{"version": 1, "wings": {"wing_01": {"stars": 4, "time": 1}}}',
			'{"version": 1, "wings": {"wing_01": {"stars": 1.5, "time": 1}}}', '{"version": 1, "wings": {}, "settings": {"music": 1}}',
			'{"version": 2, "wings": {}, "sketches": []}', '{"version": 2, "wings": {}, "sketches": {"wing_01": 1}}']:
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
	_check(credited == Paintings.ALL, name, "SOURCES.json ids %s are not Paintings.ALL %s" % [credited, Paintings.ALL])
	var all := Paintings.IDS.duplicate()
	all.append_array(Paintings.DECOYS)
	_check(Paintings.ALL == all, name, "Paintings.ALL is not the masterpieces then the decoys")
	for id in Paintings.ALL:
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
		_check(listed == Paintings.ALL, name, "%s's painting choices %s are not Paintings.ALL" % [script.resource_path, hint])

## Within a wing no decoy painting (a tilt frame's or a hiding portrait's) hangs twice, and
## none is the wing's own masterpiece; every portrait's face sits inside its frame.
func _test_decoys_unique_per_wing() -> void:
	var name := "decoys_unique_per_wing"
	for wing_path: String in Content.WINGS:
		var wing := load(wing_path) as WingData
		var hung: Array[String] = []
		for room_path: String in wing.rooms:
			var room := (load(room_path) as PackedScene).instantiate()
			var decoys: Array[Node] = room.get_node("Frames").get_children()
			decoys.append_array(room.get_node("Portraits").get_children())
			for decoy in decoys:
				var painting: String = decoy.get("painting")
				_check(painting not in hung, name, "%s: %s hangs %s again" % [wing_path.get_file(), room_path.get_file(), painting])
				_check(painting != wing.painting, name, "%s: %s hangs the wing's own masterpiece as a decoy" % [wing_path.get_file(), room_path.get_file()])
				hung.append(painting)
				if decoy is HidingPortrait:
					var inside := Rect2(-HidingPortrait.SIZE / 2.0, HidingPortrait.SIZE).grow(-6.0)
					_check(inside.has_point((decoy as HidingPortrait).face), name, "%s's portrait face %s is outside its frame" % [room_path.get_file(), (decoy as HidingPortrait).face])
			room.free()


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
	_check(grade.visible and grade.texture == ForgeryCanvas.GRADE_ICONS[Forgery.Grade.PERFECT] and grade.rotation == 0.0, name, "an exact fake does not show the Perfect badge, upright")
	_check((grade.get_node("Picture") as TextureRect).texture == Paintings.SCANS[StringName(canvas.painting)], name, "the badge does not show the traced painting")
	_check(await _wait_until(func() -> bool: return not result.is_empty(), 120), name, "painted never came after the last stroke")
	_check(not result.is_empty() and Forgery.grade(result[0]) == Forgery.Grade.PERFECT, name, "an exact fake painted %s, not Perfect" % [result])
	_check(not canvas.visible, name, "the canvas stays open after painting")
	canvas.open()
	_check(canvas.traced.is_empty(), name, "reopening a finished canvas keeps the old strokes")
	canvas.queue_free()
	await process_frame


## In every wing the grade badge shows the painting just traced (its scan, through its
## style) in the grade's frame, tilted only for Sloppy; an unknown painting at grading is
## reported (log and badge) and the frame still shows, empty.
func _test_grade_badge_shows_each_wing() -> void:
	var name := "grade_badge_shows_each_wing"
	var qualities: Array[float] = [0.2, Forgery.ASSIST_QUALITY, 1.0]
	for w in Content.WINGS.size():
		var painting := (load(Content.WINGS[w]) as WingData).painting
		var result: Array[float] = []
		var canvas := _make_canvas(result)
		canvas.painting = painting
		canvas.open()
		canvas.traced = canvas.ghosts.duplicate()
		var fake_quality := qualities[w % qualities.size()]
		canvas._finish(fake_quality)
		var grade := canvas.get_node("Grade") as TextureRect
		var picture := grade.get_node("Picture") as TextureRect
		var fake_grade := Forgery.grade(fake_quality)
		_check(grade.visible and grade.texture == ForgeryCanvas.GRADE_ICONS[fake_grade], name, "wing %d: the %s badge does not show its frame" % [w + 1, Forgery.Grade.keys()[fake_grade]])
		_check(picture.visible and picture.texture == Paintings.SCANS[StringName(painting)], name, "wing %d: the badge shows %s, not the traced %s" % [w + 1, picture.texture.resource_path if picture.texture != null else "nothing", painting])
		_check(picture.material is ShaderMaterial and (picture.material as ShaderMaterial).shader == Paintings.STYLES[StringName(painting)], name, "wing %d: the badge's %s is not drawn through its style" % [w + 1, painting])
		_check(is_equal_approx(grade.rotation_degrees, ForgeryCanvas.GRADE_TILTS[fake_grade]) and (grade.rotation != 0.0) == (fake_grade == Forgery.Grade.SLOPPY), name, "wing %d: the %s badge is tilted %.1f degrees" % [w + 1, Forgery.Grade.keys()[fake_grade], grade.rotation_degrees])
		canvas.close()
		canvas.free()
	var unknown_result: Array[float] = []
	var unknown := _make_canvas(unknown_result)
	unknown.open()
	unknown.traced = unknown.ghosts.duplicate()
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	unknown.painting = "no_such_painting"
	unknown._finish(1.0)
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 2 and "grade badge" in _game.errors[-1] and "no_such_painting" in _game.errors[-1], name, "an unknown painting at grading was not reported (errors: %s)" % [_game.errors.slice(errors_before)])
	_check((_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible, name, "an unknown painting at grading shows no error badge")
	var frame := unknown.get_node("Grade") as TextureRect
	_check(frame.visible and frame.texture == ForgeryCanvas.GRADE_ICONS[Forgery.Grade.PERFECT] and (frame.get_node("Picture") as TextureRect).texture == null, name, "an unknown painting's badge does not show its empty frame")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	unknown.close()
	unknown.free()


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


## The slice room hiding the sketch in `source` (a path under the room), made current.
func _load_sketch_room(source: NodePath) -> Room:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	room.sketch_in = source
	var old := current_scene
	root.add_child(room)
	current_scene = room
	if old != null:
		old.queue_free()
	for i in 3:
		await physics_frame
	var map := room.get_world_2d().navigation_map
	await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60)
	room.guard.active = false
	return room


## The hidden sketch: unseen until its hiding place is used (a tilted frame, a portrait hidden
## in), then it flutters down and lies on the floor; a tap (or E) picks it up, which the run
## keeps and the HUD and results show; a dropped sketch lies there again on a later visit;
## Game.record_sketch saves it for a wing file's run; the hub door and the hideout show a
## found sketch; a bad sketch_in is reported.
func _test_sketch_found() -> void:
	var name := "sketch_found"
	var room := await _load_sketch_room(^"Frames/FrameA")
	if room == null:
		return
	var sketch := room.sketch
	_check(sketch != null and sketch.state == Sketch.State.HIDDEN and sketch.texture == Paintings.SKETCHES[StringName(room.run.wing.painting)], name, "the sketch is not tucked away unseen with its wing's drawing")
	await _tap_at(sketch.position)
	_check(not room.sketch_intent, name, "a tap on a hidden sketch's spot heads for it")
	room._tilt(room.get_node("Frames/FrameA") as TiltFrame)
	_check(sketch.state == Sketch.State.FALLING and room.run.sketch_dropped and _game.audio.played.has(&"sketch_drop"), name, "tilting its frame did not let the sketch fall")
	await create_timer(Sketch.FALL_TIME + 0.1).timeout
	_check(sketch.state == Sketch.State.LYING, name, "the sketch did not land")
	var map := room.get_world_2d().navigation_map
	_check(NavigationServer2D.map_get_closest_point(map, sketch.position).distance_to(sketch.position) < 1.0, name, "the sketch lies off the walkable floor at %s" % sketch.position)
	await _tap_at(sketch.position)
	_check(room.sketch_intent, name, "a tap on the sketch does not walk the mime to it")
	_check(await _wait_until(func() -> bool: return room.run.has_sketch, 900), name, "the mime never picked the sketch up")
	_check(sketch.state == Sketch.State.TAKEN and _game.audio.played.has(&"sketch_found"), name, "picking it up did not take it with its sound")
	await process_frame
	await process_frame
	_check(room.hud.has_sketch, name, "the HUD does not show the sketch")
	room.mime.carrying = true
	room._escape()
	room._skip_escape()
	var results := room.get_node("ResultsLayer/Results") as Results
	await create_timer(Results.STAR_GAP * 6.0 + Results.POP_TIME + 0.2).timeout
	_check(results.sketch.visible and results.sketch.texture == sketch.texture, name, "the results do not show the sketch")
	# By E, from a portrait, and lying again on a later visit after it fell.
	_game.run = null
	var portrait_room := await _load_sketch_room(^"Portraits/PortraitA")
	var portrait := portrait_room.get_node("Portraits/PortraitA") as HidingPortrait
	portrait_room._hide_in(portrait)
	_check(portrait_room.sketch.state == Sketch.State.FALLING, name, "hiding in its portrait did not let the sketch fall")
	portrait_room._step_out()
	await create_timer(Sketch.FALL_TIME + 0.1).timeout
	portrait_room.mime.place_at(portrait_room.sketch.position + Vector2(20, 0))
	portrait_room._keys.interacted.emit()
	_check(portrait_room.sketch_intent, name, "E beside the sketch does not head for it")
	_check(await _wait_until(func() -> bool: return portrait_room.run.has_sketch, 600), name, "E never picked the sketch up")
	var revisit := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	revisit.sketch_in = ^"Frames/FrameB"
	var run := WingRun.new((load(Content.WINGS[0]) as WingData))
	run.wing = run.wing.duplicate()
	run.wing.rooms = [ROOM_PATH]
	run.sketch_dropped = true
	_game.run = run
	var old := current_scene
	root.add_child(revisit)
	current_scene = revisit
	old.queue_free()
	await physics_frame
	_check(revisit.sketch.state == Sketch.State.LYING, name, "a sketch that fell on this play does not lie there on a later visit")
	_game.run = null
	# Saved at once for a wing file's run; shown on the hub door and pinned in the hideout.
	_game.save = Save.defaults()
	_game.run = WingRun.new(load(Content.WINGS[1]) as WingData)
	_game.record_sketch()
	_check(Save.has_sketch(_game.save, "wing_02") and Save.has_sketch(Save.parse(FileAccess.get_file_as_string(_game.save_path), [] as Array[String]), "wing_02"), name, "the sketch was not saved at once")
	_game.run = null
	_game.goto(GameState.Flow.HUB)
	await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 300)
	var hub := current_scene as Hub
	_check(hub != null and hub.wing_doors[1].sketch and not hub.wing_doors[0].sketch, name, "the hub door does not show the found sketch")
	_game.goto(GameState.Flow.HIDEOUT)
	await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 300)
	var hideout := current_scene as Hideout
	_check(hideout != null and hideout.get_node_or_null("Originals/Sketch2") is Sprite2D and hideout.get_node_or_null("Originals/Sketch1") == null, name, "the hideout does not pin the found sketch")
	# A sketch_in that is not one of the room's frames or portraits is reported.
	_game.quiet_errors = true
	var errors_before := _game.errors.size()
	var stray := await _load_sketch_room(^"Actors/Mime")
	_check(_game.errors.size() == errors_before + 1 and stray.sketch == null, name, "a bad sketch_in is not reported")
	_game.quiet_errors = false
	_game.save = Save.defaults()


## A play of a one-room wing of the slice room (so a room loaded into it is that wing's room 0,
## not a room on its own with a run of its own).
func _hint_run() -> WingRun:
	var run := WingRun.new((load(Content.WINGS[0]) as WingData))
	run.wing = run.wing.duplicate()
	run.wing.rooms = [ROOM_PATH]
	return run


## The slice room hinting at `way_in` and `way_out`, loaded into `run` and made current.
func _load_hint_room(run: WingRun, way_in: Array, way_out: Array) -> Room:
	var room := (load(ROOM_PATH) as PackedScene).instantiate() as Room
	room.hint_in = way_in
	room.hint_out = way_out
	_game.run = run
	var old := current_scene
	root.add_child(room)
	current_scene = room
	if old != null:
		old.queue_free()
	for i in 3:
		await physics_frame
	room.guard.active = false
	return room


## The trick's hint: none before HINT_AFTER catches in the room; from the third (a toss's) it
## shows the way in before the swap and the way out while carrying; it stays across leaving
## and coming back on the same play; a new play starts at none; Reduce Motion holds it
## steady; a room without hint data has none; a bad hint entry is reported.
func _test_hint_after_catches() -> void:
	var name := "hint_after_catches"
	var run := _hint_run()
	var room := await _load_hint_room(run, [^"Frames/FrameA"], [Vector2(300, 400), ^"Portraits/PortraitB"])
	var way_in := room.hints[0]
	var way_out := room.hints[1]
	if way_in == null or way_out == null:
		_check(false, name, "the room made no hint for a way (in %s, out %s)" % [way_in, way_out])
		return
	var frame := room.get_node("Frames/FrameA") as TiltFrame
	var portrait := room.get_node("Portraits/PortraitB") as HidingPortrait
	_check(way_in.rects == ([frame.rect()] as Array[Rect2]) and way_in.spots.is_empty(), name, "the way in's hint is not FrameA: %s, %s" % [way_in.rects, way_in.spots])
	_check(way_out.rects == ([portrait.rect()] as Array[Rect2]) and way_out.spots == PackedVector2Array([Vector2(300, 400)]), name, "the way out's hint is not the spot and PortraitB: %s, %s" % [way_out.rects, way_out.spots])
	_check(way_in.material == Room.GLOW and way_in.z_index == Room.HINT_Z, name, "the hint is not drawn in the room's glow under the walkers")
	for caught in Room.HINT_AFTER:
		_check(not way_in.visible and not way_out.visible, name, "a hint shows after %d catch(es)" % caught)
		room._on_caught()
		await _wait_until(func() -> bool: return not room.tossing, 120)
	_check(run.room_catches[0] == Room.HINT_AFTER and way_in.visible and not way_out.visible, name, "the third catch does not show the way in's hint alone (catches %s, in %s, out %s)" % [run.room_catches, way_in.visible, way_out.visible])
	room.mime.has_fake = true
	room._swap()
	_check(way_out.visible and not way_in.visible, name, "carrying the original does not switch to the way out's hint")
	room._give_run()
	var again := await _load_hint_room(run, [^"Frames/FrameA"], [Vector2(300, 400)])
	_check(again.hints[1].visible and not again.hints[0].visible, name, "coming back into the room on the same play loses the hint")
	_game.set_setting("reduce_motion", true)
	var still := again.hints[1].breath()
	await create_timer(0.3).timeout
	_check(is_equal_approx(again.hints[1].breath(), still) and is_equal_approx(still, RoomHint.STEADY), name, "under Reduce Motion the hint still breathes")
	_game.set_setting("reduce_motion", false)
	var fresh := await _load_hint_room(_hint_run(), [^"Frames/FrameA"], [])
	_check(not fresh.hints[0].visible and fresh.hints[1] == null, name, "a new play starts with the hint showing, or a way without data has one")
	var bare := await _load_hint_room(_hint_run(), [], [])
	_check(bare.hints == ([null, null] as Array[RoomHint]) and bare.find_children("*", "RoomHint", false, false).is_empty(), name, "a room without hint data makes a hint")
	_game.quiet_errors = true
	var errors_before := _game.errors.size()
	var stray := await _load_hint_room(_hint_run(), [^"Actors/Mime", ^"Frames/Nowhere", 7, ^"Frames/FrameB"], [])
	_check(_game.errors.size() == errors_before + 3 and stray.hints[0].rects == ([(stray.get_node("Frames/FrameB") as TiltFrame).rect()] as Array[Rect2]), name, "bad hint entries are not reported one each (errors %d)" % (_game.errors.size() - errors_before))
	_game.quiet_errors = false
	_game.run = null


## Every wing room with a trick hints at it each way it is crossed: the way in everywhere, the
## way out everywhere but the masterpiece's room (the mime turns back there); every entry is
## one of the room's frames or portraits or a floor spot, and every bot trick tap lands on a
## hinted frame or portrait or by a hinted spot; trick-free rooms have no hint.
func _test_wings_have_hints() -> void:
	var name := "wings_have_hints"
	for path in Content.WINGS:
		var wing := load(path) as WingData
		var targets: Array[Rect2] = []
		for i in wing.rooms.size():
			var room := (load(wing.rooms[i]) as PackedScene).instantiate() as Room
			var label := "%s room %d (%s)" % [path, i, wing.rooms[i].get_file()]
			if i in wing.trick_free:
				_check(room.hint_in.is_empty() and room.hint_out.is_empty(), name, "%s is trick-free but has a hint" % label)
			else:
				_check(not room.hint_in.is_empty(), name, "%s has no hint on the way in" % label)
				_check(not room.hint_out.is_empty() or room.has_node("Masterpiece"), name, "%s has no hint on the way out" % label)
			for entry: Variant in room.hint_in + room.hint_out:
				var target: Node = room.get_node_or_null(entry) if entry is NodePath else null
				if entry is Vector2:
					targets.append(Rect2(entry, Vector2.ZERO).grow(RoomHint.RING_RADIUS))
				elif target is TiltFrame and target.get_parent() == room.get_node("Frames"):
					targets.append((target as TiltFrame).rect())
				elif target is HidingPortrait and target.get_parent() == room.get_node("Portraits"):
					targets.append((target as HidingPortrait).rect())
				else:
					_check(false, name, "%s hints at %s, not a frame, portrait or floor spot" % [label, entry])
			room.free()
		for trick in wing.bot_tricks:
			var tap := wing.bot_route[trick]
			_check(targets.any(func(target: Rect2) -> bool: return target.has_point(tap)), name, "%s: trick tap %d at %s is on no hint" % [path, trick, tap])


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


## Seen in the open, the mime is caught and tossed to the entrance while the guard dusts off
## its hands; taps are ignored during the toss; it lands flat and dizzy and recovers; then
## the guard restarts its route and the timer has kept running.
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
	await physics_frame
	_check(room.guard.rig.fidget == CharacterRig.Fidget.DUST and _game.audio.played.has(&"dust_hands"), name, "the catching guard does not dust off its hands (fidget %s, sounds %s)" % [room.guard.rig.fidget, _game.audio.played])
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
	# The landing is slapstick: flattened and seeing stars, then back to itself.
	_check(room.mime.rig.squash.y < 0.8 and room.mime.dizzy_left > 0.0, name, "the mime did not land flat and dizzy (squash %s, dizzy %.2f)" % [room.mime.rig.squash, room.mime.dizzy_left])
	_check(room.guard.rig.fidget == CharacterRig.Fidget.NONE, name, "the reset guard still dusts its hands")
	for i in ceili(Mime.DIZZY_TIME * 60.0) + 2:
		await physics_frame
	_check(room.mime.rig.squash.is_equal_approx(Vector2.ONE) and room.mime.dizzy_left == 0.0, name, "the mime did not recover from the splat (squash %s, dizzy %.2f)" % [room.mime.rig.squash, room.mime.dizzy_left])


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
## standing before it walks on. Facing is compared within FACING_TOLERANCE radians: the leg
## follows the navmesh's path, whose points carry float noise far below a visible angle.
func _test_guard_pauses_facing_its_leg() -> void:
	var name := "guard_pauses_facing_its_leg"
	const FACING_TOLERANCE := 0.001
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
	_check(room.guard.position == corner and absf(room.guard.facing.angle_to(first_leg)) < FACING_TOLERANCE, name, "during the pause the guard faces %s, not its finished leg %s" % [room.guard.facing, first_leg])
	for i in 6:
		await physics_frame
	var next_leg := (room.guard.route[2] - corner).normalized()
	# It turns toward the next leg at TURN_RATE: not snapped, and there within the turn's time.
	_check(absf(room.guard.facing.angle_to(next_leg)) > FACING_TOLERANCE, name, "the guard snapped to its next leg instead of turning")
	_check(room.guard.position == corner, name, "the guard walked off at %s mid-turn (sideways to the way it faces)" % room.guard.position)
	for i in ceili(absf(first_leg.angle_to(next_leg)) / Guard.TURN_RATE * 60.0) + 2:
		await physics_frame
	_check(absf(room.guard.facing.angle_to(next_leg)) < FACING_TOLERANCE, name, "after the pause and its turn the guard faces %s, not its next leg %s" % [room.guard.facing, next_leg])


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


## A frame tilted just before a catch is still straightened: the toss resets the guards
## (wiping the noise they heard), so the room has the nearest in earshot hear it again.
func _test_tilted_frame_straightened_after_catch() -> void:
	var name := "tilted_frame_straightened_after_catch"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var frame := room.get_node("Frames/FrameB") as TiltFrame
	room._tilt(frame)
	room._on_caught()
	await create_timer(Room.TOSS_SHAKE + Room.TOSS_FLIGHT + 0.2).timeout
	_check(frame.tilted and room.guard.intent == GuardBrain.Intent.INVESTIGATE, name, "after the toss the guard does not go to the tilted frame (intent %s)" % _intent_name(room.guard.intent))
	_check(await _wait_until(func() -> bool: return not frame.tilted, 1200), name, "the frame tilted before the catch was never straightened (guard %s at %s)" % [_intent_name(room.guard.intent), room.guard.position])


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
	# Breathing at rest moves the body by at most this (its hips kept still): a bob is more.
	var breath := -room.mime.rig.hip.y * CharacterRig.BREATH_DEPTH
	for i in 20:
		await physics_frame
		await process_frame
		bobbed = bobbed or absf(room.get_node("Actors/Mime/Rig/Body").position.y) > breath
	_check(bobbed, name, "the walking mime does not bob")
	await _walk_trace(room.mime, 300)
	for i in 6:
		await process_frame
	_check(room.mime.rig.stride == 0.0 and absf(room.get_node("Actors/Mime/Rig/Body").position.y) <= breath + 0.001, name, "the mime still bobs standing still")
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


## Every room is at night (a CanvasModulate of Room.NIGHT) and what gives light or is
## read (the guard's cone and eyes, the pause button, the fake's icon) is unshaded; a wing's
## first room has no entry doorway, only its exit door on the left.
func _test_room_at_night() -> void:
	var name := "room_at_night"
	var room := await _load_room()
	if room == null:
		return
	var night := room.get_node_or_null("Night") as CanvasModulate
	_check(night != null and night.color == Room.NIGHT, name, "the room has no night tint")
	for path: String in ["PauseButton", "FakeIcon", "Actors/Guard", "Actors/Guard/Cone", "Hud"]:
		var item := room.get_node(path) as CanvasItem
		_check(item.material is CanvasItemMaterial and (item.material as CanvasItemMaterial).light_mode == CanvasItemMaterial.LIGHT_MODE_UNSHADED, name, "%s is not lit against the night" % path)
	# The cone is the lantern's light: added over the floor, through the light texture.
	var cone := room.get_node("Actors/Guard/Cone") as Polygon2D
	_check((cone.material as CanvasItemMaterial).blend_mode == CanvasItemMaterial.BLEND_MODE_ADD and cone.texture == Guard.CONE_LIGHT and cone.uv.size() == cone.polygon.size(), name, "the cone is not the lantern's added light")
	_check(room.guard.rig.find_child("Lantern", true, false) is Sprite2D, name, "the guard carries no lantern")
	# What the player uses is lifted out of the dark; the characters draw through the night material.
	var lights := room.get_node_or_null("Lights") as RoomLights
	var painting_count := room.get_node("Frames").get_child_count() + room.get_node("Portraits").get_child_count() + (1 if room.masterpiece != null else 0)
	_check(lights != null and lights.paintings.size() == painting_count, name, "not every painting has its picture light")
	var boosted: Array[CanvasItem] = [room.masterpiece, room.easel]
	boosted.append_array(room.doors)
	boosted.append_array(room.get_node("Frames").get_children())
	boosted.append_array(room.get_node("Portraits").get_children())
	for item in boosted:
		_check(item.modulate.is_equal_approx(Room.lit_boost()), name, "%s is not picked out of the night" % item.name)
	var night_lit := Room.lit_boost() * Room.NIGHT
	_check(is_equal_approx(night_lit.r, Room.LIT_SHARE) and is_equal_approx(night_lit.b, Room.LIT_SHARE), name, "the boost does not cancel the night to LIT_SHARE")
	for rig: CharacterRig in [room.mime.rig, room.guard.rig]:
		_check(rig.material is ShaderMaterial and (rig.material as ShaderMaterial).shader == Room.RIG_NIGHT and rig.get_children().all(func(part: Node) -> bool: return not part is Sprite2D or (part as CanvasItem).use_parent_material), name, "%s does not draw through the night material" % rig.get_parent().name)
	for wing: String in Content.WINGS:
		var first := (load((load(wing) as WingData).rooms[0]) as PackedScene).instantiate()
		var lefts := 0
		for door in first.get_node("Doors").get_children():
			lefts += 1 if (door as Node2D).position.x < 480.0 else 0
		_check(first.get_children().all(func(each: Node) -> bool: return not each.name.begins_with("DoorArt")) and lefts == 1, name, "%s's first room shows an entry doorway or has %d doors on the left" % [wing.get_file(), lefts])
		first.free()


## Each wing's rooms are floored in that wing's own tile (tools/floors.py), repeating across
## the floor, and their display walls (Partition) are built in the wing's own style, never
## the plain museum one; no two wings share a tile or a style.
func _test_wing_floors() -> void:
	var name := "wing_floors"
	var tiles: Array[Texture2D] = []
	var styles: Array[Partition.Style] = []
	for wing: String in Content.WINGS:
		var tile: Texture2D = null
		var style := Partition.Style.MUSEUM
		for path: String in (load(wing) as WingData).rooms:
			var room := (load(path) as PackedScene).instantiate()
			var ground := room.get_node("Floor") as Polygon2D
			_check(ground.texture != null and ground.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED, name, "%s's floor is not tiled" % path.get_file())
			if tile == null:
				tile = ground.texture
			_check(ground.texture == tile, name, "%s's floor is not its wing's tile" % path.get_file())
			for each in room.get_node("Actors").get_children():
				if each is Partition:
					if style == Partition.Style.MUSEUM:
						style = (each as Partition).style
					_check((each as Partition).style == style and style != Partition.Style.MUSEUM, name, "%s's %s is not built in its wing's style" % [path.get_file(), each.name])
			room.free()
		_check(not tile in tiles, name, "%s shares its floor tile with another wing" % wing.get_file())
		tiles.append(tile)
		_check(not style in styles, name, "%s shares its display walls' style with another wing" % wing.get_file())
		styles.append(style)


## No display wall stands in water: in every wing room, each burst pipe's puddle at full
## size keeps PUDDLE_CLEARANCE off every Partition's footprint, and no wall's face (drawn
## above its footprint) hides a puddle behind it.
func _test_puddles_clear_of_partitions() -> void:
	var name := "puddles_clear_of_partitions"
	const PUDDLE_CLEARANCE := 12.0
	for wing: String in Content.WINGS:
		for path: String in (load(wing) as WingData).rooms:
			var room := (load(path) as PackedScene).instantiate()
			var waters: Array[Puddles] = []
			var walls: Array[Partition] = []
			var pending: Array[Node] = [room]
			while not pending.is_empty():
				var node: Node = pending.pop_back()
				if node is Puddles:
					waters.append(node as Puddles)
				elif node is Partition:
					walls.append(node as Partition)
				pending.append_array(node.get_children())
			for water in waters:
				for puddle in water.puddles:
					var centre := Vector2(puddle.x, puddle.y)
					for wall in walls:
						var foot := Rect2(wall.position.x - wall.width / 2.0, wall.position.y - wall.depth, wall.width, wall.depth)
						var face := Rect2(foot.position.x, wall.position.y - wall.height - wall.depth, wall.width, wall.height + wall.depth)
						var standing := _ellipse_meets(centre, puddle.z + PUDDLE_CLEARANCE, foot)
						var hidden := centre.y < wall.position.y and _ellipse_meets(centre, puddle.z, face)
						_check(not standing and not hidden, name, "%s: %s %s the puddle at %s" % [path.get_file(), wall.name, "stands in" if standing else "hides", puddle])
			room.free()


## Guards patrol round display walls, never through them, nor brushing them: in wing 2's
## gallery a guard sent up and down x 300 runs straight across its left display wall; over
## its loops no guard's feet ever come within Partition.WALKER_CLEARANCE of a footprint (so
## no body overlaps a wall), and the guard still reaches the waypoints either side of it.
func _test_guards_patrol_round_partitions() -> void:
	var name := "guards_patrol_round_partitions"
	var room := await _load_wing_room(name, "res://scenes/wings/wing_02_gallery.tscn")
	if room == null:
		return
	var across := room.guards[1]
	across.route = PackedVector2Array([Vector2(300, 330), Vector2(300, 490)])
	across.reset()
	var feet := _footprints(room)
	# Walkers cut a path's corner by their agents' path_desired_distance; the carve allows
	# Partition.CORNER_SLACK for it.
	for walker: Node in [room.guard, room.mime]:
		var agent := walker.get_node("Agent") as NavigationAgent2D
		_check(agent.path_desired_distance <= Partition.CORNER_SLACK, name, "%s turns corners %.1f early, more than Partition.CORNER_SLACK" % [walker.name, agent.path_desired_distance])
	for guard in room.guards:
		guard.target = null
	var brushed := []
	var reached := {}
	for frame in 1500:
		await physics_frame
		for guard in room.guards:
			var gap := _clearance(guard.position, feet)
			if gap < Partition.WALKER_CLEARANCE - 0.5:
				brushed.append([guard.name, guard.position.round(), snappedf(gap, 0.1)])
		for point: Vector2 in [Vector2(300, 330), Vector2(300, 490)]:
			if across.position.distance_to(point) < 1.0:
				reached[point] = true
	_check(brushed.is_empty(), name, "guards came within a body of a partition at [name, at, gap] %s" % [brushed.slice(0, 3)])
	_check(reached.size() == 2, name, "the guard did not reach the waypoints either side of the display wall (reached %s)" % [reached.keys()])


## Every guard's patrol keeps clear of every display wall, in every wing room and the slice
## room: each waypoint, and the whole of each leg as the guard walks it (the navmesh's path
## between waypoints, then the last straight stretch onto the waypoint), stays at least
## Partition.WALKER_CLEARANCE off every footprint.
func _test_patrol_paths_clear_walls() -> void:
	var name := "patrol_paths_clear_walls"
	var paths: Array[String] = [ROOM_PATH]
	for wing: String in Content.WINGS:
		paths.append_array((load(wing) as WingData).rooms)
	for path in paths:
		var room := await _load_wing_room(name, path)
		if room == null:
			continue
		var feet := _footprints(room)
		if feet.is_empty():
			continue
		var map := room.get_world_2d().navigation_map
		for guard in room.guards:
			for i in guard.route.size():
				var from := guard.route[i]
				var to := guard.route[(i + 1) % guard.route.size()]
				_check(_clearance(to, feet) >= Partition.WALKER_CLEARANCE, name, "%s: %s's waypoint %s is %.1f off a partition" % [path.get_file(), guard.name, to, _clearance(to, feet)])
				var walk := NavigationServer2D.map_get_path(map, from, to, true)
				walk.append(to)
				var nearest := INF
				var at := from
				for k in walk.size() - 1:
					for s in 21:
						var point := walk[k].lerp(walk[k + 1], s / 20.0)
						var gap := _clearance(point, feet)
						if gap < nearest:
							nearest = gap
							at = point
				_check(nearest >= Partition.WALKER_CLEARANCE - 0.5, name, "%s: %s's leg %s -> %s passes %.1f off a partition at %s" % [path.get_file(), guard.name, from, to, nearest, at.round()])


## Loads the room scene at `path` and waits until its navigation map has synced its navmesh
## (failing `name` and returning null if it cannot).
func _load_wing_room(name: String, path: String) -> Room:
	if change_scene_to_file(path) != OK:
		_check(false, name, "cannot load %s" % path)
		return null
	for i in 3:
		await physics_frame
	var room := current_scene as Room
	var map := room.get_world_2d().navigation_map
	if not await _wait_until(func() -> bool: return NavigationServer2D.map_get_closest_point_owner(map, room.mime.position).is_valid(), 60):
		_check(false, name, "%s's navigation map never synced" % path.get_file())
		return null
	return room


## Keyboard steps keep the mime on the floor it stands on: in wing 4's hall a south nudge
## from the corridor stops at the low screens, never jumping through their gaps onto the
## unconnected floor below (the navmesh's closest point answered it there).
func _test_keyboard_stays_on_its_floor() -> void:
	var name := "keyboard_stays_on_its_floor"
	var room := await _load_wing_room(name, "res://scenes/wings/wing_04_hall.tscn")
	if room == null:
		return
	for each in room.guards:
		each.active = false
	for x: float in [100.0, 200.0, 300.0, 480.0, 560.0, 740.0, 900.0]:
		for heading: Vector2 in [Vector2.DOWN, Vector2(1, 1).normalized(), Vector2(-1, 1).normalized()]:
			room.mime.place_at(Vector2(x, 210))
			for i in 60:
				room.mime.nudge(heading, 1.0 / 60.0)
			_check(room.mime.position.y <= 241.0, name, "nudging %s from (%.0f, 210) took the mime through the screens to %s" % [heading.round(), x, room.mime.position.round()])
	room.mime.place_at(Vector2(300, 210))
	for i in 30:
		room.mime.nudge(Vector2(1, 1).normalized(), 1.0 / 60.0)
	_check(room.mime.position.x > 320.0, name, "a diagonal nudge into the screens did not slide the mime along them (at %s)" % room.mime.position.round())
	# On open floor a step's path keeps a point at each polygon edge it crosses; still
	# straight, so the step goes its full length (refusing those were invisible walls).
	room = await _load_wing_room(name, "res://scenes/wings/wing_04_terrace.tscn")
	if room == null:
		return
	for each in room.guards:
		each.active = false
	for start: Array in [[Vector2(50, 210), Vector2.RIGHT], [Vector2(90, 310), Vector2.DOWN], [Vector2(330, 430), Vector2.UP], [Vector2(390, 390), Vector2.DOWN]]:
		var at := start[0] as Vector2
		room.mime.place_at(at)
		var full := room.mime.speed() / 60.0
		room.mime.nudge(start[1] as Vector2, 1.0 / 60.0)
		_check(absf(room.mime.position.distance_to(at) - full) < 0.2, name, "a step %s from %s on open floor moved %.2f, not %.2f" % [start[1], at, room.mime.position.distance_to(at), full])


## The floor footprints of `room`'s display walls (Partition).
func _footprints(room: Room) -> Array[Rect2]:
	var feet: Array[Rect2] = []
	for each in room.get_node("Actors").get_children():
		if each is Partition:
			var wall := each as Partition
			feet.append(Rect2(wall.position.x - wall.width / 2.0, wall.position.y - wall.depth, wall.width, wall.depth))
	return feet


## How far `point` is from the nearest of `feet` (0 inside one).
func _clearance(point: Vector2, feet: Array[Rect2]) -> float:
	var nearest := INF
	for foot in feet:
		nearest = minf(nearest, point.distance_to(point.clamp(foot.position, foot.end)))
	return nearest


## Whether the flat puddle ellipse round `centre` (`r` across, Puddles.FLATTEN of it deep)
## meets `rect`: the rect's point nearest the centre lies inside it.
func _ellipse_meets(centre: Vector2, r: float, rect: Rect2) -> bool:
	var near := centre.clamp(rect.position, rect.end)
	var off := near - centre
	return (off.x / r) ** 2 + (off.y / (r * Puddles.FLATTEN)) ** 2 <= 1.0


## A rig's view follows the heading: down front, up back, right and left the side view
## (mirrored for left); a diagonal is side on from any view; a heading between SIDE_LEAVE
## and SIDE_ENTER keeps the current view (hysteresis); a zero heading keeps it too.
func _test_rig_views() -> void:
	var name := "rig_views"
	const V := CharacterRig.View
	var cases: Array[Array] = [
		[Vector2.DOWN, V.FRONT, V.FRONT], [Vector2.UP, V.FRONT, V.BACK], [Vector2.RIGHT, V.FRONT, V.RIGHT],
		[Vector2.LEFT, V.FRONT, V.LEFT], [Vector2.ZERO, V.LEFT, V.LEFT], [Vector2(1, 1), V.FRONT, V.RIGHT],
		[Vector2(-1, -1), V.BACK, V.LEFT], [Vector2(1, 0.9), V.RIGHT, V.RIGHT], [Vector2(0.6, 1), V.FRONT, V.FRONT],
		[Vector2(0.6, 1), V.RIGHT, V.RIGHT], [Vector2(0.3, 1), V.RIGHT, V.FRONT], [Vector2(1.4, -1), V.BACK, V.RIGHT],
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
	# Each shin's knee sits on the joint, whichever (and however wide) its texture.
	var side_shin := rig.get_node("Leg1/Shin") as Sprite2D
	_check(side_shin.offset.x == -side_shin.texture.get_width() / 2.0, name, "the side view's shin hangs %s off its knee" % (side_shin.offset.x + side_shin.texture.get_width() / 2.0))
	rig.face(Vector2.UP)
	_check(rig.scale.x == 1.0 and (rig.get_node("Body") as Sprite2D).texture == rig.body_back, name, "facing up does not show the back")
	_check((rig.get_node("Leg1/Shin") as Sprite2D).texture == rig.leg_lower, name, "the back view's shin is not the front-and-back shoe")
	var back_shin := rig.get_node("Leg1/Shin") as Sprite2D
	_check(back_shin.offset.x == -back_shin.texture.get_width() / 2.0, name, "the back view's shin hangs %s off its knee" % (back_shin.offset.x + back_shin.texture.get_width() / 2.0))
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


## At rest a rig lives: the mime's starts its invisible-wall gag (once, with gag_started) only
## after gag_after idle and drops it the moment it walks; busy (not idle) it never gags; the
## body breathes (still under Reduce Motion) and the eyes blink now and then (never from
## behind). A guard fidgets through its waypoint pause and stops when it walks on.
func _test_rig_rest_life() -> void:
	var name := "rig_rest_life"
	const DT := 1.0 / 60.0
	var rig := (load("res://scenes/rig_mime.tscn") as PackedScene).instantiate() as CharacterRig
	root.add_child(rig)
	var gags := [0]
	rig.gag_started.connect(func() -> void: gags[0] += 1)
	var arm := rig.get_node("Arm0") as Sprite2D
	var body := rig.get_node("Body") as Sprite2D
	var heights: Array[float] = []
	var blinks := 0
	# A full blink cycle, busy (no gag yet).
	for i in ceili(60.0 / CharacterRig.BLINK_HZ) + 1:
		rig.walk(0.0, DT, false)
		heights.append(body.scale.y)
		if rig.blinking():
			blinks += 1
	_check(heights.max() - heights.min() > CharacterRig.BREATH_DEPTH / CharacterRig.ART_SCALE, name, "the resting body did not breathe (scale %.4f..%.4f)" % [heights.min(), heights.max()])
	var expected_blinks := roundi(CharacterRig.BLINK_TIME * 60.0)
	_check(blinks >= expected_blinks - 1 and blinks <= expected_blinks + 1, name, "%d blinking frames in one %.1f s blink cycle, not about %d" % [blinks, 1.0 / CharacterRig.BLINK_HZ, expected_blinks])
	for i in roundi((rig.gag_after - 0.1) * 60.0):
		rig.walk(0.0, DT)
	_check(not rig.gagging and gags[0] == 0, name, "the mime gagged before gag_after %.1f s idle" % rig.gag_after)
	for i in 30:
		rig.walk(0.0, DT)
	_check(rig.gagging and gags[0] == 1 and arm.rotation > 0.3, name, "after gag_after idle the mime is not at the invisible wall (gagging %s, %d starts, arm %.2f)" % [rig.gagging, gags[0], arm.rotation])
	rig.walk(rig.step_length / 10.0, DT)
	_check(not rig.gagging and rig.rest == 0.0, name, "walking did not stop the gag at once")
	for i in roundi((rig.gag_after + 1.0) * 60.0):
		rig.walk(0.0, DT, false)
	_check(not rig.gagging and gags[0] == 1, name, "a busy mime gagged")
	rig.face(Vector2.UP)
	var back_blinks := 0
	for i in roundi(2.0 / CharacterRig.BLINK_HZ * 60.0):
		rig.walk(0.0, DT, false)
		if rig.blinking():
			back_blinks += 1
	_check(back_blinks == 0, name, "the back view blinked")
	var was := _game.setting("reduce_motion")
	_game.set_setting("reduce_motion", true)
	heights.clear()
	for i in 120:
		rig.walk(0.0, DT, false)
		heights.append(body.scale.y)
	_check(is_equal_approx(heights.min(), heights.max()), name, "under Reduce Motion the body still breathes")
	_game.set_setting("reduce_motion", was)
	rig.free()
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var corner := room.guard.route[1]
	var reached := await _wait_until(func() -> bool: return room.guard.position == corner, 600)
	var expected := Guard.FIDGETS[2 % Guard.FIDGETS.size()]
	_check(reached and room.guard.rig.fidget == expected, name, "at its waypoint the guard does not fidget %s (reached %s, fidget %s)" % [expected, reached, room.guard.rig.fidget])
	var walked_on := await _wait_until(func() -> bool: return room.guard.position != corner, 240)
	await physics_frame
	_check(walked_on and room.guard.rig.fidget == CharacterRig.Fidget.NONE, name, "the guard still fidgets after walking on (fidget %s)" % room.guard.rig.fidget)


## Every limb of both rigs is two parts at a joint (upper arm and forearm, thigh and shin),
## drawn from SVGs imported at ART_SCALE; walking bends (or, front and back, foreshortens)
## every knee and elbow in every view (front, back, side, mirrored left), and standing still
## straightens them all; the body sinks lowest at a footfall (contact, legs spread) and rises
## as the legs pass; the bend leaves the footfalls' timing as it was.
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
		# A joint's bend: its turn plus how far its upper and lower parts are foreshortened.
		var bend := func(lower: Sprite2D) -> float:
			var upper := lower.get_parent() as Sprite2D
			return absf(lower.rotation) + absf(1.0 - lower.scale.y * upper.scale.y * CharacterRig.ART_SCALE) + absf(1.0 - upper.scale.y * CharacterRig.ART_SCALE)
		for view: V in [V.FRONT, V.BACK, V.RIGHT, V.LEFT]:
			rig.face(([Vector2.DOWN, Vector2.UP, Vector2.RIGHT, Vector2.LEFT] as Array[Vector2])[view])
			_check(rig.view == view, name, "%s did not turn to %s" % [path, V.keys()[view]])
			var bent: Array[float] = [0.0, 0.0, 0.0, 0.0]
			for i in 120:
				rig.walk(rig.step_length / 15.0, 1.0 / 60.0)
				for j in 4:
					bent[j] = maxf(bent[j], bend.call(joints[j]))
			for j in 4:
				_check(bent[j] > 0.15, name, "%s walking %s: %s bent only %.2f" % [path, V.keys()[view], joints[j].get_parent().name + "/" + joints[j].name, bent[j]])
			# Just past a footfall (contact) the body is lower than as the legs pass.
			var heights: Array[float] = []
			for at: float in [0.0, 0.25]:
				rig.phase = at
				rig.walk(0.001, 0.0)
				heights.append(body.position.y)
			_check(heights[0] > heights[1] + rig.bob * 0.8, name, "%s walking %s: the body is not lowest at contact (%.2f there, %.2f passing)" % [path, V.keys()[view], heights[0], heights[1]])
			for i in 30:
				rig.walk(0.0, 1.0 / 60.0)
			for j in 4:
				var upper := joints[j].get_parent() as Sprite2D
				_check(joints[j].rotation == 0.0 and upper.rotation == 0.0 and bend.call(joints[j]) == 0.0, name, "%s standing %s: %s is not straight (%.2f)" % [path, V.keys()[view], upper.name, joints[j].rotation])
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
	# Every repeating rate in a script (a *_HZ constant: the gimmicks' drips, splashes, foam,
	# flow, motes and glint; the rigs' breath, blink and pat; the logo's sway).
	var rates := 0
	for folder: String in ["res://scripts", "res://scripts/gimmicks", "res://scripts/ui"]:
		for file in DirAccess.get_files_at(folder):
			if not file.ends_with(".gd"):
				continue
			var constants := (load(folder.path_join(file)) as Script).get_script_constant_map()
			for constant: String in constants:
				if constant.ends_with("_HZ"):
					rates += 1
					_check(float(constants[constant]) < LIMIT_HZ, name, "%s's %s is %s Hz" % [file, constant, constants[constant]])
	_check(rates >= 10, name, "found only %d repeating rates" % rates)
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
	# Wing 2 just opened: its door plays the unlock once (chains off, painting bright), then
	# a later visit shows it plain open.
	_check(hub.wing_doors[1].unlocking and _game.just_unlocked == -1, name, "wing 2's door did not start its unlock beat (or the flag was kept)")
	var unlocked := await _wait_until(func() -> bool: return not hub.wing_doors[1].unlocking, ceili((WingDoor.UNLOCK_DELAY + WingDoor.UNLOCK_TIME) * 60.0) + 20)
	_check(unlocked and _game.audio.played.has(&"chains_fall"), name, "wing 2's unlock beat did not finish with its sound")
	_game.goto(GameState.Flow.HIDEOUT)
	await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 120)
	_game.goto(GameState.Flow.HUB)
	await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 120)
	hub = current_scene as Hub
	_check(hub.wing_doors[1].open and not hub.wing_doors.any(func(door: WingDoor) -> bool: return door.unlocking), name, "a later visit played an unlock again")
	_game.run = null
	_game.save = Save.defaults()
	_game.just_unlocked = -1
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
	_check(replay != null and HideoutDecor.plaque_rect(0).encloses(replay.get_rect()), name, "wing 1's replay button is not on its frame's plaque")
	_check((current_scene.get_node("Decor") as HideoutDecor).stolen == ([true, false, false, false, false, false] as Array[bool]), name, "the lair's plaques do not show which originals were stolen")
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
	# The escape beat first: the beret tipped, the slip out, the door shut; then the results.
	await physics_frame
	_check(room.escaping and not results.visible and room.mime.rig.fidget == CharacterRig.Fidget.TIP, name, "the escape went straight to the results without its beat (escaping %s, fidget %s)" % [room.escaping, room.mime.rig.fidget])
	var shown := await _wait_until(func() -> bool: return results.visible, ceili(Room.escape_beat_time() * 60.0) + 10)
	_check(shown and not room.escaping and room.exit_door.shut == 1.0 and not room.exit_door.glowing and room.mime.rig.modulate.a == 0.0, name, "after the beat the results are not shown over a shut door with the mime gone (shown %s, shut %.2f, mime alpha %.2f)" % [shown, room.exit_door.shut, room.mime.rig.modulate.a])
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


## A tap (or E) during the escape beat skips it: the results show at once, the door shut (its
## glow out) and the mime gone; the stars were already recorded. Skipped mid-swing, the door's
## thud sounds once and nothing of the beat plays late.
func _test_escape_beat_skips() -> void:
	var name := "escape_beat_skips"
	for by_key: bool in [false, true]:
		var room := await _load_room()
		if room == null:
			return
		room.guard.active = false
		room.mime.carrying = true
		room._escape()
		var results := room.get_node("ResultsLayer/Results") as Results
		await physics_frame
		_check(room.escaping and not results.visible, name, "the escape beat did not start")
		if by_key:
			room._keys.interacted.emit()
		else:
			await _tap_at(Vector2(480, 400))
		_check(not room.escaping and results.visible and room.exit_door.shut == 1.0 and room.mime.rig.modulate.a == 0.0, name, "a %s did not skip the escape beat to the results" % ("key" if by_key else "tap"))
		_check(room.stars.size() == 3, name, "the skipped escape has no stars")
	# Skipped mid-swing: the door's thud sounds once, then nothing of the beat plays late.
	var swinging := await _load_room()
	if swinging == null:
		return
	swinging.guard.active = false
	swinging.mime.carrying = true
	swinging._escape()
	await _wait_until(func() -> bool: return swinging.exit_door.shut > 0.2, ceili(Room.escape_beat_time() * 60.0))
	_game.audio.played.clear()
	await _tap_at(Vector2(480, 400))
	await create_timer(Door.SHUT_TIME + 0.1).timeout
	_check(_game.audio.played.count(&"door") == 1 and swinging.exit_door.shut == 1.0 and not swinging.exit_door.glowing, name, "a skip mid-swing did not shut the door with one thud and its glow out (sounds %s)" % [_game.audio.played])


## The HUD: the par clock follows the wing timer over par (and stops with it), warms only
## past par; the objective strip ticks off painting, swapping and escaping as they happen,
## keeps them through a catch, and the HUD hides in a hideout replay.
func _test_room_hud() -> void:
	var name := "room_hud"
	_check(RoomHud.clock_fill(0.0, 80.0) == 0.0 and is_equal_approx(RoomHud.clock_fill(20.0, 80.0), 0.25) and RoomHud.clock_fill(120.0, 80.0) == 1.0, name, "the clock does not fill with elapsed over par")
	_check(RoomHud.warmth(79.0, 80.0) == 0.0 and RoomHud.warmth(80.0 + RoomHud.WARM_TIME * 0.5, 80.0) == 0.5 and RoomHud.warmth(200.0, 80.0) == 1.0, name, "the face does not warm only past par")
	_check(RoomHud.goals(false, false, false) == [false, false, false] and RoomHud.goals(true, false, false) == [true, false, false]
			and RoomHud.goals(false, true, false) == [true, true, false] and RoomHud.goals(false, true, true) == [true, true, true], name, "the goals do not follow the mime's state")
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var hud := room.hud
	var areas: Array[Rect2] = [RoomHud.clock_rect(), RoomHud.plate_rect(), RoomHud.sketch_rect()]
	var canvas := room.get_node("EaselLayer/ForgeryCanvas/Easel") as Control
	for area in areas:
		_check(hud.visible and Rect2(Vector2.ZERO, Vector2(960, 540)).encloses(area) and not area.intersects(room.get_node("PauseButton").get_rect()) and not area.intersects(canvas.get_global_rect()), name, "the HUD (%s) is off the world, over the pause button or the canvas board" % area)
	# No wing room hangs a painting under it.
	for wing_path in Content.WINGS:
		for room_path: String in (load(wing_path) as WingData).rooms:
			var scene := (load(room_path) as PackedScene).instantiate()
			var hung: Dictionary[String, Rect2] = {}
			for frame in scene.get_node("Frames").get_children():
				hung["frame " + frame.name] = Rect2(frame.position - TiltFrame.SIZE / 2.0, TiltFrame.SIZE)
			for portrait in scene.get_node("Portraits").get_children():
				hung["portrait " + portrait.name] = Rect2(portrait.position - HidingPortrait.SIZE / 2.0, HidingPortrait.SIZE)
			var picture := scene.get_node_or_null("Masterpiece") as FramedPainting
			if picture != null:
				hung["the masterpiece"] = Rect2(picture.position - picture.size / 2.0, picture.size)
			for what in hung:
				_check(not areas.any(func(area: Rect2) -> bool: return area.intersects(hung[what])), name, "%s: %s is under the HUD" % [room_path, what])
			scene.free()
	await physics_frame
	_check(hud.done == [false, false, false], name, "goals are done before anything was: %s" % [hud.done])
	var before := room.elapsed
	for i in 30:
		await physics_frame
	_check(room.elapsed > before and is_equal_approx(RoomHud.clock_fill(room.elapsed, room.par_time), room.elapsed / room.par_time), name, "the clock does not follow the running timer")
	room._on_painted(Forgery.ASSIST_QUALITY)
	await process_frame
	await process_frame
	_check(hud.done == [true, false, false], name, "painting did not tick the brush: %s" % [hud.done])
	room._swap()
	await process_frame
	await process_frame
	_check(hud.done == [true, true, false], name, "swapping did not tick the swap: %s" % [hud.done])
	room._on_caught()
	await create_timer(Room.TOSS_SHAKE + Room.TOSS_FLIGHT + 0.1).timeout
	_check(hud.done == [true, true, false], name, "a catch lost the goals: %s" % [hud.done])
	room._escape()
	var stopped := room.elapsed
	await process_frame
	await process_frame
	await physics_frame
	_check(hud.done == [true, true, true] and room.elapsed == stopped, name, "escaping did not tick the exit and stop the clock: %s" % [hud.done])
	var replay := await _load_room()
	if replay == null:
		return
	# Stopped first (leaving), so the replay's empty stay does not end it and leave the room.
	replay.leaving = true
	replay.run.replaying = true
	await process_frame
	await process_frame
	_check(not replay.hud.visible, name, "the HUD shows in a hideout replay")
	replay.run.replaying = false


## Every wing room's back wall is dressed in its wing's style (RoomDecor), its lamps hung only
## in clear wall (off every painting, the gimmick's window or pipe and the HUD), each lighting
## the wall and the floor (two pools); the finale never paints wing 4's starry sky; an
## unknown style is reported.
func _test_room_decor() -> void:
	var name := "room_decor"
	var paintings: Array[Rect2] = [Rect2(300, 40, 70, 130), Rect2(600, 50, 60, 50)]
	for x in RoomDecor.lamp_xs(paintings, 88.0, RoomDecor.LAMP_BOX):
		var lamp := Rect2(Vector2(x, 88.0) + RoomDecor.LAMP_BOX.position, RoomDecor.LAMP_BOX.size)
		_check(x >= RoomDecor.HUD_CLEAR and not paintings.any(func(each: Rect2) -> bool: return each.grow(RoomDecor.LAMP_CLEARANCE - 1.0).intersects(lamp)), name, "a lamp at x %.0f hangs over a painting or the HUD" % x)
	_check(RoomDecor.lamp_xs([Rect2(0, 96, 960, 32)] as Array[Rect2], 88.0, RoomDecor.LAMP_BOX).is_empty(), name, "a lamp hangs across a wall-wide pipe")
	for wing_path in Content.WINGS:
		var wing := load(wing_path) as WingData
		for index in wing.rooms.size():
			# The room as one of its wing's (its style is the wing's painting), come in at its Entrance.
			_game.run = WingRun.new(wing)
			_game.run.room = index
			change_scene_to_file(wing.rooms[index])
			var room := await _wait_for_room(wing.rooms[index], 120)
			if room == null:
				_check(false, name, "%s did not load" % wing.rooms[index])
				continue
			var decor := room.get_node_or_null("Decor") as RoomDecor
			_check(decor != null and decor.style == StringName(wing.painting) and decor.z_index == Room.DECOR_Z, name, "%s is not dressed in %s" % [wing.rooms[index], wing.painting])
			if decor == null:
				continue
			var lights := room.get_node("Lights") as RoomLights
			_check(lights.pools.size() == decor.lamps.size() * 2, name, "%s: its %d lamps do not each light the wall and floor" % [wing.rooms[index], decor.lamps.size()])
			for lamp in decor.lamps:
				var box := Rect2(lamp + RoomDecor.LAMP_BOX.position, RoomDecor.LAMP_BOX.size)
				var blocked := decor.avoid.any(func(each: Rect2) -> bool: return each.intersects(box))
				_check(not blocked and lamp.x >= RoomDecor.HUD_CLEAR, name, "%s: the lamp at %s hangs over a painting, the gimmick's wall or the HUD" % [wing.rooms[index], lamp])
			if wing.painting == "mona_lisa" and room.gimmick != null:
				var parts: Array[Gimmick] = []
				if room.gimmick is GimmickMix:
					parts = (room.gimmick as GimmickMix).parts()
				else:
					parts.append(room.gimmick)
				for part in parts:
					_check(not part is Searchlights or not (part as Searchlights).sky, name, "%s paints wing 4's starry sky" % wing.rooms[index])
	_game.run = null
	var stray := RoomDecor.new()
	stray.style = &"no_such_style"
	_game.quiet_errors = true
	var errors_before := _game.errors.size()
	root.add_child(stray)
	_check(_game.errors.size() == errors_before + 1 and stray.lamps.is_empty(), name, "an unknown style is not reported")
	_game.quiet_errors = false
	stray.queue_free()
	await process_frame


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
	_check(carried.visible and carried.modulate.is_equal_approx(Mime.FAKE_TINT * room.mime.carried_light), name, "the carried fake does not show, tinted")
	await _tap_at(room.painting_rect().get_center())
	_check(await _wait_until(func() -> bool: return room.mime.carrying, 900), name, "the fake never swapped for the original")
	_check(not room.mime.has_fake and carried.modulate.is_equal_approx(room.mime.carried_light), name, "after the swap the mime still has the fake, or the original shows tinted")
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


## An escape beats a best only against a record: a first escape beats none; then more stars
## beat the stars and a faster time the time, each on its own.
func _test_new_best_detected() -> void:
	var name := "new_best_detected"
	var data := Save.defaults()
	var two: Array[bool] = [true, true, false]
	var three: Array[bool] = [true, true, true]
	_check(Save.improvement(data, "wing_01", three, 30.0) == {"stars": false, "time": false}, name, "a first escape beat a record")
	Save.record(data, "wing_01", two, 40.0)
	_check(Save.improvement(data, "wing_01", three, 50.0) == {"stars": true, "time": false}, name, "more stars, slower, did not beat only the stars")
	_check(Save.improvement(data, "wing_01", two, 30.0) == {"stars": false, "time": true}, name, "the same stars, faster, did not beat only the time")
	_check(Save.improvement(data, "wing_01", two, 40.0) == {"stars": false, "time": false}, name, "a tie beat a best")


## A three-star result bursts into confetti while the mime bows; a rosette pops in for each
## best beaten (by the stars, on the clock); fewer stars and no best show neither.
func _test_results_celebrate() -> void:
	var name := "results_celebrate"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var results := room.get_node("ResultsLayer/Results") as Results
	var wait := (Results.STAR_GAP + Results.POP_TIME) * 3.0 + Results.STAR_GAP * 3.0 + 0.2
	results.present([true, true, false] as Array[bool])
	await create_timer(wait).timeout
	_check(not results.confetti.playing() and results.mime.fidget == CharacterRig.Fidget.NONE and not results.stars_best.visible and not results.time_best.visible, name, "two stars and no best still celebrated")
	results.present([true, true, true] as Array[bool], {"stars": true, "time": false})
	await create_timer(wait).timeout
	_check(results.confetti.playing() and results.mime.fidget == CharacterRig.Fidget.BOW and _game.audio.played.has(&"confetti"), name, "three stars did not burst into confetti with a bow")
	_check(results.stars_best.visible and results.stars_best.scale.is_equal_approx(Vector2.ONE) and not results.time_best.visible, name, "a new best star count did not pin its rosette by the stars alone")
	results.present([true, true, true] as Array[bool], {"stars": false, "time": true})
	await create_timer(wait).timeout
	_check(results.time_best.visible and not results.stars_best.visible, name, "a new best time did not pin its rosette on the clock alone")
	await create_timer(Confetti.LIFE).timeout
	_check(not results.confetti.playing(), name, "the confetti outlived its %.1f s" % Confetti.LIFE)


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


## The cone warms from calm toward the alert red with suspicion, step by small step (no
## flash), and is red while alert; a guard's drawn cone follows its suspicion.
func _test_cone_warms_with_suspicion() -> void:
	var name := "cone_warms_with_suspicion"
	_check(Guard.cone_color(0.0, false).is_equal_approx(Guard.CONE_COLOR), name, "a calm cone is not CONE_COLOR")
	_check(Guard.cone_color(1.0, false).is_equal_approx(Guard.CONE_ALERT_COLOR) and Guard.cone_color(0.0, true) == Guard.CONE_ALERT_COLOR, name, "a full or alert cone is not CONE_ALERT_COLOR")
	var before := Guard.cone_color(0.0, false)
	for i in range(1, 21):
		var color := Guard.cone_color(i / 20.0, false)
		_check(color.g < before.g and absf(color.get_luminance() - before.get_luminance()) < 0.05, name, "the cone at suspicion %.2f did not warm a small step (%s after %s)" % [i / 20.0, color, before])
		before = color
	var room := await _load_room()
	room.guard.suspicion = 0.5
	await physics_frame
	await physics_frame
	var cone := room.guard.get_node("Cone") as Polygon2D
	_check(cone.color.is_equal_approx(Guard.cone_color(room.guard.suspicion, false)), name, "the drawn cone %s does not follow suspicion %.2f" % [cone.color, room.guard.suspicion])


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


## Every wing loop has a tension stem (Audio.stem_for, tools/music.py STEMS) that loads as a
## looping MP3 exactly as long as its loop (so they stay locked); the chase sting loads as a
## one-shot; the caper and results have no stem. play_music starts a wing's stem on the
## player paired with its loop.
func _test_tension_stems() -> void:
	var name := "tension_stems"
	var stems := 0
	for track in Audio.MUSIC_TRACKS:
		var stem := Audio.stem_for(track)
		_check((stem != "") == track.begins_with("wing_"), name, "%s has stem '%s'" % [track, stem])
		if stem == "":
			continue
		stems += 1
		var loop := load(Audio.MUSIC_PATH % track) as AudioStreamMP3
		var layer := load(Audio.MUSIC_PATH % stem) as AudioStreamMP3
		_check(layer != null and layer.loop and is_equal_approx(layer.get_length(), loop.get_length()), name, "stem %s is missing, not looping or not as long as %s" % [stem, track])
	_check(stems == 6, name, "%d wing loops have stems, expected 6" % stems)
	var sting := load(Audio.MUSIC_PATH % Audio.STING) as AudioStreamMP3
	_check(sting != null and not sting.loop and sting.get_length() < 4.0, name, "the chase sting is missing, looping or long")
	var audio := _game.audio
	var was := audio.music
	audio.play_music("wing_02")
	_check(audio.current_stem().stream == load(Audio.MUSIC_PATH % "wing_02_tension") and audio.current_stem().bus == Audio.MUSIC_BUS, name, "wing_02 did not start its stem on the Music bus")
	audio.play_music("caper")
	_check(audio.current_stem().stream == null, name, "the caper started a stem")
	audio.play_music(was)


## set_tension eases the stem: up over TENSION_RISE, down over TENSION_FALL (half way after
## half the time), clamped to 0..1; the stem plays at the tension times its loop's volume, so
## a crossfade to a loop without a stem fades it out and calms the target.
func _test_tension_eases() -> void:
	var name := "tension_eases"
	var audio := _game.audio
	var was := audio.music
	audio.play_music("wing_01")
	audio.tension = 0.0
	audio.set_tension(2.0)
	_check(audio.tension_target == 1.0, name, "set_tension does not clamp to 1")
	audio._process(Audio.TENSION_RISE / 2.0)
	_check(is_equal_approx(audio.tension, 0.5), name, "half the rise time eased to %.2f, not 0.5" % audio.tension)
	audio._process(Audio.TENSION_RISE)
	_check(audio.tension == 1.0, name, "the stem did not reach full tension")
	var music := audio.get_node("Music" + audio.current_stem().name.trim_prefix("Stem")) as AudioStreamPlayer
	_check(is_equal_approx(audio.current_stem().volume_linear, music.volume_linear), name, "the stem plays at %.2f, its loop at %.2f" % [audio.current_stem().volume_linear, music.volume_linear])
	audio.set_tension(0.0)
	audio._process(Audio.TENSION_FALL / 2.0)
	_check(is_equal_approx(audio.tension, 0.5), name, "half the fall time eased to %.2f, not 0.5" % audio.tension)
	audio.set_tension(1.0)
	audio.play_music("caper")
	_check(audio.tension_target == 0.0, name, "a new loop did not calm the tension")
	audio.tension = 0.0
	audio.play_music(was)


## A chase's start plays the sting once; it does not repeat while the chase goes on, and a
## new chase plays it again.
func _test_chase_sting_once() -> void:
	var name := "chase_sting_once"
	var audio := _game.audio
	audio.set_chase(false)
	var before := audio.stings
	audio.set_chase(true)
	audio.set_chase(true)
	audio.set_chase(true)
	_check(audio.stings == before + 1, name, "one chase played %d stings" % (audio.stings - before))
	audio.set_chase(false)
	audio.set_chase(true)
	_check(audio.stings == before + 2, name, "a second chase did not play the sting")
	audio.set_chase(false)


## The room's danger is the peak suspicion of its active guards, full while one chases or
## searches, 0 while tossing or once finished; each tick it sets the music's tension and a
## chase plays the sting. Nothing in the room changes (audio only).
func _test_room_drives_tension() -> void:
	var name := "room_drives_tension"
	var room: Room = await _load_room()
	var guard := room.guard
	guard.suspicion = 0.3
	_check(is_equal_approx(room.peak_suspicion(), 0.3) and is_equal_approx(room.danger(), 0.3), name, "danger %.2f does not follow the peak suspicion 0.3" % room.danger())
	guard.active = false
	_check(room.peak_suspicion() == 0.0, name, "an inactive guard counts")
	guard.active = true
	guard.intent = GuardBrain.Intent.SEARCH
	_check(room.danger() == 1.0 and not room.chasing(), name, "a search is not full danger, or counts as a chase")
	guard.intent = GuardBrain.Intent.CHASE
	_check(room.danger() == 1.0 and room.chasing(), name, "a chase is not full danger")
	room.tossing = true
	_check(room.danger() == 0.0 and not room.chasing(), name, "tossing is not calm")
	room.tossing = false
	var before := _game.audio.stings
	_game.audio.set_chase(false)
	await physics_frame
	_check(_game.audio.tension_target == 1.0 and _game.audio.stings == before + 1, name, "the room's chase did not set full tension and play the sting")
	room.finished = true
	await physics_frame
	_check(_game.audio.tension_target == 0.0, name, "a finished room did not calm the music")
	room.finished = false
	_game.audio.set_chase(false)


## A double tap on the floor (within Room.DOUBLE_TAP and DOUBLE_TAP_REACH) dashes there at
## Mime.DASH_SPEED with the rig running, until it arrives; a first tap walks at once, and taps
## apart in time or space only walk.
func _test_dash_double_tap() -> void:
	var name := "dash_double_tap"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room.mime.place_at(Vector2(200, 450))
	await _tap_at(Vector2(600, 480))
	_check(room.mime.walking and not room.mime.dashing and room.mime.speed() == Mime.SPEED, name, "a first tap does not walk at once at SPEED")
	await _tap_at(Vector2(615, 480))
	_check(room.mime.dashing and room.mime.speed() == Mime.DASH_SPEED, name, "a second tap 15 away at once does not dash (speed %.0f)" % room.mime.speed())
	await physics_frame
	await physics_frame
	_check(room.mime.rig.running, name, "the dashing mime's rig does not run")
	var from := room.mime.position
	for i in 30:
		await physics_frame
	var moved := room.mime.position.distance_to(from)
	_check(absf(moved - Mime.DASH_SPEED * 0.5) < 8.0, name, "the dash covered %.0f in 0.5 s, not %.0f" % [moved, Mime.DASH_SPEED * 0.5])
	await _wait_until(func() -> bool: return not room.mime.walking, 240)
	await physics_frame
	_check(not room.mime.dashing and not room.mime.rig.running, name, "the dash goes on after arriving")
	await _tap_at(Vector2(300, 480))
	for i in ceili(Room.DOUBLE_TAP * 60.0) + 2:
		await physics_frame
	await _tap_at(Vector2(305, 480))
	_check(room.mime.walking and not room.mime.dashing, name, "a second tap after DOUBLE_TAP dashes")
	await _tap_at(Vector2(305 + Room.DOUBLE_TAP_REACH + 20.0, 480))
	_check(room.mime.walking and not room.mime.dashing, name, "a second tap beyond DOUBLE_TAP_REACH dashes")
	_check(Mime.DASH_SPEED > Mime.SPEED * 1.4 and Mime.DASH_SPEED < Mime.SPEED * 1.8, name, "DASH_SPEED %.0f is not about 1.6 times SPEED" % Mime.DASH_SPEED)


## Shift held with the arrows runs the mime at DASH_SPEED; let go, it walks again.
func _test_dash_shift() -> void:
	var name := "dash_shift"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room.mime.place_at(Vector2(200, 480))
	await _key(KEY_SHIFT, true)
	var from := room.mime.position
	Input.action_press("ui_right")
	for i in 30:
		await physics_frame
	_check(room.mime.dashing and room.mime.rig.running, name, "Shift with an arrow does not run")
	Input.action_release("ui_right")
	var moved := room.mime.position - from
	_check(absf(moved.x - Mime.DASH_SPEED * 0.5) < 6.0, name, "Shift and right for 0.5 s moved the mime %s, not %.0f right" % [moved, Mime.DASH_SPEED * 0.5])
	await physics_frame
	await physics_frame
	_check(not room.mime.dashing, name, "the run goes on with no key held")
	await _key(KEY_SHIFT, false)
	from = room.mime.position
	Input.action_press("ui_right")
	for i in 30:
		await physics_frame
	Input.action_release("ui_right")
	_check(absf(room.mime.position.x - from.x - Mime.SPEED * 0.5) < 6.0, name, "without Shift the arrow does not walk at SPEED")


## The DustPuff children of the room's Actors now.
func _dust_puffs(room: Room) -> int:
	return room.get_node("Actors").get_children().filter(func(child: Node) -> bool: return child is DustPuff).size()


## Every dashed footfall is a noise (the dash sound and a dust puff) the guard within
## Mime.DASH_NOISE of hearing range hears; the same walk tiptoed is heard by nobody, and
## Reduce Motion kicks up no dust.
func _test_dash_footfalls_heard() -> void:
	var name := "dash_footfalls_heard"
	var room := await _load_room()
	if room == null:
		return
	var guard := room.guard
	guard.target = null
	_game.audio.played.clear()
	for dash: bool in [false, true]:
		guard.reset()
		guard.position = Vector2(720, 480)
		room.mime.place_at(Vector2(420, 480))
		await _tap_at(Vector2(560, 480))
		if dash:
			await _tap_at(Vector2(560, 480))
		var puffs := 0
		for i in 120:
			guard.position = Vector2(720, 480)
			puffs = maxi(puffs, _dust_puffs(room))
			await physics_frame
		var kind := "dash" if dash else "tiptoe"
		_check(guard.senses.noise_heard == dash, name, "a %s near the guard was heard: %s" % [kind, guard.senses.noise_heard])
		_check((puffs > 0) == dash, name, "a %s kicked up %d dust puff(s)" % [kind, puffs])
		# The double tap's first tap sets off walking: one tiptoe before the dash.
		var sounds := _game.audio.played
		_check((sounds.count(&"dash") >= 2 and sounds.count(&"tiptoe") <= 1) if dash else (sounds.count(&"dash") == 0 and sounds.count(&"tiptoe") >= 2), name, "a %s played %s" % [kind, sounds])
		_game.audio.played.clear()
	_check(Mime.DASH_NOISE > 0.0 and Mime.DASH_NOISE < 1.0, name, "DASH_NOISE %.2f is not a share of hearing range" % Mime.DASH_NOISE)
	_game.set_setting("reduce_motion", true)
	room.mime.place_at(Vector2(420, 480))
	await _tap_at(Vector2(560, 480))
	await _tap_at(Vector2(560, 480))
	var stilled := 0
	for i in 60:
		stilled += _dust_puffs(room)
		await physics_frame
	_game.set_setting("reduce_motion", false)
	_check(stilled == 0, name, "a dash under Reduce Motion kicked up dust")


## Between CloseCall.CLOSE_CALL and full suspicion (no chase) a heartbeat beats, faster as it
## rises but under 2 Hz, and the edges darken with it (under the HUD); a chase or a calm
## stops both, and Reduce Motion keeps the edges clear.
func _test_close_call_heartbeat() -> void:
	var name := "close_call_heartbeat"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var close := room.close_call
	_check(close != null and close.z_index < room.hud.z_index and close.z_index < (room.get_node("PauseButton") as CanvasItem).z_index, name, "the close call is missing or not under the HUD")
	close.set_physics_process(false)
	_check(CloseCall.beat_hz(CloseCall.CLOSE_CALL) < CloseCall.beat_hz(0.7) and CloseCall.beat_hz(0.7) < CloseCall.beat_hz(0.999) and CloseCall.beat_hz(0.999) < 2.0, name, "the heartbeat does not quicken under 2 Hz")
	_check(CloseCall.strength(0.2) == 0.0 and CloseCall.strength(0.5) < CloseCall.strength(0.9) and CloseCall.strength(1.0) == 0.0, name, "the edge strength does not follow suspicion between CLOSE_CALL and full")
	_game.audio.played.clear()
	for i in 30:
		close.step(0.2, false, 1.0 / 60.0)
	_check(not &"heartbeat" in _game.audio.played and close.edge_alpha() == 0.0, name, "suspicion under CLOSE_CALL beats or darkens")
	var beats := 0
	for i in 120:
		var before := _game.audio.played.count(&"heartbeat")
		close.step(0.9, false, 1.0 / 60.0)
		beats += _game.audio.played.count(&"heartbeat") - before
	_check(beats >= 2 and beats <= 4, name, "2 s at suspicion 0.9 beat %d times (expected 2 to 4, under 2 Hz)" % beats)
	_check(is_equal_approx(close.shown, CloseCall.strength(0.9)) and close.edge_alpha() > 0.0, name, "the edges did not darken to the suspicion (shown %.2f)" % close.shown)
	var alphas: Array[float] = []
	for i in 60:
		close.step(0.9, false, 1.0 / 60.0)
		alphas.append(close.edge_alpha())
	_check(alphas.max() - alphas.min() <= CloseCall.EDGE_ALPHA * CloseCall.BEAT_SWELL + 0.01, name, "the beat swings the edges by %.2f (a flash, not a swell)" % (alphas.max() - alphas.min()))
	_game.set_setting("reduce_motion", true)
	_check(close.edge_alpha() == 0.0, name, "Reduce Motion leaves the edges dark")
	_game.set_setting("reduce_motion", false)
	_game.audio.played.clear()
	for i in 60:
		close.step(1.0, true, 1.0 / 60.0)
	_check(not &"heartbeat" in _game.audio.played and close.shown == 0.0, name, "a chase beats or keeps the edges dark (shown %.2f)" % close.shown)


## Suspicion that peaks at NEAR_MISS or more and drains to nothing unseen plays the relief
## sting and the mime wipes its brow; a lower peak, or a guard spotting it meanwhile, does not.
func _test_near_miss() -> void:
	var name := "near_miss"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var close := room.close_call
	close.set_physics_process(false)
	_game.audio.played.clear()
	close.step(CloseCall.NEAR_MISS + 0.05, false, 0.1)
	close.step(0.2, false, 0.1)
	_check(close.near_misses == 0, name, "a near miss before the suspicion drained")
	close.step(0.0, false, 0.1)
	_check(close.near_misses == 1 and &"relief" in _game.audio.played and room.mime.rig.fidget == CharacterRig.Fidget.BROW, name, "a drained near miss played no relief or brow wipe (fidget %s)" % room.mime.rig.fidget)
	for i in ceili(CloseCall.BROW_TIME * 60.0) + 2:
		await physics_frame
	_check(room.mime.rig.fidget == CharacterRig.Fidget.NONE, name, "the brow wipe does not end")
	close.step(CloseCall.NEAR_MISS - 0.05, false, 0.1)
	close.step(0.0, false, 0.1)
	_check(close.near_misses == 1, name, "a peak under NEAR_MISS counted as a near miss")
	close.step(CloseCall.NEAR_MISS + 0.05, false, 0.1)
	room.guard.spotted.emit()
	close.step(0.0, false, 0.1)
	_check(close.near_misses == 1 and not close.spoiled, name, "a close call the guard spotted counted as a near miss")
	close.step(CloseCall.NEAR_MISS + 0.05, false, 0.1)
	close.step(0.0, false, 0.1)
	_check(close.near_misses == 2, name, "the close call after a spotted one is no near miss")


## No recorded bot route (main, sketch, or a trick ablation skipping its tap at any wait) can
## make a double tap: two taps in one room visit within Room.DOUBLE_TAP_REACH, the second
## within Room.DOUBLE_TAP (a wait under it). A dash would change a recorded run.
func _test_routes_never_double_tap() -> void:
	var name := "routes_never_double_tap"
	var paths: Array[String] = []
	paths.assign(Content.WINGS)
	paths.append("res://scenes/test/slice_wing.tres")
	var pairs := 0
	for path in paths:
		var wing := load(path) as WingData
		# Each room's doors, as [tap rect, room it leads to].
		var doors: Array[Array] = []
		for room_path in wing.rooms:
			var room := (load(room_path) as PackedScene).instantiate()
			var room_doors: Array = []
			for child in room.get_node("Doors").get_children():
				if child is Door:
					room_doors.append([(child as Door).rect(), (child as Door).to_room])
			doors.append(room_doors)
			room.free()
		var runs: Array[Array] = [[wing.bot_route, wing.bot_waits, -1], [wing.sketch_route, wing.sketch_waits, -1]]
		for trick in wing.bot_tricks:
			runs.append([wing.bot_route, wing.bot_waits, trick])
		for run in runs:
			var route: PackedVector2Array = run[0]
			var waits: PackedFloat32Array = run[1]
			var skip: int = run[2]
			var at_room := 0
			var previous := -1
			for i in route.size():
				if i == skip:
					continue
				# Ablating a trick tries every wait of the leg after it, 0 included.
				var any_wait := skip >= 0 and i == skip + 1
				if previous >= 0:
					pairs += 1
					var close := route[i].distance_to(route[previous]) <= Room.DOUBLE_TAP_REACH
					_check(not close or (waits[i] >= Room.DOUBLE_TAP and not any_wait), name, "%s: taps %d and %d (%s, %s) could double tap%s" % [path, previous, i, route[previous], route[i], " (ablating tap %d)" % skip if skip >= 0 else ""])
				previous = i
				for door: Array in doors[at_room]:
					if (door[0] as Rect2).has_point(route[i]):
						# Through a door: a new room visit, a fresh tap memory.
						previous = -1
						at_room = door[1]
						break
				if at_room < 0:
					break
	_check(pairs > 100, name, "only %d tap pairs checked" % pairs)


## A save with `count` wings finished (Content.WINGS order).
func _save_finished(count: int) -> Dictionary:
	var save := Save.defaults()
	var ids := Content.wing_ids()
	for i in count:
		Save.record(save, ids[i], [true, true, false] as Array[bool], 300.0)
	return save


func _reset_finale_state() -> void:
	_game.run = null
	_game.save = Save.defaults()
	_game.just_unlocked = -1
	_game.ending_due = false
	_game.finale_return = GameState.Flow.HUB
	DirAccess.remove_absolute(_game.save_path)


## The finale is due only on the escape that finishes the last unfinished wing: not on an
## escape before it, not on a later escape once every wing is finished.
func _test_finale_due_once() -> void:
	var name := "finale_due_once"
	var stars: Array[bool] = [true, true, true]
	_reset_finale_state()
	_game.save = _save_finished(4)
	_game.run = WingRun.new(load(Content.WINGS[4]) as WingData)
	_game.record_escape(stars, 100.0, Challenges.none())
	_check(not _game.ending_due and not _game.all_wings_finished(), name, "the finale is due with wing 6 unfinished")
	_game.run = WingRun.new(load(Content.WINGS[5]) as WingData)
	_game.record_escape(stars, 100.0, Challenges.none())
	_check(_game.ending_due and _game.all_wings_finished(), name, "the escape that finished every wing did not make the finale due")
	_game.ending_due = false
	_game.record_escape(stars, 90.0, Challenges.none())
	_check(not _game.ending_due, name, "a later escape with every wing finished made the finale due again")
	# Out of order: the last wing to finish need not be wing 6.
	_game.save = _save_finished(6)
	(_game.save["wings"] as Dictionary).erase("wing_02")
	_game.run = WingRun.new(load(Content.WINGS[1]) as WingData)
	_game.record_escape(stars, 100.0, Challenges.none())
	_check(_game.ending_due, name, "finishing wing 2 last did not make the finale due")
	_reset_finale_state()


## The results' home plays the due finale once (then the hub), or goes to the hub when none
## is due; the finale skips on a tap, E, Space and ui_accept (its focused skip button), and
## unskipped it plays to its end, each time going to finale_return.
func _test_finale_skips_and_returns() -> void:
	var name := "finale_skips_and_returns"
	_reset_finale_state()
	_game.ending_due = true
	_game.leave_results()
	var arrived := await _wait_until(func() -> bool: return current_scene is Finale and not _game.is_transitioning(), 300)
	_check(arrived and _game.state == GameState.Flow.FINALE and not _game.ending_due and _game.finale_return == GameState.Flow.HUB, name, "the results' home with the finale due did not play it once, back to the hub")
	if not arrived:
		_reset_finale_state()
		return
	var skip := current_scene.get_node("SkipButton") as Button
	_check(skip.has_focus(true) and skip.size.x >= 44.0 and skip.size.y >= 44.0 and not skip.accessibility_name.is_empty(), name, "the skip button is not a focused, named 44x44 button")
	_check(_game.music_for(GameState.Flow.FINALE) == "results", name, "the finale does not play the results' fanfare")
	await _tap_at(Vector2(480, 400))
	var back := await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), 300)
	_check(back, name, "a tap did not skip the finale to the hub")
	_game.leave_results()
	await _wait_until(func() -> bool: return not _game.is_transitioning() and current_scene is Hub, 300)
	_check(_game.state == GameState.Flow.HUB, name, "the results' home with no finale due did not go to the hub")
	for key: Key in [KEY_E, KEY_SPACE, KEY_ENTER]:
		_game.play_finale(GameState.Flow.HIDEOUT)
		await _wait_until(func() -> bool: return current_scene is Finale and not _game.is_transitioning(), 300)
		await _press_key(key)
		back = await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 300)
		_check(back, name, "%s did not skip the finale to the hideout" % OS.get_keycode_string(key))
	_game.play_finale(GameState.Flow.HUB)
	await _wait_until(func() -> bool: return current_scene is Finale and not _game.is_transitioning(), 300)
	var finale := current_scene as Finale
	var frames := ceili(Finale.LENGTH * 60.0)
	await _wait_until(func() -> bool: return finale.beat == 2, frames)
	_check(finale.beat == 2 and finale.thumbs.size() == 6 and finale.fakes.size() == 6 and finale.originals.size() == 6, name, "the finale did not reach its credits with six paintings in each beat")
	back = await _wait_until(func() -> bool: return current_scene is Hub and not _game.is_transitioning(), frames)
	_check(back, name, "the finale did not end in the hub on its own")
	_reset_finale_state()


## The hideout offers the finale again (a named 44x44 button) only once every wing is
## finished; it plays the finale and comes back to the hideout.
func _test_hideout_replays_finale() -> void:
	var name := "hideout_replays_finale"
	_reset_finale_state()
	_game.save = _save_finished(5)
	change_scene_to_file("res://scenes/hideout.tscn")
	await process_frame
	await process_frame
	_check(current_scene.get_node_or_null("FinaleButton") == null, name, "the hideout offers the finale with a wing unfinished")
	_game.save = _save_finished(6)
	change_scene_to_file("res://scenes/hideout.tscn")
	await process_frame
	await process_frame
	var button := current_scene.get_node_or_null("FinaleButton") as Button
	_check(button != null and button.size.x >= 44.0 and button.size.y >= 44.0 and not button.accessibility_name.is_empty() and button.focus_mode == Control.FOCUS_ALL, name, "with every wing finished the hideout has no focusable, named 44x44 finale button")
	if button == null:
		_reset_finale_state()
		return
	await _tap_control(button)
	var arrived := await _wait_until(func() -> bool: return current_scene is Finale and not _game.is_transitioning(), 300)
	_check(arrived and _game.finale_return == GameState.Flow.HIDEOUT, name, "the hideout's button did not play the finale back to the hideout")
	await _tap_at(Vector2(480, 400))
	var back := await _wait_until(func() -> bool: return current_scene is Hideout and not _game.is_transitioning(), 300)
	_check(back, name, "the finale from the hideout did not return there")
	_reset_finale_state()


## Each challenge is judged on its own: no power used, a PERFECT fake (Good is not), never
## caught (being seen is allowed), and under the speed target, which is half of par unless
## the wing sets one; a negative target is refused.
func _test_challenges_judged() -> void:
	var name := "challenges_judged"
	_check(Challenges.earned(0, 0.9, 0, 20.0, 30.0) == [true, true, true, true], name, "a clean, perfect, quick run did not complete all four")
	_check(Challenges.earned(1, 0.9, 0, 20.0, 30.0) == [false, true, true, true], name, "a power used still completed NO_POWERS")
	_check(Challenges.earned(0, Forgery.ASSIST_QUALITY, 0, 20.0, 30.0) == [true, false, true, true], name, "a Good fake completed PERFECT")
	_check(Challenges.earned(0, Forgery.PERFECT_QUALITY, 0, 20.0, 30.0)[Challenges.Challenge.PERFECT], name, "a fake at the PERFECT threshold did not complete PERFECT")
	_check(Challenges.earned(0, 0.9, 2, 20.0, 30.0) == [true, true, false, true], name, "a caught run completed NEVER_CAUGHT")
	_check(Challenges.earned(0, 0.9, 0, 30.0, 30.0)[Challenges.Challenge.SPEED] and not Challenges.earned(0, 0.9, 0, 30.5, 30.0)[Challenges.Challenge.SPEED], name, "SPEED is not 'within the target'")
	var wing := _test_wing()
	wing.par_time = 90.0
	_check(is_equal_approx(Challenges.speed_target(wing), 45.0), name, "the default speed target is %.1f, not half of par 90" % Challenges.speed_target(wing))
	wing.speed_target = 60.0
	_check(is_equal_approx(Challenges.speed_target(wing), 60.0) and Content.validate(wing, "w.tres").is_empty(), name, "a wing's own speed target is not used or is refused")
	wing.speed_target = -1.0
	var problems := Content.validate(wing, "w.tres")
	_check(problems.size() == 1 and "speed_target" in problems[0], name, "a negative speed target is not refused with one problem: %s" % [problems])
	_check(Challenges.ICONS.size() == Challenges.Challenge.size() and Challenges.ICONS.all(func(each: Texture2D) -> bool: return each != null), name, "not every challenge has its badge")


## Save version 3 keeps each wing's challenges ever completed (a completed one stays so),
## reports those first completed, reads back as written and refuses a bad entry; version 1
## and 2 saves upgrade with every best, sketch and setting kept and no challenge yet.
func _test_save_challenges() -> void:
	var name := "save_challenges"
	var problems: Array[String] = []
	var data := Save.defaults()
	_check(Save.VERSION == 3 and Save.READS == ([1, 2, 3] as Array[int]), name, "the save is version %d reading %s" % [Save.VERSION, Save.READS])
	_check(Save.challenges_of(data, "wing_01") == Challenges.none(), name, "a wing never escaped from has challenges")
	_check(Save.record_challenges(data, "wing_01", [true, false, true, false] as Array[bool]) == [true, false, true, false], name, "first completions are not all reported")
	_check(Save.record_challenges(data, "wing_01", [false, true, true, false] as Array[bool]) == [false, true, false, false], name, "a challenge completed before is reported again")
	_check(Save.challenges_of(data, "wing_01") == [true, true, true, false], name, "a completed challenge did not stay completed: %s" % [Save.challenges_of(data, "wing_01")])
	_check(Save.record_challenges(data, "wing_01", Challenges.none()) == Challenges.none() and Save.challenges_of(data, "wing_01") == [true, true, true, false], name, "a run completing none lost or reported challenges")
	Save.record(data, "wing_01", [true, true, false] as Array[bool], 70.0)
	Save.record_sketch(data, "wing_01")
	var back := Save.parse(Save.to_json(data), problems)
	_check(problems.is_empty() and back == data, name, "a save with challenges does not read back as written: %s, %s" % [back, problems])
	var v2 := Save.parse('{"version": 2, "wings": {"wing_01": {"stars": 2, "time": 70.5}}, "sketches": {"wing_01": true}, "settings": {"music": false, "sound": true, "reduce_motion": true, "assist": true}}', problems)
	_check(problems.is_empty() and v2["version"] == 3 and v2["wings"] == {"wing_01": {"stars": 2, "time": 70.5}} and v2["sketches"] == {"wing_01": true}
			and v2["challenges"] == {} and v2["settings"] == {"music": false, "sound": true, "reduce_motion": true, "assist": true}, name, "a version 2 save does not upgrade with its bests, sketches and settings: %s, %s" % [v2, problems])
	var v1 := Save.parse('{"version": 1, "wings": {"wing_02": {"stars": 3, "time": 99}}, "settings": {"music": true, "sound": false, "reduce_motion": false, "assist": false}}', problems)
	_check(problems.is_empty() and v1["version"] == 3 and v1["wings"] == {"wing_02": {"stars": 3, "time": 99.0}} and v1["sketches"] == {} and v1["challenges"] == {}
			and v1["settings"]["sound"] == false and Save.challenges_of(v1, "wing_02") == Challenges.none(), name, "a version 1 save does not upgrade with its bests and settings: %s, %s" % [v1, problems])
	for bad: String in ['{"version": 3, "wings": {}, "challenges": []}', '{"version": 3, "wings": {}, "challenges": {"wing_01": [true, false, true]}}',
			'{"version": 3, "wings": {}, "challenges": {"wing_01": [true, false, true, 1]}}', '{"version": 3, "wings": {}, "challenges": {"wing_01": true}}']:
		problems.clear()
		_check(Save.parse(bad, problems).is_empty() and problems.size() == 1, name, "save '%s' is not refused with one problem: %s" % [bad, problems])


## Game.record_escape keeps the run's challenges in the save (written) and returns those first
## completed under "challenges"; a room loaded on its own records none.
func _test_record_escape_challenges() -> void:
	var name := "record_escape_challenges"
	_game.save = Save.defaults()
	_game.run = WingRun.new(load(Content.WINGS[0]) as WingData)
	var beaten := _game.record_escape([true, true, true] as Array[bool], 40.0, [true, false, true, false] as Array[bool])
	_check(beaten["challenges"] == [true, false, true, false] and Save.challenges_of(_game.save, "wing_01") == [true, false, true, false], name, "a first escape's challenges are not kept and reported: %s" % [beaten])
	beaten = _game.record_escape([true, true, false] as Array[bool], 90.0, [true, true, false, false] as Array[bool])
	_check(beaten["challenges"] == [false, true, false, false] and Save.challenges_of(_game.save, "wing_01") == [true, true, true, false], name, "a worse escape completing a new challenge did not keep and report only it: %s" % [beaten])
	var problems: Array[String] = []
	_check(Save.parse(FileAccess.get_file_as_string(_game.save_path), problems) == _game.save, name, "the new challenge was not written to the save")
	_game.run = WingRun.new(WingData.new())
	_check(_game.record_escape([true, true, true] as Array[bool], 1.0, [true, true, true, true] as Array[bool])["challenges"] == Challenges.none(), name, "a run without a wing file recorded challenges")
	_game.run = null
	_game.save = Save.defaults()
	DirAccess.remove_absolute(_game.save_path)


## The results pop the four challenge badges after the stars: completed ones bright (with the
## `challenge` sound), the rest dim, a first completion with its rosette; the row sits on the
## panel clear of the stars, legends, rosettes, sketch, buttons and mime. No challenges given: none show.
func _test_results_challenge_badges() -> void:
	var name := "results_challenge_badges"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	var results := room.get_node("ResultsLayer/Results") as Results
	var wait := (Results.STAR_GAP + Results.POP_TIME) * 3.0 + Results.STAR_GAP * 8.0 + Results.POP_TIME + 0.2
	results.present([true, true, true] as Array[bool], {"stars": true, "time": true, "challenges": [false, true, false, false]}, Paintings.SKETCHES.get(&"pearl_earring"), [true, true, false, true] as Array[bool])
	await create_timer(wait).timeout
	_check(results.badges.all(func(each: TextureRect) -> bool: return each.visible and each.scale.is_equal_approx(Vector2.ONE)), name, "not every challenge badge popped in")
	_check(results.badges[0].modulate == Color.WHITE and results.badges[2].modulate == Results.BADGE_DIM and _game.audio.played.has(&"challenge"), name, "completed badges are not bright with their sound and missed ones dim")
	_check(results.badge_rosettes[1].visible and not results.badge_rosettes[0].visible and not results.badge_rosettes[3].visible and _game.audio.played.has(&"challenge_new"), name, "only the first completion should pin its rosette")
	var inner := (results.get_node("Panel/Inner") as Control).get_rect()
	var others: Array[Rect2] = [Rect2(results.mime.position - Vector2(30, 90), Vector2(60, 95))]
	for path: String in ["Star0", "Star1", "Star2", "Legend0", "Legend1", "Legend2", "StarsBest", "TimeBest", "Sketch", "ReplayButton", "HomeButton"]:
		others.append((results.get_node("Panel/" + path) as Control).get_rect().grow(4.0))
	var rects: Array[Rect2] = []
	for i in results.badges.size():
		for each: TextureRect in [results.badges[i], results.badge_rosettes[i]]:
			rects.append(each.get_rect())
	for rect in rects:
		_check(inner.encloses(rect), name, "a badge at %s leaves the panel %s" % [rect, inner])
		for other in others:
			_check(not rect.intersects(other), name, "a badge at %s covers %s" % [rect, other])
	for i in results.badges.size() - 1:
		_check(not results.badges[i].get_rect().intersects(results.badges[i + 1].get_rect()), name, "badges %d and %d overlap" % [i, i + 1])
	results.present([true, false, false] as Array[bool])
	await create_timer(wait).timeout
	_check(not (results.badges + results.badge_rosettes).any(func(each: TextureRect) -> bool: return each.visible), name, "badges showed with no challenges given")


## A hub door shows a pip for each challenge its wing ever completed, from the save; the pips
## stay clear of the stars, the sketch, the painting, the archway and the neighbouring door.
func _test_hub_challenge_pips() -> void:
	var name := "hub_challenge_pips"
	_game.run = null
	_game.save = Save.defaults()
	Save.record(_game.save, "wing_01", [true, true, true] as Array[bool], 60.0)
	Save.record_challenges(_game.save, "wing_01", [true, false, true, true] as Array[bool])
	var hub := await _load_hub()
	_check(hub.wing_doors[0].challenges == [true, false, true, true] and hub.wing_doors[1].challenges == Challenges.none(), name, "the doors do not carry their wings' challenges")
	var keep_out: Array[Rect2] = [WingDoor.SKETCH_RECT, Rect2(WingDoor.PICTURE_CENTER - WingDoor.PICTURE_SIZE / 2.0, WingDoor.PICTURE_SIZE), WingDoor.OPENING.grow(5.0),
		Rect2(-WingDoor.OPENING.size.x / 2.0 - 5.0, WingDoor.OPENING.position.y - WingDoor.OPENING.size.x / 2.0 - 5.0, WingDoor.OPENING.size.x + 10.0, WingDoor.OPENING.size.x + 10.0)]
	for i in 3:
		keep_out.append(Rect2(Vector2((i - 1) * (WingDoor.STAR_SIZE + 4.0) - WingDoor.STAR_SIZE / 2.0, WingDoor.STAR_ROW_Y - WingDoor.STAR_SIZE / 2.0), Vector2.ONE * WingDoor.STAR_SIZE))
	for i in Challenges.Challenge.size():
		var pip := WingDoor.pip_rect(i)
		_check(absf(pip.position.x) < Hub.DOOR_GAP / 2.0 and absf(pip.end.x) < Hub.DOOR_GAP / 2.0, name, "pip %d at %s reaches the next door" % [i, pip])
		for j in i:
			_check(not pip.intersects(WingDoor.pip_rect(j)), name, "pips %d and %d overlap" % [i, j])
		for other in keep_out:
			_check(not pip.intersects(other), name, "pip %d at %s covers %s" % [i, pip, other])
	_game.save = Save.defaults()


## A stolen original's plaque carries its wing's four challenge badges round the replay
## button, never under it, all on the plaque.
func _test_hideout_challenge_badges() -> void:
	var name := "hideout_challenge_badges"
	_game.run = null
	_game.save = Save.defaults()
	Save.record(_game.save, "wing_02", [true, false, false] as Array[bool], 200.0)
	Save.record_challenges(_game.save, "wing_02", [false, true, false, true] as Array[bool])
	change_scene_to_file("res://scenes/hideout.tscn")
	for i in 3:
		await process_frame
	var hideout := current_scene as Hideout
	if hideout == null:
		_check(false, name, "the hideout did not load")
		return
	var decor := hideout.get_node("Decor") as HideoutDecor
	_check(decor.challenges.size() == Content.WINGS.size() and decor.challenges[1] == [false, true, false, true] and decor.challenges[0] == Challenges.none(), name, "the plaques do not carry their wings' challenges: %s" % [decor.challenges])
	for index in Content.WINGS.size():
		var plate := HideoutDecor.plaque_rect(index)
		var replay := Rect2(plate.get_center() - Vector2.ONE * Hideout.REPLAY_SIZE / 2.0, Vector2.ONE * Hideout.REPLAY_SIZE)
		for i in Challenges.Challenge.size():
			var badge := HideoutDecor.badge_rect(index, i)
			_check(plate.encloses(badge) and not badge.intersects(replay), name, "frame %d's badge %d at %s is off its plaque %s or under the replay button" % [index, i, badge, plate])
			for j in i:
				_check(not badge.intersects(HideoutDecor.badge_rect(index, j)), name, "frame %d's badges %d and %d overlap" % [index, i, j])
		if index + 1 < Content.WINGS.size():
			_check(not plate.intersects(HideoutDecor.plaque_rect(index + 1)), name, "plaques %d and %d overlap" % [index, index + 1])
	var button := hideout.get_node("Replay2") as Button
	_check(button != null and button.get_rect().is_equal_approx(Rect2(HideoutDecor.plaque_rect(1).get_center() - button.size / 2.0, button.size)), name, "the replay button is not centred on its plaque")
	_game.save = Save.defaults()
