class_name Guard
extends Node2D
## A museum guard run by a GuardBrain. Each physics tick it senses (its target through a
## vision cone that walls cut short, rays against SIGHT_MASK; a hung fake to inspect),
## scores its intents and acts on the winner (logged when it changes):
## - PATROL: walks its route in straight legs (a closed loop of waypoints, pausing
##   WAYPOINT_PAUSE at each, facing the way it walks); after any excursion it first walks
##   the navmesh back to its next waypoint.
## - INSPECT: once per pass (re-armed when it no longer sees it), stands facing the hung
##   fake (fake_point, while watches_fake) for INSPECT_TIME, then emits inspected.
## - INVESTIGATE: walks to a noise it heard (hear, within GuardBrain.HEARING_RANGE) at
##   INVESTIGATE_SPEED and looks at where it came from.
## - STRAIGHTEN: a tilted frame it sees (one of frames) gets walked to and, after
##   STRAIGHTEN_TIME, straightened (which also settles a noise that came from it).
## - SEARCH: walks to search_point at SEARCH_SPEED and looks around for SEARCH_TIME.
## - CHASE: from full suspicion, runs at the mime at CHASE_SPEED (to where it last saw it
##   while it cannot see it); within CATCH_REACH it emits caught and stops until the room
##   resets it. Out of sight for CHASE_MEMORY, it searches the last-seen spot. A hidden
##   target (not visible) is never seen or caught, unless the guard saw it hide
##   (saw_hiding): then it chases to the hiding place and pulls it out, until the target
##   steps out again.
## The room's gimmick (Gimmick.light_at) scales how fast suspicion fills; in its shade the
## guard cannot see the mime. It walks the room's navmesh (Agent). The cone is drawn on the floor (red while it
## chases or searches), the suspicion as an eye above its head that fills and reddens, and
## the intent as an icon above that (INTENT_ICONS; none while patrolling) that pops in
## when the intent changes.

const PATROL_SPEED := 70.0
const SEARCH_SPEED := 100.0
const INVESTIGATE_SPEED := 90.0
const STRAIGHTEN_TIME := 1.0
## A noise this close to a frame it straightens is that frame's (no longer to investigate).
const NOISE_EXPLAINED := 40.0
## Below the mime's speed (Mime.SPEED): a mime that runs at once gets away.
const CHASE_SPEED := 150.0
## How close a chasing guard must get to catch the mime.
const CATCH_REACH := 28.0
const INSPECT_TIME := 1.2
const SEARCH_TIME := 4.0
## How fast a searching guard turns to look around (radians per second).
const SEARCH_TURN := 2.2
## A chase re-plans its path only once the mime has moved this far from the path's goal.
const CHASE_REPATH := 8.0
## Seconds the guard stands at each waypoint, still facing the leg it walked, before it
## turns to the next one (it always faces the way it walks).
const WAYPOINT_PAUSE := 0.8
const CONE_RANGE := 180.0
## 32 degrees either side of the facing.
const CONE_HALF_ANGLE := PI * 32.0 / 180.0
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
const INTENT_ICONS: Dictionary[GuardBrain.Intent, Texture2D] = {
	GuardBrain.Intent.INVESTIGATE: preload("res://art/svg/icon_ear.svg"),
	GuardBrain.Intent.STRAIGHTEN: preload("res://art/svg/icon_straighten.svg"),
	GuardBrain.Intent.INSPECT: preload("res://art/svg/icon_inspect.svg"),
	GuardBrain.Intent.SEARCH: preload("res://art/svg/icon_query.svg"),
	GuardBrain.Intent.CHASE: preload("res://art/svg/icon_alarm.svg"),
}
const ICON_SCALE := 0.6
const ICON_POP := 0.2

## Emitted when the guard starts seeing its target (suspicion leaves 0).
signal spotted
## Emitted once when a chase reaches the mime.
signal caught
## Emitted when an inspection of the hung fake has run its INSPECT_TIME.
signal inspected

