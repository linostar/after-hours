extends SceneTree
## The playtest bot (AC 29): plays wings headlessly through synthetic touches, as a player
## would, and proves each one beatable with every star. A wing's bot_route lists its taps
## (base units: the easel, a portrait, a door, the masterpiece, the exit...) in order;
## bot_waits holds how long to wait before each. After a tap the bot waits until the mime
## has settled (arrived and done what the tap meant: painted, by tracing every ghost stroke
## exactly; swapped; hidden; through a door); a catch, a sighting or a leg running past
## LEG_TIMEOUT fails the run. Guards are deterministic, so a replay plays out the same.
##
## Run with --fixed-fps 60 (one frame = one physics tick):
##   "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/bot.gd" \
##       -- [--record <wing.tres>] [--wing <wing.tres>]...
## Default: replays every wing in Content.WINGS (and each --wing) with its bot_waits and
##   fails unless it escapes unseen within par_time; prints "bot: OK (N wings)".
## --record: searches bot_waits leg by leg (each wait from 0 to MAX_WAIT in WAIT_STEP,
##   the first that gets the leg through unseen), then writes them, par_time (the bot's
##   time plus PAINT_ALLOWANCE per ghost stroke, times PAR_FACTOR, up to the next
##   PAR_ROUND seconds) and the ghost replay
##   (data/ghosts/<wing file name>.ghost.json, or beside a wing outside data/wings: the
##   mime's room, position and hiding every TRAIL_GAP frames) for the wing.

const TOUCH_INDEX := 7
const BASE_WINDOW := Vector2i(960, 540)
const WAIT_STEP := 0.25
const MAX_WAIT := 16.0
const LEG_TIMEOUT := 30.0
const PAR_FACTOR := 1.25
## Seconds a person takes per ghost stroke beyond the bot's instant tracing, added to the
## bot's time before PAR_FACTOR.
const PAINT_ALLOWANCE := 4.0
const PAR_ROUND := 5.0
const TRAIL_GAP := 6
const GHOSTS_DIR := "res://data/ghosts/"
## A wing outside this directory (a test fixture) keeps its ghost replay beside it.
const WINGS_DIR := "res://data/wings/"
## Real-time limit for the whole run.
const WATCHDOG_MSEC := 600000

var _game: GameState
var _deadline_msec := 0
## The current run's trail, and the frames since its last sample.
var _trail: Array = []
var _trail_wait := 0


## The outcome of one play: whether every leg settled and the mime escaped, whether it
## was seen or caught, the leg that failed (-1 for none), the wing time and the trail.
class Play:
	var escaped := false
	var seen := false
	var caught := false
	var failed_leg := -1
	var time := 0.0
	var trail: Array = []


func _initialize() -> void:
	_deadline_msec = Time.get_ticks_msec() + WATCHDOG_MSEC
	_game = root.get_node_or_null("Game") as GameState
	if _game == null:
		printerr("bot: FAILED: Game autoload not found")
		quit(1)
		return
	_main.call_deferred()


func _process(_delta: float) -> bool:
	if Time.get_ticks_msec() > _deadline_msec:
		printerr("bot: FAILED watchdog: not done within %d ms" % WATCHDOG_MSEC)
		quit(1)
	return false


func _main() -> void:
	root.size = BASE_WINDOW
	_game.quiet_errors = false
	var args := OS.get_cmdline_user_args()
	var paths: Array[String] = Content.WINGS.duplicate()
	var recording := ""
	var i := 0
	while i < args.size():
		if args[i] in ["--wing", "--record"] and i + 1 < args.size():
			if args[i] == "--record":
				recording = args[i + 1]
			else:
				paths.append(args[i + 1])
			i += 2
		else:
			printerr("bot: FAILED: unknown argument '%s'" % args[i])
			quit(2)
			return
	if recording != "":
		quit(0 if await _record(recording) else 1)
		return
	var failures: Array[String] = []
	for path in paths:
		var problem := await _check_wing(path)
		if problem != "":
			failures.append(problem)
	if failures.is_empty():
		print("bot: OK (%d wings)" % paths.size())
		quit(0)
		return
	for failure in failures:
		printerr("bot: FAIL " + failure)
	quit(1)


## Replays the wing at `path` with its bot_waits; returns what is wrong ("" for a run that
## escapes unseen within par_time).
func _check_wing(path: String) -> String:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	if wing == null:
		return "; ".join(problems)
	if wing.bot_waits.size() != wing.bot_route.size():
		return "%s: %d waits for %d route taps (run --record)" % [path, wing.bot_waits.size(), wing.bot_route.size()]
	var play := await _play(wing, wing.bot_waits, wing.bot_route.size())
	print("bot: %s: escaped %s, seen %s, caught %s, failed leg %d, %.2f s (par %.0f)" % [path, play.escaped, play.seen, play.caught, play.failed_leg, play.time, wing.par_time])
	if not play.escaped or play.seen or play.caught:
		return "%s: the recorded run no longer escapes unseen (leg %d: %s)" % [path, play.failed_leg, _leg_name(wing, play.failed_leg)]
	if play.time > wing.par_time:
		return "%s: the run took %.2f s, over par %.0f" % [path, play.time, wing.par_time]
	return ""


