class_name Room
extends Node2D
## The vertical slice's gallery room, seen 3/4 top-down: the back wall across the top, a
## parquet floor, a freestanding display partition the mime walks around (its navmesh
## leaves the partition's footprint out) and the guards cannot see through. A tap on the
## floor walks the mime there. A tap on the glowing easel (EASEL_RECT) walks it to
## EASEL_SPOT, where the forgery canvas opens over the still-running room; a painted fake
## puts the glow out (tapping the easel again repaints it). With a fake, a tap on the
## masterpiece (PAINTING_RECT) walks the mime to SWAP_SPOT below it, where standing still
## for SWAP_TIME swaps the fake for the original (tapping elsewhere cancels the swap); a
## tap there without one is a tap on the floor. Carrying the original, the exit door
## glows, and the fake hangs in the original's place: a guard who sees it (FAKE_VIEW_POINT,
## the floor at its foot) inspects it once per pass, a "?" over the painting; a fake
## found out (Forgery.is_noticed) turns the "?" into "!" and raises the guard's alarm until
## the room ends. Reaching EXIT ends the wing: the stars (Stars, against PAR_TIME) show in the
## results overlay. A guard that catches the mime shakes it and tosses it back
## through the entrance (TOSS_SHAKE, then TOSS_FLIGHT along an arc TOSS_HEIGHT high),
## closing the canvas if it was painting (its finished strokes are kept); taps are ignored
## meanwhile, then the guard starts its route again (a mime carrying the fake or the
## original keeps it: only the guard resets). The timer (elapsed) keeps running through
## it all, but not while a screen change fades (the player cannot act then); ever_seen
## records whether any guard ever spotted the mime.

## Where the mime enters the room (the door in the left wall), in room coordinates.
const ENTRANCE := Vector2(70, 330)
## The masterpiece on the back wall (where a tap means "swap"), and where the mime stands
## to swap it.
const PAINTING_RECT := Rect2(720, 30, 120, 90)
const SWAP_SPOT := Vector2(780, 235)
## The easel (the forgery kit, by the left wall, where the guard's cone sweeps past at the
## end of its bottom leg), and where the mime stands to paint.
const EASEL_RECT := Rect2(147, 260, 70, 110)
const EASEL_SPOT := Vector2(230, 372)
## Where a guard looks to inspect the hung fake: the floor at the painting's foot (sight
## rays to the painting itself would hit the back wall).
const FAKE_VIEW_POINT := Vector2(780, 180)
const QUERY_ICON := preload("res://art/svg/icon_query.svg")
const ALARM_ICON := preload("res://art/svg/icon_alarm.svg")
## How close to SWAP_SPOT (or EASEL_SPOT) counts as standing there.
const SWAP_REACH := 8.0
const SWAP_TIME := 1.5
## The exit (in front of the right-wall door) and how close counts as leaving.
const EXIT := Vector2(925, 330)
const EXIT_REACH := 24.0
## The par time for the third star, in seconds.
const PAR_TIME := 45.0
const TOSS_SHAKE := 0.45
const TOSS_FLIGHT := 0.8
const TOSS_HEIGHT := 120.0
## The mime's wobble while the guard shakes it (radians either way).
const SHAKE_ANGLE := 0.3

## Seconds since the room started (the wing timer: a toss does not stop it).
var elapsed := 0.0
var ever_seen := false
var catches := 0
var tossing := false
## Whether the mime is heading to (or standing at) the swap spot to swap.
var swap_intent := false
## Whether the mime is heading to the easel to paint.
var paint_intent := false
## The quality (Forgery) of the fake the mime carries, or of the one hung by the swap.
var fake_quality := 0.0
## Whether the swap has hung the fake, and how many inspections it has had.
var fake_hung := false
var inspections := 0
## Whether the guard's next sight of the fake starts an inspection (once per pass: it
## re-arms when the guard no longer sees it).
var _inspect_armed := true
var finished := false
var stars: Array[bool] = []

@onready var mime: Mime = $Actors/Mime
@onready var guard: Guard = $Actors/Guard
@onready var _floor: FloorInput = $FloorInput
@onready var _exit_glow: Polygon2D = $ExitGlow
@onready var _easel_glow: Polygon2D = $EaselGlow
@onready var _canvas: ForgeryCanvas = $EaselLayer/ForgeryCanvas
@onready var _fake_icon: Sprite2D = $FakeIcon
@onready var _results: Results = $ResultsLayer/Results
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	mime.place_at(ENTRANCE)
	guard.target = mime
	guard.reset()
	guard.spotted.connect(_on_spotted)
	guard.caught.connect(_on_caught)
	guard.inspected.connect(_on_inspected)
	_floor.tapped.connect(_on_floor_tapped)
	_canvas.watcher = guard
	_canvas.painted.connect(_on_painted)
	_game.arrive(GameState.Flow.ROOM)
	print("[Room] Masterpiece at %s, exit at %s" % [PAINTING_RECT, EXIT])
	print("[Room] Easel at %s" % EASEL_RECT)