## The patrol loop (room coordinates); the guard starts at its first point.
@export var route: PackedVector2Array
## Whom the guard looks for (set by the room).
var target: Node2D
## Whether it walks its route (tests stand it still; other intents still move it).
var patrolling := true
## Whether it moves and looks at all (off from a catch until the room resets it).
var active := true
var facing := Vector2.RIGHT
var suspicion := 0.0
## The hung fake's inspection point, while the room has it watched.
var watches_fake := false
var fake_point := Vector2.ZERO
var inspecting := false
## The room's gimmick (null for none): how lit the mime is where it stands, and how fast
## the guard itself walks where it stands (slow_at: it wades through water as the mime does).
var gimmick: Gimmick
## The room's tilt decoys, which it straightens when it sees them tilted.
var frames: Array[TiltFrame] = []
## Where the noise it is investigating came from.
var noise_point := Vector2.ZERO
var intent := GuardBrain.Intent.PATROL
var scores: Dictionary[GuardBrain.Intent, float] = {}
var senses := GuardBrain.Senses.new()
## Where it last saw its target, and where it searches.
var last_seen := Vector2.ZERO
var search_point := Vector2.ZERO
var _inspect_left := 0.0
var _fake_armed := true
## Whether it left its route and walks the navmesh back to it.
var _returning := false
var _straighten_frame: TiltFrame
## Whether it saw its target step into a hiding place (the chase does not lose it).
var _knows_hiding := false
var _straighten_left := 0.0
var _next := 0
var _pause := 0.0

@onready var _cone: Polygon2D = $Cone
@onready var _agent: NavigationAgent2D = $Agent
@onready var _icon: Sprite2D = $IntentIcon


## Back to the start of the route, calm, facing its first leg, its senses cleared. A
## route of fewer than 2 points cannot be patrolled: reported (log and error badge), and
## the guard stands still.
func reset() -> void:
	suspicion = 0.0
	_pause = 0.0
	inspecting = false
	_inspect_left = 0.0
	_fake_armed = true
	_returning = false
	_knows_hiding = false
	_straighten_frame = null
	_straighten_left = 0.0
	senses = GuardBrain.Senses.new()
	intent = GuardBrain.Intent.PATROL
	_show_intent()
	active = true
	if route.size() < 2:
		(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("Guard '%s' has a route of %d point(s) (%s); it needs at least 2 to patrol" % [get_path(), route.size(), route])
	if route.is_empty():
		return
	position = route[0]
	_agent.target_position = position
	_next = 1 % route.size()
	if route.size() > 1 and not route[_next].is_equal_approx(route[0]):
		facing = (route[_next] - route[0]).normalized()
	_update_cone()
	queue_redraw()


## Searches around `point` (room coordinates) for SEARCH_TIME.
func search(point: Vector2) -> void:
	search_point = point
	senses.search_left = SEARCH_TIME
	print("[Guard] %s searches around %s" % [name, point.round()])


## Saw its target step into a hiding place: it gives chase to it and pulls it out.
func saw_hiding() -> void:
	_knows_hiding = true
	senses.chasing = true
	senses.lost_sight_for = 0.0
	last_seen = target.global_position
	print("[Guard] %s saw the mime hide at %s" % [name, last_seen.round()])


## Hears a noise at `point` (room coordinates) if it is within HEARING_RANGE; returns
## whether it did.
func hear(point: Vector2) -> bool:
	var distance := global_position.distance_to(point)
	if distance >= GuardBrain.HEARING_RANGE:
		return false
	noise_point = point
	senses.noise_heard = true
	senses.noise_distance = distance
	print("[Guard] %s hears a noise at %s" % [name, point.round()])
	return true


## Whether the guard sees `point` (global): inside its cone and no wall in between.
func can_see(point: Vector2) -> bool:
	if not Detection.in_cone(global_position, facing, point, CONE_RANGE, CONE_HALF_ANGLE):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, point, SIGHT_MASK)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _physics_process(delta: float) -> void:
	if not active:
		return
	_look(delta)
	_sense_fake()
	_sense_frames()
	if senses.chasing and senses.lost_sight_for >= GuardBrain.CHASE_MEMORY and not Detection.is_full(suspicion):
		senses.chasing = false
		print("[Guard] %s loses the mime" % name)
		search(last_seen)
	scores = GuardBrain.scores(senses)
	var chosen := GuardBrain.choose(scores)
	if chosen != intent:
		_leave(intent)
		intent = chosen
		if intent == GuardBrain.Intent.STRAIGHTEN:
			_straighten_left = STRAIGHTEN_TIME
		_show_intent()
		print("[Guard] %s now %s" % [name, GuardBrain.Intent.keys()[intent]])
	match intent:
		GuardBrain.Intent.CHASE:
			_chase(delta)
		GuardBrain.Intent.SEARCH:
			_search(delta)
		GuardBrain.Intent.INSPECT:
			_inspect(delta)
		GuardBrain.Intent.INVESTIGATE:
			_investigate(delta)
		GuardBrain.Intent.STRAIGHTEN:
			_straighten(delta)
		GuardBrain.Intent.PATROL:
			_patrol(delta)
	_update_cone()