## Finds bot_waits for the wing at `path` leg by leg, then writes them, its par time and
## its ghost replay. Returns whether it found a run.
func _record(path: String) -> bool:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	if wing == null:
		printerr("bot: FAILED: " + "; ".join(problems))
		return false
	var waits := PackedFloat32Array()
	var tries := 0
	for leg in wing.bot_route.size():
		var found := false
		var wait := 0.0
		while wait <= MAX_WAIT and not found:
			var trial := waits.duplicate()
			trial.append(wait)
			var play := await _play(wing, trial, leg + 1)
			tries += 1
			var last := leg == wing.bot_route.size() - 1
			found = play.failed_leg == -1 and not play.seen and not play.caught and (play.escaped or not last)
			if found:
				waits = trial
			else:
				wait += WAIT_STEP
		if not found:
			printerr("bot: FAILED: %s: no wait up to %.1f s gets leg %d (%s) through unseen" % [path, MAX_WAIT, leg, _leg_name(wing, leg)])
			return false
		print("bot: %s: leg %d (%s) waits %.2f s" % [path, leg, _leg_name(wing, leg), waits[leg]])
	var best := await _play(wing, waits, wing.bot_route.size())
	wing.bot_waits = waits
	wing.par_time = ceilf((best.time + PAINT_ALLOWANCE * wing.ghosts.size()) * PAR_FACTOR / PAR_ROUND) * PAR_ROUND
	var error := ResourceSaver.save(wing, path)
	if error != OK:
		printerr("bot: FAILED: cannot save %s: %s" % [path, error_string(error)])
		return false
	var ghost_dir := GHOSTS_DIR if path.get_base_dir() + "/" == WINGS_DIR else path.get_base_dir() + "/"
	var ghost_path := ghost_dir + path.get_file().get_basename() + ".ghost.json"
	DirAccess.make_dir_recursive_absolute(ghost_dir)
	var file := FileAccess.open(ghost_path, FileAccess.WRITE)
	if file == null:
		printerr("bot: FAILED: cannot write %s: %s" % [ghost_path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(JSON.stringify({"wing": path, "time": snappedf(best.time, 0.01), "gap_frames": TRAIL_GAP, "trail": best.trail}) + "\n")
	file.close()
	print("bot: recorded %s in %d plays: %.2f s, par %.0f, ghost %s" % [path, tries, best.time, wing.par_time, ghost_path])
	return true


## Plays `wing` from its start: for each of its first `legs` route taps, waits `waits[i]`
## seconds, taps, and waits for the mime to settle; stops at the first leg that fails.
func _play(wing: WingData, waits: PackedFloat32Array, legs: int) -> Play:
	var play := Play.new()
	_trail = []
	_trail_wait = 0
	_game.play_wing(wing)
	var room := await _next_room(null)
	for leg in legs:
		if room == null:
			play.failed_leg = leg
			break
		for frame in roundi(waits[leg] * 60.0):
			await _tick(room)
			if _spoiled(room, play):
				break
		if _spoiled(room, play):
			play.failed_leg = leg
			break
		await _tap(wing.bot_route[leg])
		var settled := await _settle(room, play)
		if not settled:
			play.failed_leg = leg
			break
		room = current_scene as Room
	if room != null:
		play.escaped = room.finished
		play.time = room.elapsed
		play.seen = play.seen or room.ever_seen
	play.trail = _trail
	_game.run = null
	return play


## Whether the run is already lost for an unseen escape: seen or caught.
func _spoiled(room: Room, play: Play) -> bool:
	play.seen = play.seen or room.ever_seen
	play.caught = play.caught or room.catches > 0
	return play.seen or play.caught


## After a tap: waits until the room's mime has settled (or the room changed, or the wing
## ended); paints the canvas when it opens. False when it spoils or times out.
func _settle(room: Room, play: Play) -> bool:
	var canvas := room.get_node("EaselLayer/ForgeryCanvas") as ForgeryCanvas
	for frame in roundi(LEG_TIMEOUT * 60.0):
		if room.leaving:
			return await _next_room(room) != null
		if room.finished:
			return true
		if _spoiled(room, play):
			return false
		if canvas.visible and not canvas.is_finished():
			await _paint(canvas)
			continue
		var busy := room.mime.walking or room.swap_intent or room.paint_intent or room.hide_target != null or room.tilt_target != null or canvas.visible or room.tossing
		if not busy and not _game.is_transitioning():
			return true
		await _tick(room)
	return false


## Waits for the room after `from` (null: the first) to be current and ready.
func _next_room(from: Room) -> Room:
	for frame in 300:
		var room := current_scene as Room
		if room != null and room != from and room.is_node_ready() and not _game.is_transitioning():
			return room
		await physics_frame
	return null


## One physics frame, sampling the trail every TRAIL_GAP frames.
func _tick(room: Room) -> void:
	_trail_wait -= 1
	if _trail_wait <= 0:
		_trail_wait = TRAIL_GAP
		_trail.append([_game.run.room if _game.run != null else 0, roundi(room.mime.position.x), roundi(room.mime.position.y), room.hidden_in != null])
	await physics_frame


## Traces every remaining ghost exactly (a dab is a tap).
func _paint(canvas: ForgeryCanvas) -> void:
	var origin := (canvas.get_node("Pad") as Control).get_global_rect().position
	for i in range(canvas.traced.size(), canvas.ghosts.size()):
		var points := PackedVector2Array()
		for point in Forgery.resample(canvas.ghosts[i]):
			points.append(origin + point)
		await _drag_along(points)


func _tap(at: Vector2) -> void:
	await _drag_along(PackedVector2Array([at]))


## A touch pressed at the first point, dragged through the rest and lifted at the last,
## one event a frame.
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


func _leg_name(wing: WingData, leg: int) -> String:
	return "tap at %s" % wing.bot_route[leg] if leg >= 0 and leg < wing.bot_route.size() else "none"