func _physics_process(delta: float) -> void:
	if finished or _game.is_transitioning():
		return
	elapsed += delta
	if paint_intent and not tossing and not mime.walking and mime.position.distance_to(EASEL_SPOT) <= SWAP_REACH:
		paint_intent = false
		_canvas.open()
	if fake_hung and guard.active and not guard.inspecting and not guard.alarmed:
		var sees_fake := guard.can_see(FAKE_VIEW_POINT)
		if sees_fake and _inspect_armed:
			_start_inspection()
		elif not sees_fake:
			_inspect_armed = true
	if swap_intent and not tossing and not mime.walking and mime.position.distance_to(SWAP_SPOT) <= SWAP_REACH:
		mime.swap_progress = minf(mime.swap_progress + delta / SWAP_TIME, 1.0)
		if mime.swap_progress >= 1.0:
			_swap()
	if mime.carrying and not tossing and mime.position.distance_to(EXIT) <= EXIT_REACH:
		_escape()


func _on_floor_tapped(at: Vector2) -> void:
	if tossing or finished:
		return
	var on_painting := PAINTING_RECT.has_point(at) and mime.has_fake
	if on_painting and swap_intent:
		# Already heading there or swapping: a second tap keeps the progress.
		return
	_cancel_swap()
	paint_intent = false
	if EASEL_RECT.has_point(at) and not mime.carrying:
		paint_intent = true
		mime.walk_to(EASEL_SPOT)
		return
	if on_painting:
		swap_intent = true
		mime.walk_to(SWAP_SPOT)
		return
	mime.walk_to(at)


func _cancel_swap() -> void:
	if swap_intent and mime.swap_progress > 0.0:
		print("[Room] Swap cancelled at %d%%" % roundi(mime.swap_progress * 100.0))
	swap_intent = false
	mime.swap_progress = 0.0


func _on_painted(quality: float) -> void:
	fake_quality = quality
	mime.has_fake = true
	_easel_glow.visible = false
	print("[Room] Fake ready at t %.2f (quality %.2f, %s)" % [elapsed, quality, Forgery.Grade.keys()[Forgery.grade(quality)]])


func _swap() -> void:
	swap_intent = false
	mime.swap_progress = 0.0
	mime.has_fake = false
	mime.carrying = true
	fake_hung = true
	_exit_glow.visible = true
	print("[Room] Swapped the forgery for the original at t %.2f (fake %s)" % [elapsed, Forgery.Grade.keys()[Forgery.grade(fake_quality)]])


func _start_inspection() -> void:
	_inspect_armed = false
	inspections += 1
	_fake_icon.texture = QUERY_ICON
	_fake_icon.show()
	guard.inspect(FAKE_VIEW_POINT)


func _on_inspected() -> void:
	var fake_grade := Forgery.grade(fake_quality)
	var noticed := Forgery.is_noticed(fake_grade, inspections)
	print("[Room] Inspection %d of the %s fake at t %.2f: %s" % [inspections, Forgery.Grade.keys()[fake_grade], elapsed, "found out" if noticed else "passed"])
	if not noticed:
		_fake_icon.hide()
		return
	_fake_icon.texture = ALARM_ICON
	guard.alarm()


func _escape() -> void:
	finished = true
	guard.active = false
	mime.place_at(mime.position)
	stars = Stars.earned(ever_seen, elapsed, PAR_TIME)
	print("[Room] Escaped with the original at t %.2f (par %.0f, seen %s)" % [elapsed, PAR_TIME, ever_seen])
	_results.present(stars)


func _on_spotted() -> void:
	ever_seen = true


func _on_caught() -> void:
	catches += 1
	tossing = true
	_cancel_swap()
	paint_intent = false
	_canvas.close()
	if guard.inspecting:
		# A catch cuts the inspection short: it does not count.
		inspections -= 1
		_fake_icon.hide()
	var from := mime.position
	mime.place_at(from)
	print("[Room] Caught (%d) at t %.2f: tossing the mime from %s to the entrance" % [catches, elapsed, from.round()])
	var toss := create_tween()
	for angle: float in [SHAKE_ANGLE, -SHAKE_ANGLE, SHAKE_ANGLE, 0.0]:
		toss.tween_property(mime, "rotation", angle, TOSS_SHAKE / 4.0)
	toss.tween_method(_toss_step.bind(from), 0.0, 1.0, TOSS_FLIGHT)
	toss.finished.connect(_end_toss)


## The mime along the toss arc, `t` from 0 (where it was caught) to 1 (the entrance).
func _toss_step(t: float, from: Vector2) -> void:
	mime.position = from.lerp(ENTRANCE, t) + Vector2(0.0, -sin(t * PI) * TOSS_HEIGHT)
	mime.rotation = t * TAU


func _end_toss() -> void:
	mime.rotation = 0.0
	mime.place_at(ENTRANCE)
	guard.reset()
	_inspect_armed = true
	tossing = false
	print("[Room] The mime is back at the entrance at t %.2f" % elapsed)
