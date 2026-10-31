extends SceneTree
## Headless gameplay tests. Run with --fixed-fps 60 so one frame = one physics tick:
##   "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/test_gameplay.gd"
## Prints "test_gameplay: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Tests run in that order on one SceneTree, so
## each one restores whatever it changes (Game.quiet_errors, Game.errors, the badge).

const TITLE_PATH := "res://scenes/title.tscn"
const ROOM_PATH := "res://scenes/room.tscn"
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


func _tests() -> Array[Callable]:
	return [
		_test_project_display_and_input,
		_test_project_strict_warnings,
		_test_web_export_preset,
		_test_title_arrives,
		_test_report_error_shows_badge,
		_test_detection_cone,
		_test_detection_suspicion,
		_test_stars,
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
		_test_guard_partition_blocks_sight,
		_test_guard_ignores_behind,
		_test_guard_chase_search_return,
		_test_tilt_decoy_investigated,
		_test_tilted_frame_seen_and_straightened,
		_test_hide_unseen_and_step_out,
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
		_test_catches_during_swap_and_while_carrying,
		_test_title_play_starts_room,
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
		_test_unknown_painting_reports,
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
	_check(room.mime.position == Room.ENTRANCE, name, "the mime starts at %s, not the entrance %s" % [room.mime.position, Room.ENTRANCE])
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
	_check(room.mime.position == Room.ENTRANCE and room.mime.rotation == 0.0, name, "after the toss the mime is at %s (rotation %f), not upright at the entrance" % [room.mime.position, room.mime.rotation])
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


## At a waypoint the guard pauses still facing the leg it walked, then turns to the next.
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
	for i in 12:
		await physics_frame
	var next_leg := (room.guard.route[2] - corner).normalized()
	_check(room.guard.facing.is_equal_approx(next_leg), name, "after the pause the guard faces %s, not its next leg %s" % [room.guard.facing, next_leg])


## A catch mid-swap cancels the swap. A catch while carrying keeps the original (only the
## guard resets): the mime still escapes, and being seen costs the unseen star.
func _test_catches_during_swap_and_while_carrying() -> void:
	var name := "catches_during_swap_and_while_carrying"
	var room := await _load_room()
	if room == null:
		return
	room.guard.active = false
	room._on_painted(Forgery.ASSIST_QUALITY)
	await _tap_at(Room.PAINTING_RECT.get_center())
	await _wait_until(func() -> bool: return room.mime.swap_progress > 0.3, 900)
	await _tap_at(Room.PAINTING_RECT.get_center())
	_check(room.mime.swap_progress > 0.3 and room.swap_intent, name, "a second tap on the painting restarted the swap")
	room.guard.active = true
	_stage_guard(room, room.mime.position + Vector2(-80, 0), Vector2.RIGHT, room.mime.position)
	await _wait_until(func() -> bool: return room.tossing, 120)
	_check(room.tossing and room.mime.swap_progress == 0.0 and not room.swap_intent, name, "a catch mid-swap did not cancel it")
	await _wait_until(func() -> bool: return not room.tossing, 180)
	room.guard.active = false
	room.mime.place_at(Room.SWAP_SPOT)
	room._on_painted(Forgery.ASSIST_QUALITY)
	room.swap_intent = true
	await _wait_until(func() -> bool: return room.mime.carrying, 180)
	room.guard.active = true
	_stage_guard(room, Vector2(700, 330), Vector2.RIGHT, Vector2(780, 330))
	await _wait_until(func() -> bool: return room.tossing, 120)
	await _wait_until(func() -> bool: return not room.tossing, 180)
	_check(room.mime.carrying and (room.get_node("ExitGlow") as Polygon2D).visible, name, "a catch while carrying took the original away")
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
	_stage_guard(room, Vector2(660, 430), Vector2.LEFT, Room.ENTRANCE)
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


## A guard that sees a tilted frame without hearing it walks over and straightens it.
func _test_tilted_frame_seen_and_straightened() -> void:
	var name := "tilted_frame_seen_and_straightened"
	var room := await _load_room()
	if room == null:
		return
	room.guard.target = null
	var frame := room.get_node("Frames/FrameA") as TiltFrame
	frame.tilt()
	_stage_guard(room, Vector2(frame.position.x, 260), Vector2.UP, Room.ENTRANCE)
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
	_stage_guard(room, Vector2(500, 430), Vector2.RIGHT, Room.ENTRANCE)
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
	# A key held from the room's first frame, before the map holds its navmesh (queries
	# answer (0, 0) then), leaves the mime where it is.
	change_scene_to_file(ROOM_PATH)
	await process_frame
	await process_frame
	var early := current_scene as Room
	early.mime.nudge(Vector2.RIGHT, 1.0 / 60.0)
	_check(early.mime.position == Room.ENTRANCE, name, "a nudge before the navmesh was in moved the mime to %s" % early.mime.position)
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
	room.mime.place_at(Room.EASEL_SPOT + Vector2(40, 0))
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
	_stage_guard(room, Vector2(660, 430), Vector2.LEFT, Room.ENTRANCE)
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
	_stage_guard(room, frame.view_point() + Vector2(0, 150), Vector2.DOWN, Room.ENTRANCE)
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
	_stage_guard(room, Vector2(450, 260), Vector2.UP, Room.ENTRANCE)
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


## The title's play button fades to the room; a second goto during the fade is ignored.
func _test_title_play_starts_room() -> void:
	var name := "title_play_starts_room"
	change_scene_to_file(TITLE_PATH)
	await process_frame
	await process_frame
	var play := current_scene.get_node("PlayButton") as Button
	_check(play.has_focus(true), name, "the play button does not have visible keyboard focus (hidden focus shows no ring)")
	await _tap_control(play)
	_check(_game.is_transitioning(), name, "tapping play did not start a screen change")
	_game.goto(GameState.Flow.TITLE)
	var arrived := await _wait_until(func() -> bool: return not _game.is_transitioning(), 120)
	_check(arrived and current_scene != null and current_scene.scene_file_path == ROOM_PATH, name, "the room is not running after the fade (a goto during it was not ignored?)")
	_check(_game.state == GameState.Flow.ROOM, name, "Game.state is %s, expected ROOM" % GameState.Flow.keys()[_game.state])


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
	await _tap_at(Room.PAINTING_RECT.get_center())
	_check(room.swap_intent, name, "a tap on the masterpiece did not mean swap")
	var swapped := await _wait_until(func() -> bool: return room.mime.carrying, 900)
	_check(swapped, name, "the mime never swapped the painting (at %s, progress %.2f)" % [room.mime.position, room.mime.swap_progress])
	_check((room.get_node("ExitGlow") as Polygon2D).visible, name, "the exit door does not glow while carrying the original")
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
	await _tap_at(Room.PAINTING_RECT.get_center())
	var swapping := await _wait_until(func() -> bool: return room.mime.swap_progress > 0.3, 900)
	_check(swapping, name, "the swap never got going")
	await _tap_at(Vector2(950, 330))
	_check(room.mime.swap_progress == 0.0 and not room.swap_intent, name, "tapping away did not cancel the swap")
	await _walk_trace(room.mime, 900)
	_check(room.mime.position.distance_to(Room.EXIT) <= Room.EXIT_REACH, name, "the mime did not reach the exit (at %s)" % room.mime.position)
	for i in 10:
		await physics_frame
	_check(not room.finished and not room.mime.carrying, name, "the exit ended the wing without the original")


## Taps the easel and waits (at most 600 frames) for the canvas to open; returns it.
func _open_easel(room: Room) -> ForgeryCanvas:
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	await _tap_at(Room.EASEL_RECT.get_center())
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
	var glow := room.get_node("EaselGlow") as Polygon2D
	_check(glow.visible and not room.mime.has_fake, name, "the easel does not glow at the start, or the mime starts with a fake")
	await _tap_at(Room.PAINTING_RECT.get_center())
	_check(not room.swap_intent, name, "a tap on the masterpiece without a fake meant swap")
	var canvas := await _open_easel(room)
	_check(canvas.visible and room.mime.position.distance_to(Room.EASEL_SPOT) <= Room.SWAP_REACH, name, "tapping the easel did not open the canvas with the mime at the easel (at %s)" % room.mime.position)
	await _tap_at(Vector2(100, 480))
	_check(not room.mime.walking, name, "a tap beside the open canvas walked the mime")
	await _trace_rest(canvas)
	_check(await _wait_until(func() -> bool: return room.mime.has_fake, 120), name, "tracing every ghost gave the mime no fake")
	_check(not glow.visible and not canvas.visible, name, "after painting the easel still glows or the canvas stays open")
	_check(Forgery.grade(room.fake_quality) == Forgery.Grade.PERFECT, name, "an exact trace of the room's painting graded %s (%.2f)" % [Forgery.Grade.keys()[Forgery.grade(room.fake_quality)], room.fake_quality])
	var carried := room.mime.get_node("Carried") as FramedPainting
	_check(carried.visible and carried.modulate == Mime.FAKE_TINT, name, "the carried fake does not show, tinted")
	await _tap_at(Room.PAINTING_RECT.get_center())
	_check(await _wait_until(func() -> bool: return room.mime.carrying, 900), name, "the fake never swapped for the original")
	_check(not room.mime.has_fake and carried.modulate == Color.WHITE, name, "after the swap the mime still has the fake, or the original shows tinted")
	await _tap_at(Room.EASEL_RECT.get_center())
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
	_check(room.guard.intent == GuardBrain.Intent.SEARCH and room.guard.search_point == Room.FAKE_VIEW_POINT, name, "after a found-out fake the guard is %s around %s, not searching the fake" % [_intent_name(room.guard.intent), room.guard.search_point])
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
		"the easel": Room.EASEL_RECT,
		"the painting mime": Rect2(Room.EASEL_SPOT - Vector2(30, 100), Vector2(60, 104)),
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
	_check(current_scene != null and current_scene.scene_file_path == TITLE_PATH and _game.state == GameState.Flow.TITLE, name, "home did not return to the title")


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


## A frame naming an unknown painting is reported and stays empty.
func _test_unknown_painting_reports() -> void:
	var name := "unknown_painting_reports"
	var picture := FramedPainting.new()
	picture.painting = "no_such_painting"
	var errors_before := _game.errors.size()
	_game.quiet_errors = true
	root.add_child(picture)
	_game.quiet_errors = false
	_check(_game.errors.size() == errors_before + 1 and "no_such_painting" in _game.errors[-1], name, "an unknown painting was not reported (errors: %s)" % [_game.errors.slice(errors_before)])
	_check(picture.picture() == null, name, "an unknown painting shows a picture")
	_game.errors.resize(errors_before)
	(_game.get_node("ErrorLayer/ErrorBadge") as TextureRect).visible = false
	picture.queue_free()
	await process_frame


func _check(condition: bool, test_name: String, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [test_name, detail])
