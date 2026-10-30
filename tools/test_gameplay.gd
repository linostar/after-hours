extends SceneTree
## Headless gameplay tests. Run with --fixed-fps 60 so one frame = one physics tick:
##   "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/test_gameplay.gd"
## Prints "test_gameplay: OK" when every test passes; exits 1 otherwise.
## To add a test: write a `_test_*` func (it may await) that reports through _check(),
## and append it to the list in _tests(). Tests run in that order on one SceneTree, so
## each one restores whatever it changes (Game.quiet_errors, Game.errors, the badge).

const TITLE_PATH := "res://scenes/title.tscn"
const ROOM_PATH := "res://scenes/room.tscn"
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
		_test_room_tap_walks_around_partition,
		_test_room_tap_on_wall_stops_at_floor,
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
	_check(Detection.is_caught(1.0) and not Detection.is_caught(0.999), name, "a catch is not exactly full suspicion")
	# Seen point-blank from nothing, a catch takes 1 / (FILL_FAR + FILL_NEAR) seconds at 60 ticks per second.
	var suspicion := 0.0
	var ticks := 0
	while not Detection.is_caught(suspicion) and ticks < 600:
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


## Loads the slice room and waits until the navigation map has synced its navmesh.
func _load_room() -> Room:
	var error := change_scene_to_file(ROOM_PATH)
	if error != OK:
		_check(false, "load_room", "cannot load %s: %s" % [ROOM_PATH, error_string(error)])
		return null
	for i in 3:
		await physics_frame
	return current_scene as Room


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
	await _tap_at(Vector2(200, 60))
	await _walk_trace(room.mime, 600)
	_check(not room.mime.walking, name, "the mime was still walking after 600 frames")
	_check(absf(room.mime.position.y - FLOOR_TOP) <= 6.0 and absf(room.mime.position.x - 200.0) <= 6.0, name, "the mime stopped at %s, expected about (200, %d)" % [room.mime.position, FLOOR_TOP])


func _check(condition: bool, test_name: String, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [test_name, detail])
