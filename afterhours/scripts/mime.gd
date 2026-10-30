class_name Mime
extends Node2D
## The player's mime: walks a navmesh path (NavigationAgent2D) to wherever the room sends
## it, at SPEED. Its origin is its feet, so the room y-sorts it with the guards and props.
## While swapping it draws a ring beside its head (clear of the painting above it) that
## fills (swap_progress 0..1); while carrying the original, the little framed painting
## shows at its side.

## Walking speed in base units per second.
const SPEED := 170.0
const RING_CENTER := Vector2(34, -84)
const RING_RADIUS := 14.0
const RING_TRACK := Color(0.1, 0.08, 0.13, 0.7)
const RING_FILL := Color(0.95, 0.85, 0.4)

## Emitted once when the mime reaches the end of its path.
signal arrived(at: Vector2)

var walking := false
var swap_progress := 0.0:
	set(value):
		swap_progress = value
		queue_redraw()
var carrying := false:
	set(value):
		carrying = value
		if is_node_ready():
			_carried.visible = value

@onready var _agent: NavigationAgent2D = $Agent
@onready var _carried: Sprite2D = $Carried


func _ready() -> void:
	_carried.visible = carrying


## Walks to the navmesh point closest to `point`.
func walk_to(point: Vector2) -> void:
	_agent.target_position = point
	walking = true
	print("[Mime] Walking from %s to %s" % [position.round(), point.round()])


## Stops at once and stands at `point` (a reset, a toss).
func place_at(point: Vector2) -> void:
	position = point
	_agent.target_position = point
	walking = false


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
