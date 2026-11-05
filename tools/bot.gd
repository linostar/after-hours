extends SceneTree
## The playtest bot (AC 29): plays wings headlessly through synthetic touches, as a player
## would, and proves each one beatable with every star. A wing's bot_route lists its taps
## (base units: the easel, a portrait, a door, the masterpiece, the exit...) in order;
## bot_waits holds how long to wait before each and bot_actions what each tap is
## (WingData.BotAction: a plain tap; a dash, the spot tapped twice; the ball or the rope,
## picked through the room's PowerBar.picked, then the tap at its target; the box, picked,
## no tap). After a tap the bot waits until the mime has settled (arrived and done what the
## tap meant: painted, by tracing every ghost stroke exactly at a person's pace, PAINT_PACE
## a stroke, while the room runs on; swapped; hidden in a portrait or the box; the ball
## landed; through a door); a catch, a sighting, a power or dash the room refused or a leg
## running past LEG_TIMEOUT fails the run. Guards are deterministic, so a replay plays out
## the same.
##
## Run with --fixed-fps 60 (one frame = one physics tick):
##   "$GODOT" --headless --path afterhours --fixed-fps 60 --script "$PWD/tools/bot.gd" \
##       -- [--record <wing.tres>] [--speed <wing.tres>] [--wing <wing.tres>]... [--check <wing.tres>]...
## --check: replays and proves only the wings named (development).
## Default: replays every wing in Content.WINGS (and each --wing) with its bot_waits and
##   fails unless it escapes unseen within par_time; prints "bot: OK (N wings)". For a wing
##   in data/wings it also proves the puzzles: every room but its trick_free ones has a trick
##   tap (bot_tricks) in the recorded run, and each trick is needed (the run without that tap
##   is seen or caught whatever the next leg waits, 0 to MAX_WAIT in ABLATE_STEP); and its
##   sketch_route (with sketch_waits) picks up the sketch and escapes, never caught; and its
##   speed_route (with speed_waits) escapes uncaught (seen allowed) within
##   Challenges.speed_target, the game awarding the SPEED challenge.
## --record: searches bot_waits leg by leg (each wait from 0 to MAX_WAIT in WAIT_STEP,
##   the first that gets the leg through unseen), then writes them, par_time (the bot's
##   time plus PAINT_ALLOWANCE per ghost stroke, times PAR_FACTOR, up to the next
##   PAR_ROUND seconds) and the ghost replay
##   (data/ghosts/<wing file name>.ghost.json, or beside a wing outside data/wings: the
##   mime's room, position and hiding every TRAIL_GAP frames) for the wing; then the
##   sketch_route's waits the same way (a leg passes when it settles uncaught: the sketch's
##   corner may be watched) as sketch_waits; then the speed_route's (a leg passes when it
##   settles uncaught, seen or not) as speed_waits, setting speed_target to the speed run's
##   time up to the next PAR_ROUND seconds when that is over half par (else 0: half par);
##   and proves the puzzles as above. When no wait gets a leg through, the leg before is
##   retried later (_record_route).
## --speed: records only the speed_route's waits (and speed_target), then replays it.

const TOUCH_INDEX := 7
const BASE_WINDOW := Vector2i(960, 540)
const WAIT_STEP := 0.25
const MAX_WAIT := 16.0
const LEG_TIMEOUT := 30.0
const PAR_FACTOR := 1.25
## Seconds the bot spends on each ghost stroke before tracing it, as a person would (about
## what the developer took in the step 9 playtest): the easel must stay unseen that long.
const PAINT_PACE := 2.5
## Seconds a person takes per ghost stroke beyond the bot's PAINT_PACE, added to the bot's
## time before PAR_FACTOR.
const PAINT_ALLOWANCE := 1.5
const PAR_ROUND := 5.0
## The next leg's waits an ablation tries, in seconds apart (0 to MAX_WAIT).
const ABLATE_STEP := 1.0
const TRAIL_GAP := 6
const GHOSTS_DIR := "res://data/ghosts/"
## A wing outside this directory (a test fixture) keeps its ghost replay beside it.
const WINGS_DIR := "res://data/wings/"
## Real-time limit for the whole run (the puzzle proofs replay every wing many times).
const WATCHDOG_MSEC := 2700000

