class_name Mime
extends Node2D
## The player's mime: walks a navmesh path (NavigationAgent2D) to wherever the room sends
## it, at SPEED. Its origin is its feet, so the room y-sorts it with the guards and props.
## While swapping it draws a ring beside its head (clear of the painting above it) that
## fills (swap_progress 0..1); while it carries the fake (paler, unframed-looking) or the
## original, the little painting shows at its side.

## Walking speed in base units per second.
const SPEED := 170.0
const RING_CENTER := Vector2(34, -84)
const RING_RADIUS := 14.0
const RING_TRACK := Color(0.1, 0.08, 0.13, 0.7)
const RING_FILL := Color(0.95, 0.85, 0.4)
## The carried painting's tint while it is the fake.
const FAKE_TINT := Color(1.0, 0.95, 0.85, 0.75)

## Emitted once when the mime reaches the end of its path.
signal arrived(at: Vector2)

var walking := false
var swap_progress := 0.0:
	set(value):
		swap_progress = value
		queue_redraw()
## Carrying the original.
var carrying := false:
	set(value):
		carrying = value
		if is_node_ready():
			_sync_carried()
## Carrying a painted fake (to hang in the original's place).
var has_fake := false:
	set(value):
		has_fake = value
		if is_node_ready():
			_sync_carried()

@onready var _agent: NavigationAgent2D = $Agent
@onready var _carried: Sprite2D = $Carried


func _ready() -> void:
	_sync_carried()


## Walks to the navmesh point closest to `point`.
func walk_to(point: Vector2) -> void:
	_agent.target_position = point
	walking = true
	print("[Mime] Walking from %s to %s" % [position.round(), point.round()])


## Steps along `direction` (length at most 1) for `delta` seconds at SPEED, kept on the
## navmesh so it slides along walls (keyboard walking); a path walk stops. Until the
## map holds the room's navmesh (no region owns a closest point; its queries answer
## (0, 0) then) it stays put.
func nudge(direction: Vector2, delta: float) -> void:
	walking = false
	var map := _agent.get_navigation_map()
	var step := position + direction * SPEED * delta
	if not NavigationServer2D.map_get_closest_point_owner(map, step).is_valid():
		return
	position = NavigationServer2D.map_get_closest_point(map, step)
	_agent.target_position = position


## Stops at once and stands at `point` (a reset, a toss).
func place_at(point: Vector2) -> void:
	position = point
	_agent.target_position = point
	walking = false


func _sync_carried() -> void:
	_carried.visible = carrying or has_fake
	_carried.modulate = Color.WHITE if carrying else FAKE_TINT


func _physics_process(delta: float) -> void:
	if not walking:
		return
	if _agent.is_navigation_finished():
		walking = false
		print("[Mime] Arrived at %s" % position.round())
		arrived.emit(position)
		return
	var next := _agent.get_next_path_position()
	position = position.move_toward(next, SPEED * delta)


func _draw() -> void:
	if swap_progress <= 0.0:
		return
	draw_circle(RING_CENTER, RING_RADIUS + 3.0, RING_TRACK)
	draw_arc(RING_CENTER, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * swap_progress, 32, RING_FILL, 5.0, true)