## The current path on the navmesh (room coordinates), for the debug overlay.
func nav_path() -> PackedVector2Array:
	return _agent.get_current_navigation_path()


## Pops in the icon of the current intent (none while patrolling).
func _show_intent() -> void:
	_icon.visible = INTENT_ICONS.has(intent)
	if not _icon.visible:
		return
	_icon.texture = INTENT_ICONS[intent]
	_icon.scale = Vector2.ZERO
	create_tween().tween_property(_icon, "scale", Vector2.ONE * ICON_SCALE, ICON_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Cleans up after `left`, which another intent has just replaced.
func _leave(left: GuardBrain.Intent) -> void:
	if left == GuardBrain.Intent.PATROL:
		_returning = true
	if left == GuardBrain.Intent.INSPECT and inspecting:
		# Cut short: it does not count, and the fake can be inspected again.
		inspecting = false
		_inspect_left = 0.0


## Walks the navmesh towards `goal` at `speed`, facing the way it walks; returns whether
## it has arrived (at the reachable point nearest `goal`).
func _travel(goal: Vector2, speed: float, delta: float) -> bool:
	# The agent stays "finished" until a target is submitted again, so a goal reached
	# before must be resubmitted once the guard has walked off (straight patrol legs move
	# it without the agent). Compared with where its last path ended, not with `goal`: a
	# goal off the navmesh is reached at its nearest point.
	var walked_off := _agent.is_navigation_finished() and position.distance_to(_agent.get_final_position()) > _agent.target_desired_distance
	if walked_off or not _agent.target_position.is_equal_approx(goal):
		_agent.target_position = goal
	if _agent.is_navigation_finished():
		return true
	var next := _agent.get_next_path_position()
	# A zero step keeps the old facing: a zero facing would see all round.
	if not next.is_equal_approx(position):
		facing = (next - position).normalized()
	position = position.move_toward(next, speed * _pace() * delta)
	return false


## The share of its speed the guard walks at where it stands (the gimmick's slow_at).
func _pace() -> float:
	return gimmick.slow_at(position) if gimmick != null else 1.0


func _patrol(delta: float) -> void:
	if not patrolling or route.size() < 2:
		return
	if _pause > 0.0:
		_pause -= delta
		return
	var goal := route[_next]
	if _returning:
		_returning = not _travel(goal, PATROL_SPEED, delta)
		return
	if not position.is_equal_approx(goal):
		facing = (goal - position).normalized()
	position = position.move_toward(goal, PATROL_SPEED * _pace() * delta)
	if position.is_equal_approx(goal):
		position = goal
		print("[Guard] %s reaches waypoint %d at %s" % [name, _next, goal.round()])
		_next = (_next + 1) % route.size()
		_pause = WAYPOINT_PAUSE


func _chase(delta: float) -> void:
	# Re-plan only when the mime has moved CHASE_REPATH from the path's goal (not every tick).
	var goal := last_seen if last_seen.distance_to(_agent.target_position) > CHASE_REPATH else _agent.target_position
	_travel(goal, CHASE_SPEED, delta)
	# A hidden target is caught only by a guard that saw it hide.
	if target != null and (target.visible or _knows_hiding) and global_position.distance_to(target.global_position) <= CATCH_REACH:
		active = false
		print("[Guard] %s catches the mime at %s" % [name, target.global_position.round()])
		caught.emit()


func _investigate(delta: float) -> void:
	if not _travel(noise_point, INVESTIGATE_SPEED, delta):
		return
	senses.noise_heard = false
	facing = (noise_point - position).normalized() if not noise_point.is_equal_approx(position) else Vector2.UP
	print("[Guard] %s investigated the noise at %s" % [name, noise_point.round()])


func _straighten(delta: float) -> void:
	if not _travel(_straighten_frame.view_point(), INVESTIGATE_SPEED, delta):
		_straighten_left = STRAIGHTEN_TIME
		return
	facing = Vector2.UP
	_straighten_left -= delta
	if _straighten_left > 0.0:
		return
	_straighten_frame.straighten()
	if senses.noise_heard and noise_point.distance_to(_straighten_frame.view_point()) < NOISE_EXPLAINED:
		senses.noise_heard = false
	print("[Guard] %s straightens the frame at %s" % [name, _straighten_frame.position.round()])
	_straighten_frame = null
	senses.tilted_frame_known = false


func _search(delta: float) -> void:
	if not _travel(search_point, SEARCH_SPEED, delta):
		return
	senses.search_left -= delta
	facing = facing.rotated(SEARCH_TURN * delta)
	if senses.search_left <= 0.0:
		print("[Guard] %s gives up the search" % name)


func _inspect(delta: float) -> void:
	if not inspecting:
		inspecting = true
		_inspect_left = INSPECT_TIME
		print("[Guard] %s inspects %s" % [name, fake_point.round()])
	if not fake_point.is_equal_approx(position):
		facing = (fake_point - position).normalized()
	_inspect_left -= delta
	if _inspect_left <= 0.0:
		inspecting = false
		_fake_armed = false
		inspected.emit()


## Whether a hung fake waits for this pass's inspection (re-armed once out of sight).
func _sense_fake() -> void:
	if not watches_fake:
		senses.fake_in_view = false
		return
	var sees := can_see(fake_point)
	if not sees and not inspecting:
		_fake_armed = true
	senses.fake_in_view = inspecting or (_fake_armed and sees)


## Keeps the tilted frame it means to straighten, or picks one it sees.
func _sense_frames() -> void:
	if _straighten_frame != null and not _straighten_frame.tilted:
		_straighten_frame = null
	if _straighten_frame == null:
		for frame in frames:
			if frame.tilted and can_see(frame.view_point()):
				_straighten_frame = frame
				print("[Guard] %s sees a tilted frame at %s" % [name, frame.position.round()])
				break
	senses.tilted_frame_known = _straighten_frame != null


func _look(delta: float) -> void:
	if target == null:
		return
	var light := gimmick.light_at(target.global_position) if gimmick != null else 1.0
	var seen := target.visible and light > 0.0 and can_see(target.global_position)
	var before := suspicion
	suspicion = Detection.suspicion_after(suspicion, seen, global_position.distance_to(target.global_position), CONE_RANGE, delta, light)
	senses.suspicion = suspicion
	if _knows_hiding and target.visible:
		# Out of its hiding place again: the chase can lose it like any other.
		_knows_hiding = false
	if seen:
		last_seen = target.global_position
		senses.lost_sight_for = 0.0
	elif senses.chasing and not _knows_hiding:
		senses.lost_sight_for += delta
	if before == 0.0 and suspicion > 0.0:
		print("[Guard] %s spots the mime at %s" % [name, target.global_position.round()])
		spotted.emit()
	if suspicion != before:
		queue_redraw()
	if Detection.is_full(suspicion) and not senses.chasing:
		senses.chasing = true
		senses.search_left = 0.0
		print("[Guard] %s gives chase at %s" % [name, target.global_position.round()])


## The floor fan: CONE_RAYS rays across the cone, each cut where a wall stops it.
func _update_cone() -> void:
	var space := get_world_2d().direct_space_state
	var points := PackedVector2Array([Vector2.ZERO])
	for i in CONE_RAYS + 1:
		var angle := facing.angle() - CONE_HALF_ANGLE + 2.0 * CONE_HALF_ANGLE * i / CONE_RAYS
		var end := global_position + Vector2.from_angle(angle) * CONE_RANGE
		var hit := space.intersect_ray(PhysicsRayQueryParameters2D.create(global_position, end, SIGHT_MASK))
		points.append(to_local(hit["position"] if not hit.is_empty() else end))
	_cone.polygon = points
	var alert := intent == GuardBrain.Intent.CHASE or intent == GuardBrain.Intent.SEARCH
	_cone.color = CONE_ALERT_COLOR if alert else CONE_COLOR.lerp(CONE_ALERT_COLOR, suspicion)


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