## Which of a wing's routes the recorder searches (each has its own pass rule, _passes).
enum Route { MAIN, SKETCH, SPEED }
const ROUTE_NAMES: Array[String] = ["main", "sketch", "speed"]
## Seconds past Powers.BOX_TIME the leg after a box may wait (the box has opened by then).
const BOX_SLACK := 1.0
## When no wait gets a leg through, how much later the recorder retries the leg before it
## (coarser than WAIT_STEP: each retry searches this leg again) and up to what wait it then
## searches this leg (BOX_TIME + BOX_SLACK after a box, if less).
const LATER_STEP := 1.0
const LATER_CAP := 4.0

var _game: GameState
## Plays tried by the current recording.
var _tries := 0
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
	## The stars the game awarded (empty unless it escaped).
	var stars: Array[bool] = []
	var trail: Array = []
	## The room the mime was in at each tap, and whether it ended holding the sketch.
	var tap_rooms: Array[int] = []
	var has_sketch := false
	## The challenges the game judged (empty unless it escaped).
	var challenges: Array[bool] = []
	## Whether being seen leaves the run going (the speed route: only a catch spoils it).
	var seen_ok := false


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
	var speeding := ""
	var only: Array[String] = []
	var i := 0
	while i < args.size():
		if args[i] in ["--wing", "--record", "--speed", "--check"] and i + 1 < args.size():
			if args[i] == "--record":
				recording = args[i + 1]
			elif args[i] == "--speed":
				speeding = args[i + 1]
			elif args[i] == "--check":
				only.append(args[i + 1])
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
	if speeding != "":
		quit(0 if await _record_speed(speeding) else 1)
		return
	if not only.is_empty():
		paths = only
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
	var play := await _play(wing, wing.bot_waits, wing.bot_route.size(), wing.bot_route, wing.bot_actions)
	print("bot: %s: escaped %s, seen %s, caught %s, failed leg %d, %.2f s (par %.0f)" % [path, play.escaped, play.seen, play.caught, play.failed_leg, play.time, wing.par_time])
	if not play.escaped or play.seen or play.caught:
		return "%s: the recorded run no longer escapes unseen (leg %d: %s)" % [path, play.failed_leg, _leg_name(wing.bot_route, wing.bot_actions, play.failed_leg)]
	if play.time > wing.par_time:
		return "%s: the run took %.2f s, over par %.0f" % [path, play.time, wing.par_time]
	if Stars.count(play.stars) != Stars.Star.size():
		return "%s: the game awarded %s, not every star" % [path, play.stars]
	if path.get_base_dir() + "/" != WINGS_DIR:
		return ""
	return await _check_puzzles(path, wing, play)


## Proves `wing`'s puzzles from its recorded `play`: a trick in every room but the trick_free
## ones, each trick needed, and the sketch route; returns what is wrong ("" for none).
func _check_puzzles(path: String, wing: WingData, play: Play) -> String:
	var problems: Array[String] = []
	for room in wing.rooms.size():
		var tricked := false
		for trick in wing.bot_tricks:
			tricked = tricked or play.tap_rooms[trick] == room
		if not tricked and not room in wing.trick_free:
			problems.append("%s: room %d (%s) has no trick tap" % [path, room, wing.rooms[room].get_file()])
	for trick in wing.bot_tricks:
		var escaped_at := await _ablate(wing, trick)
		if escaped_at >= 0.0:
			problems.append("%s: trick tap %d (%s) is not needed: without it, waiting %.2f s before the next leg escapes unseen" % [path, trick, _leg_name(wing.bot_route, wing.bot_actions, trick), escaped_at])
		else:
			print("bot: %s: trick tap %d (%s) is needed" % [path, trick, _leg_name(wing.bot_route, wing.bot_actions, trick)])
	if wing.sketch_route.is_empty():
		problems.append("%s: no sketch_route" % path)
	elif wing.sketch_waits.size() != wing.sketch_route.size():
		problems.append("%s: %d sketch waits for %d sketch taps (run --record)" % [path, wing.sketch_waits.size(), wing.sketch_route.size()])
	else:
		var sketched := await _play(wing, wing.sketch_waits, wing.sketch_route.size(), wing.sketch_route, wing.sketch_actions)
		print("bot: %s: sketch route: escaped %s, sketch %s, caught %s, %.2f s" % [path, sketched.escaped, sketched.has_sketch, sketched.caught, sketched.time])
		if not sketched.escaped or not sketched.has_sketch or sketched.caught:
			problems.append("%s: the sketch route no longer picks up the sketch and escapes uncaught (leg %d)" % [path, sketched.failed_leg])
	var speeding := await _check_speed(path, wing)
	if speeding != "":
		problems.append(speeding)
	return "; ".join(problems)


