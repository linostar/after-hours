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
		_test_guard_patrols,
		_test_guard_sees_and_tosses,
		_test_guard_partition_blocks_sight,
		_test_guard_ignores_behind,
		_test_guard_pauses_facing_its_leg,
		_test_catches_during_swap_and_while_carrying,
		_test_title_play_starts_room,
		_test_goto_missing_scene_reports,
		_test_room_swap_and_escape,
		_test_room_swap_cancel_and_locked_exit,
		_test_results_buttons,
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
	_check(play.has_focus(), name, "the play button does not have keyboard focus")
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


func _check(condition: bool, test_name: String, detail: String) -> void:
	_checks += 1
	if not condition:
		_failures.append("%s: %s" % [test_name, detail])
