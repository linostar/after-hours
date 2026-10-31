class_name Guard
extends Node2D
## A museum guard: walks its route (a closed loop of waypoints, pausing at each), looks
## ahead through a vision cone that walls cut short (rays against SIGHT_MASK), and fills
## its suspicion (Detection) while it sees its target. The cone is drawn on the floor and
## the suspicion as an eye above its head that fills and reddens; full suspicion stops the
## guard and emits caught (the room tosses the mime out and resets the guard).
## The room can stop it to inspect a point (inspect: it stands facing it for INSPECT_TIME,
## still looking, then emits inspected) and can raise its alarm (alarm: faster, a wider
## red cone, until the room ends; a reset keeps it).

const PATROL_SPEED := 70.0
const ALARM_SPEED := 110.0
const INSPECT_TIME := 1.2
## Seconds the guard stands at each waypoint, still facing the leg it walked, before it
## turns to the next one (it always faces the way it walks).
const WAYPOINT_PAUSE := 0.8
const CONE_RANGE := 180.0
## 32 degrees either side of the facing.
const CONE_HALF_ANGLE := PI * 32.0 / 180.0
## 45 degrees either side while alarmed.
const ALARM_HALF_ANGLE := PI * 45.0 / 180.0
## Rays in the drawn cone's fan (the floor polygon follows where walls cut them).
const CONE_RAYS := 24
## Physics layers that block sight (walls, partitions).
const SIGHT_MASK := 1
const CONE_COLOR := Color(1.0, 0.92, 0.55, 0.18)
const CONE_ALERT_COLOR := Color(1.0, 0.35, 0.25, 0.3)
## The suspicion eye, drawn above the head (guard-local).
const EYE_CENTER := Vector2(0, -116)
const EYE_SIZE := Vector2(22, 12)
const EYE_WHITE := Color(1.0, 0.98, 0.92)
const EYE_INK := Color(0.1, 0.08, 0.13)
const EYE_CALM := Color(0.95, 0.75, 0.2)
const EYE_ALARM := Color(0.85, 0.15, 0.12)

## Emitted when the guard starts seeing its target (suspicion leaves 0).
signal spotted
## Emitted once when suspicion is full.
signal caught
## Emitted when an inspection (inspect) has run its INSPECT_TIME.
signal inspected

## The patrol loop (room coordinates); the guard starts at its first point.
@export var route: PackedVector2Array
## Whom the guard looks for (set by the room).
var target: Node2D
## Whether it walks its route (tests stand it still).
var patrolling := true
## Whether it moves and looks at all (off from a catch until the room resets it).
var active := true
var facing := Vector2.RIGHT
var suspicion := 0.0
var inspecting := false
var alarmed := false
var _inspect_left := 0.0
var _next := 0
var _pause := 0.0

@onready var _cone: Polygon2D = $Cone


## Back to the start of the route, calm, facing its first leg. A route of fewer than 2
## points cannot be patrolled: reported (log and error badge), and the guard stands still.
func reset() -> void:
	suspicion = 0.0
	_pause = 0.0
	inspecting = false
	active = true
	if route.size() < 2:
		(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("Guard '%s' has a route of %d point(s) (%s); it needs at least 2 to patrol" % [get_path(), route.size(), route])
	if route.is_empty():
		return
	position = route[0]
	_next = 1 % route.size()
	if route.size() > 1 and not route[_next].is_equal_approx(route[0]):
		facing = (route[_next] - route[0]).normalized()
	_update_cone()
	queue_redraw()


## Stops to look at `point` (room coordinates) for INSPECT_TIME, then emits inspected.
func inspect(point: Vector2) -> void:
	inspecting = true
	_inspect_left = INSPECT_TIME
	if not point.is_equal_approx(position):
		facing = (point - position).normalized()
	print("[Guard] %s inspects %s" % [name, point.round()])


## From now until the room ends: faster, with a wider, red cone.
func alarm() -> void:
	alarmed = true
	print("[Guard] %s raises the alarm" % name)


func half_angle() -> float:
	return ALARM_HALF_ANGLE if alarmed else CONE_HALF_ANGLE


## Whether the guard sees `point` (global): inside its cone and no wall in between.
func can_see(point: Vector2) -> bool:
	if not Detection.in_cone(global_position, facing, point, CONE_RANGE, half_angle()):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, point, SIGHT_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if not active:
		return
	if inspecting:
		_inspect_left -= delta
		if _inspect_left <= 0.0:
			inspecting = false
			inspected.emit()
	elif patrolling:
		_patrol(delta)
	_look(delta)
	_update_cone()


func _patrol(delta: float) -> void:
	if route.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var goal := route[_next]
	# A zero step (two identical waypoints) keeps the old facing: a zero facing would see all round.
	if not position.is_equal_approx(goal):
		facing = (goal - position).normalized()
	position = position.move_toward(goal, (ALARM_SPEED if alarmed else PATROL_SPEED) * delta)
	if position.is_equal_approx(goal):
		position = goal
		print("[Guard] %s reaches waypoint %d at %s" % [name, _next, goal.round()])
		_next = (_next + 1) % route.size()
		_pause = WAYPOINT_PAUSE


func _look(delta: float) -> void:
	if target == null:
		return
	var seen := can_see(target.global_position)
	var before := suspicion
	suspicion = Detection.suspicion_after(suspicion, seen, global_position.distance_to(target.global_position), CONE_RANGE, delta)
	if before == 0.0 and suspicion > 0.0:
		print("[Guard] %s spots the mime at %s" % [name, target.global_position.round()])
		spotted.emit()
	if suspicion != before:
		queue_redraw()
	if Detection.is_full(suspicion):
		active = false
		print("[Guard] %s catches the mime at %s" % [name, target.global_position.round()])
		caught.emit()


## The floor fan: CONE_RAYS rays across the cone, each cut where a wall stops it.
func _update_cone() -> void:
	var space := get_world_2d().direct_space_state
	var points := PackedVector2Array([Vector2.ZERO])
	for i in CONE_RAYS + 1:
		var angle := facing.angle() - half_angle() + 2.0 * half_angle() * i / CONE_RAYS
		var end := global_position + Vector2.from_angle(angle) * CONE_RANGE
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, end, SIGHT_MASK))
		points.append(to_local(hit["position"] if not hit.is_empty() else end))
	_cone.polygon = points
	_cone.color = CONE_ALERT_COLOR if alarmed else CONE_COLOR.lerp(CONE_ALERT_COLOR, suspicion)


func _draw() -> void:
	if suspicion > 0.0:
		draw_eye(self, EYE_CENTER, suspicion)


## Draws the suspicion eye on `item` at `center`, `size_scale` times its size on a guard:
## an almond eye whose iris grows and reddens with `suspicion`.
static func draw_eye(item: CanvasItem, center: Vector2, eye_suspicion: float, size_scale := 1.0) -> void:
	var size := EYE_SIZE * size_scale
	var outline := PackedVector2Array()
	for i in 16:
		var t := TAU * i / 16.0
		outline.append(center + Vector2(cos(t) * size.x, sin(t) * size.y * (0.55 + 0.45 * absf(cos(t)))))
	item.draw_colored_polygon(outline, EYE_WHITE)
	item.draw_circle(center, lerpf(3.0, EYE_SIZE.y - 1.0, eye_suspicion) * size_scale, EYE_CALM.lerp(EYE_ALARM, eye_suspicion))
	item.draw_circle(center, 2.5 * size_scale, EYE_INK)
	outline.append(outline[0])
	item.draw_polyline(outline, EYE_INK, 2.0 * size_scale, true)