## Replays `wing`'s speed_route: it must escape uncaught within Challenges.speed_target, the
## game awarding SPEED; returns what is wrong ("" for none).
func _check_speed(path: String, wing: WingData) -> String:
	var problems: Array[String] = []
	var speed := Challenges.speed_target(wing)
	if wing.speed_route.is_empty():
		problems.append("%s: no speed_route" % path)
	elif wing.speed_waits.size() != wing.speed_route.size():
		problems.append("%s: %d speed waits for %d speed taps (run --record)" % [path, wing.speed_waits.size(), wing.speed_route.size()])
	else:
		var sped := await _play(wing, wing.speed_waits, wing.speed_route.size(), wing.speed_route, wing.speed_actions, -1, true)
		print("bot: %s: speed route: escaped %s, seen %s, caught %s, %.2f s (target %.0f)" % [path, sped.escaped, sped.seen, sped.caught, sped.time, speed])
		if not sped.escaped or sped.caught:
			problems.append("%s: the speed route no longer escapes uncaught (leg %d)" % [path, sped.failed_leg])
		elif sped.time > speed or not sped.challenges[Challenges.Challenge.SPEED]:
			problems.append("%s: the speed route took %.2f s, over the speed target %.0f" % [path, sped.time, speed])
	return "; ".join(problems)


## Plays `wing` without its trick tap `trick` (waiting it out instead), trying each wait of
## the next leg from 0 to MAX_WAIT: returns the first wait that still escapes unseen, or -1
## when every one is seen or caught (the trick is needed).
func _ablate(wing: WingData, trick: int) -> float:
	var next := trick + 1
	var wait := 0.0
	while wait <= MAX_WAIT:
		var waits := wing.bot_waits.duplicate()
		if next < waits.size():
			waits[next] = wait
		var play := await _play(wing, waits, wing.bot_route.size(), wing.bot_route, wing.bot_actions, trick)
		if not play.seen and not play.caught:
			return wait
		if next >= waits.size():
			break
		wait += ABLATE_STEP
	return -1.0


## Finds bot_waits for the wing at `path` leg by leg, then writes them, its par time and
## its ghost replay. Returns whether it found a run.
func _record(path: String) -> bool:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	if wing == null:
		printerr("bot: FAILED: " + "; ".join(problems))
		return false
	_tries = 0
	var waits := await _record_route(path, wing, wing.bot_route, wing.bot_actions, Route.MAIN)
	if waits.is_empty():
		return false
	var best := await _play(wing, waits, wing.bot_route.size(), wing.bot_route, wing.bot_actions)
	wing.bot_waits = waits
	wing.par_time = ceilf((best.time + PAINT_ALLOWANCE * wing.ghosts.size()) * PAR_FACTOR / PAR_ROUND) * PAR_ROUND
	if not wing.sketch_route.is_empty():
		wing.sketch_waits = await _record_route(path, wing, wing.sketch_route, wing.sketch_actions, Route.SKETCH)
		if wing.sketch_waits.is_empty():
			return false
	if not wing.speed_route.is_empty() and not await _record_speed_waits(path, wing):
		return false
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
	print("bot: recorded %s in %d plays: %.2f s, par %.0f, ghost %s" % [path, _tries, best.time, wing.par_time, ghost_path])
	if path.get_base_dir() + "/" == WINGS_DIR:
		var problem := await _check_puzzles(path, wing, best)
		if problem != "":
			printerr("bot: FAILED: " + problem)
			return false
	return true


## --speed: finds only the speed_route's waits (and speed_target) of the wing at `path`, its
## other waits as recorded, writes them and proves the speed route. Returns whether it did.
func _record_speed(path: String) -> bool:
	var problems: Array[String] = []
	var wing := Content.load_wing(path, problems)
	if wing == null:
		printerr("bot: FAILED: " + "; ".join(problems))
		return false
	_tries = 0
	if not await _record_speed_waits(path, wing):
		return false
	var error := ResourceSaver.save(wing, path)
	if error != OK:
		printerr("bot: FAILED: cannot save %s: %s" % [path, error_string(error)])
		return false
	var problem := await _check_speed(path, wing)
	if problem != "":
		printerr("bot: FAILED: " + problem)
		return false
	print("bot: recorded the speed route of %s in %d plays" % [path, _tries])
	return true


