class_name Room
extends Node2D
## The vertical slice's gallery room, seen 3/4 top-down: the back wall across the top, a
## parquet floor, a freestanding display partition the mime walks around (its navmesh
## leaves the partition's footprint out) and the guards cannot see through. A tap on the
## floor walks the mime there. A guard that catches the mime shakes it and tosses it back
## through the entrance (TOSS_SHAKE, then TOSS_FLIGHT along an arc TOSS_HEIGHT high); taps
## are ignored meanwhile, then the guard starts its route again. The timer (elapsed) keeps
## running through it all; ever_seen records whether any guard ever spotted the mime.

## Where the mime enters the room (the door in the left wall), in room coordinates.
const ENTRANCE := Vector2(70, 330)
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

@onready var mime: Mime = $Actors/Mime
@onready var guard: Guard = $Actors/Guard
@onready var _floor: FloorInput = $FloorInput


func _ready() -> void:
	mime.place_at(ENTRANCE)
	guard.target = mime
	guard.reset()
	guard.spotted.connect(_on_spotted)
	guard.caught.connect(_on_caught)
	_floor.tapped.connect(_on_floor_tapped)
	(get_node(GameState.AUTOLOAD_PATH) as GameState).arrive(GameState.Flow.ROOM)


func _physics_process(delta: float) -> void:
	elapsed += delta


func _on_floor_tapped(at: Vector2) -> void:
	if tossing:
		return
	mime.walk_to(at)


func _on_spotted() -> void:
	ever_seen = true


func _on_caught() -> void:
	catches += 1
	tossing = true
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
