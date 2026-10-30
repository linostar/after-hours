class_name Room
extends Node2D
## The vertical slice's gallery room, seen 3/4 top-down: the back wall across the top, a
## parquet floor, a freestanding display partition the mime walks around (its navmesh
## leaves the partition's footprint out) and the guards cannot see through. A tap on the
## floor walks the mime there; a tap on the masterpiece (PAINTING_RECT) walks it to
## SWAP_SPOT below it, where standing still for SWAP_TIME swaps the forgery for the
## original (tapping elsewhere cancels the swap). Carrying the original, the exit door
## glows, and reaching EXIT ends the wing: the stars (Stars, against PAR_TIME) show in the
## results overlay. A guard that catches the mime shakes it and tosses it back
## through the entrance (TOSS_SHAKE, then TOSS_FLIGHT along an arc TOSS_HEIGHT high); taps
## are ignored meanwhile, then the guard starts its route again. The timer (elapsed) keeps
## running through it all; ever_seen records whether any guard ever spotted the mime.

## Where the mime enters the room (the door in the left wall), in room coordinates.
const ENTRANCE := Vector2(70, 330)
## The masterpiece on the back wall (where a tap means "swap"), and where the mime stands
## to swap it.
const PAINTING_RECT := Rect2(720, 30, 120, 90)
const SWAP_SPOT := Vector2(780, 235)
## How close to SWAP_SPOT counts as standing there.
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
var finished := false
var stars: Array[bool] = []

@onready var mime: Mime = $Actors/Mime
@onready var guard: Guard = $Actors/Guard
@onready var _floor: FloorInput = $FloorInput
@onready var _exit_glow: Polygon2D = $ExitGlow
@onready var _results: Results = $ResultsLayer/Results


func _ready() -> void:
	mime.place_at(ENTRANCE)
	guard.target = mime
	guard.reset()
	guard.spotted.connect(_on_spotted)
	guard.caught.connect(_on_caught)
	_floor.tapped.connect(_on_floor_tapped)
	(get_node(GameState.AUTOLOAD_PATH) as GameState).arrive(GameState.Flow.ROOM)
	print("[Room] Masterpiece at %s, exit at %s" % [PAINTING_RECT, EXIT])


func _physics_process(delta: float) -> void:
	if finished:
		return
	elapsed += delta
	if swap_intent and not tossing and not mime.walking and mime.position.distance_to(SWAP_SPOT) <= SWAP_REACH:
		mime.swap_progress = minf(mime.swap_progress + delta / SWAP_TIME, 1.0)
		if mime.swap_progress >= 1.0:
			_swap()
	if mime.carrying and not tossing and mime.position.distance_to(EXIT) <= EXIT_REACH:
		_escape()


func _on_floor_tapped(at: Vector2) -> void:
	if tossing or finished:
		return
	_cancel_swap()
	if PAINTING_RECT.has_point(at) and not mime.carrying:
		swap_intent = true
		mime.walk_to(SWAP_SPOT)
		return
	mime.walk_to(at)


func _cancel_swap() -> void:
	if swap_intent and mime.swap_progress > 0.0:
		print("[Room] Swap cancelled at %d%%" % roundi(mime.swap_progress * 100.0))
	swap_intent = false
	mime.swap_progress = 0.0


func _swap() -> void:
	swap_intent = false
	mime.swap_progress = 0.0
	mime.carrying = true
	_exit_glow.visible = true
	print("[Room] Swapped the forgery for the original at t %.2f" % elapsed)


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
	tossing = false
	print("[Room] The mime is back at the entrance at t %.2f" % elapsed)