## Finds `wing`'s speed_waits and sets its speed_target: the speed run's time up to the next
## PAR_ROUND when that is over half par, else 0 (half par). False when no wait gets a leg through.
func _record_speed_waits(path: String, wing: WingData) -> bool:
	wing.speed_waits = await _record_route(path, wing, wing.speed_route, wing.speed_actions, Route.SPEED)
	if wing.speed_waits.is_empty():
		return false
	var sped := await _play(wing, wing.speed_waits, wing.speed_route.size(), wing.speed_route, wing.speed_actions, -1, true)
	var rounded := ceilf(sped.time / PAR_ROUND) * PAR_ROUND
	wing.speed_target = rounded if sped.time > wing.par_time / 2.0 else 0.0
	print("bot: %s: speed route %.2f s (seen %s), speed target %.0f (half par %.1f)" % [path, sped.time, sped.seen, Challenges.speed_target(wing), wing.par_time / 2.0])
	return true


## Finds the waits of `route` (with `actions`) leg by leg, each the first from 0 that gets the
## leg through as `kind` asks (_passes): up to MAX_WAIT, or BOX_TIME + BOX_SLACK after a box
## (it has opened by then). Greedy, the earliest wait can leave the next leg no way through
## (a box or a hide left before its guard has passed); then the leg before is retried
## LATER_STEP later (still getting through) and the leg searched again up to LATER_CAP, until
## it gets through or the leg before reaches MAX_WAIT. Returns the waits, or none after
## printing the leg that no wait gets through.
func _record_route(path: String, wing: WingData, route: PackedVector2Array, actions: PackedInt32Array, kind: Route) -> PackedFloat32Array:
	var waits := PackedFloat32Array()
	while waits.size() < route.size():
		var leg := waits.size()
		var after_box := leg > 0 and _action(actions, leg - 1) == WingData.BotAction.BOX
		var cap := Powers.BOX_TIME + BOX_SLACK if after_box else MAX_WAIT
		var wait := await _search_wait(wing, route, actions, waits, leg, 0.0, cap, kind)
		while wait < 0.0 and leg > 0 and waits[leg - 1] + LATER_STEP <= MAX_WAIT:
			var before := await _search_wait(wing, route, actions, waits.slice(0, leg - 1), leg - 1, waits[leg - 1] + LATER_STEP, MAX_WAIT, kind)
			if before < 0.0:
				break
			waits[leg - 1] = before
			print("bot: %s: %s leg %d (%s) now waits %.2f s, for the leg after it" % [path, ROUTE_NAMES[kind], leg - 1, _leg_name(route, actions, leg - 1), before])
			wait = await _search_wait(wing, route, actions, waits, leg, 0.0, minf(cap, LATER_CAP), kind)
		if wait < 0.0:
			printerr("bot: FAILED: %s: no wait up to %.1f s gets %s leg %d (%s) through" % [path, cap, ROUTE_NAMES[kind], leg, _leg_name(route, actions, leg)])
			return PackedFloat32Array()
		waits.append(wait)
		print("bot: %s: %s leg %d (%s) waits %.2f s" % [path, ROUTE_NAMES[kind], leg, _leg_name(route, actions, leg), wait])
	return waits


## The first wait from `from` to `to` (WAIT_STEP apart) before leg `leg` of `route`, after
## `waits` for the legs before it, that gets the leg through as `kind` asks; -1 for none.
func _search_wait(wing: WingData, route: PackedVector2Array, actions: PackedInt32Array, waits: PackedFloat32Array, leg: int, from: float, to: float, kind: Route) -> float:
	var wait := from
	while wait <= to:
		var trial := waits.duplicate()
		trial.append(wait)
		var play := await _play(wing, trial, leg + 1, route, actions, -1, kind == Route.SPEED)
		_tries += 1
		if _passes(play, kind, leg == route.size() - 1):
			return wait
		wait += WAIT_STEP
	return -1.0


## Whether a recording's `play` got its last leg through as a route of `kind` asks: every leg
## settled and uncaught; the main route unseen too; the `last` leg escaped (holding the sketch,
## for the sketch route).
func _passes(play: Play, kind: Route, last: bool) -> bool:
	if play.failed_leg != -1 or play.caught or (kind == Route.MAIN and play.seen):
		return false
	return not last or (play.escaped and (kind != Route.SKETCH or play.has_sketch))


## Plays `wing` from its start: for each of its first `legs` taps of `route`, waits `waits[i]`
## seconds, does the tap as `actions` says (all but tap `skip`, which it only waits out), and
## waits for the mime to settle; stops at the first leg that fails (spoiled by a sighting
## too unless `seen_ok`).
func _play(wing: WingData, waits: PackedFloat32Array, legs: int, route: PackedVector2Array, actions: PackedInt32Array, skip := -1, seen_ok := false) -> Play:
	var play := Play.new()
	play.seen_ok = seen_ok
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
		play.tap_rooms.append(_game.run.room if _game.run != null else 0)
		if leg == skip:
			continue
		var done := await _act(room, route[leg], _action(actions, leg))
		if not done:
			print("bot: leg %d (%s) was refused by the room" % [leg, _leg_name(route, actions, leg)])
			play.failed_leg = leg
			break
		var settled := await _settle(room, play)
		if not settled:
			play.failed_leg = leg
			break
		room = current_scene as Room
	if room != null:
		play.escaped = room.finished
		play.stars = room.stars
		play.time = room.elapsed
		play.seen = play.seen or room.ever_seen
		play.has_sketch = room.run.has_sketch
		play.challenges = room.challenges
	play.trail = _trail
	_game.run = null
	return play


## Whether the run is already lost: caught, or seen unless `play.seen_ok`.
func _spoiled(room: Room, play: Play) -> bool:
	play.seen = play.seen or room.ever_seen
	play.caught = play.caught or room.catches > 0
	return (play.seen and not play.seen_ok) or play.caught


## The action of tap `leg` (WingData.BotAction): a plain TAP when `actions` is empty.
func _action(actions: PackedInt32Array, leg: int) -> int:
	return actions[leg] if not actions.is_empty() else WingData.BotAction.TAP


## Does a tap at `at` as `action` (WingData.BotAction) says; false when the room refused it
## (a power it does not have, spent, out of reach or not on a frame; a dash that does not run).
func _act(room: Room, at: Vector2, action: int) -> bool:
	var power := Content.power_of(action)
	if power >= 0:
		room.power_bar.picked.emit(power)
		if power == Powers.Power.BOX:
			await _tick()
			return room.box != null
		await _tap(at)
		return room.powers_spent[power]
	await _tap(at)
	if action == WingData.BotAction.DASH:
		await _tap(at)
		return room.mime.dashing
	return true


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
		var busy := room.mime.walking or _ball_flying(room) or room.swap_intent or room.paint_intent or room.hide_target != null or room.tilt_target != null or room.sketch_intent or canvas.visible or room.tossing
		if not busy and not _game.is_transitioning():
			return true
		await _tick(room)
	return false


## Whether a thrown ball is still in the air (it is heard as it lands).
func _ball_flying(room: Room) -> bool:
	for child in room.get_children():
		var fx := child as PowerFx
		if fx != null and fx.kind == PowerFx.Kind.BALL and fx.age < PowerFx.BALL_FLIGHT:
			return true
	return false


## Waits for the room after `from` (null: the first) to be current and ready.
func _next_room(from: Room) -> Room:
	for frame in 300:
		var room := current_scene as Room
		if room != null and room != from and room.is_node_ready() and not _game.is_transitioning():
			return room
		await physics_frame
	return null


## One physics frame (with --fixed-fps 60 a frame is one physics tick), sampling the
## trail every TRAIL_GAP frames while a room runs, painting included.
func _tick(_room: Room = null) -> void:
	var room := current_scene as Room
	if room != null and not _game.is_transitioning():
		_trail_wait -= 1
		if _trail_wait <= 0:
			_trail_wait = TRAIL_GAP
			_trail.append([_game.run.room if _game.run != null else 0, roundi(room.mime.position.x), roundi(room.mime.position.y), room.is_hidden()])
	await physics_frame


## Traces every remaining ghost exactly (a dab is a tap), PAINT_PACE before each stroke;
## stops if the canvas closes (a catch).
func _paint(canvas: ForgeryCanvas) -> void:
	var origin := (canvas.get_node("Pad") as Control).get_global_rect().position
	for i in range(canvas.traced.size(), canvas.ghosts.size()):
		for frame in roundi(PAINT_PACE * 60.0):
			await _tick()
			if not canvas.visible:
				return
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
	await _tick()
	for i in range(1, points.size()):
		var drag := InputEventScreenDrag.new()
		drag.index = TOUCH_INDEX
		drag.position = root.get_final_transform() * points[i]
		drag.relative = (points[i] - points[i - 1]) * root.get_final_transform().get_scale()
		Input.parse_input_event(drag)
		await _tick()
	var release := InputEventScreenTouch.new()
	release.index = TOUCH_INDEX
	release.position = root.get_final_transform() * points[points.size() - 1]
	Input.parse_input_event(release)
	await _tick()


## Tap `leg` of `route` as a name for the log: its action and point.
func _leg_name(route: PackedVector2Array, actions: PackedInt32Array, leg: int) -> String:
	if leg < 0 or leg >= route.size():
		return "none"
	return "%s at %s" % [String(WingData.BotAction.keys()[_action(actions, leg)]).to_lower(), route[leg]]
