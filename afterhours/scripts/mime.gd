class_name Mime
extends Node2D
## The player's mime: walks a navmesh path (NavigationAgent2D) to wherever the room sends
## it, at SPEED (times the room gimmick's slow_at where it stands). Its origin is its feet, so
## the room y-sorts it with the guards and props. Drawn by its CharacterRig: it faces the way
## it moves (a path walk or a keyboard nudge; face and face_toward turn it toward what it
## uses) and keeps its last facing standing still; the rig's high-stepping walk cycle runs on
## the distance moved, and every footfall is a quiet tiptoe (not on noisy floor, where the
## room plays the gimmick's loud step).
## While swapping it draws a ring beside its head (clear of the painting above it) that
## fills (swap_progress 0..1); while it carries the fake (paler, unframed-looking) or the
## original, the little painting shows at its side.

## Walking speed in base units per second.
const SPEED := 170.0
const RING_CENTER := Vector2(34, -84)
const RING_RADIUS := 14.0
const RING_TRACK := Color(0.1, 0.08, 0.13, 0.7)
const RING_FILL := Color(0.95, 0.85, 0.4)
## A shrug (E with nothing in reach): the drawing sinks and widens to SHRUG_SCALE and back,
## twice, over SHRUG_TIME.
const SHRUG_SCALE := Vector2(1.14, 0.88)
const SHRUG_TIME := 0.4
## The carried painting's tint while it is the fake.
const FAKE_TINT := Color(1.0, 0.95, 0.85, 0.75)

## Emitted once when the mime reaches the end of its path.
signal arrived(at: Vector2)

var walking := false
## Busy using something (painting, swapping, tossed): it stands without the idle gag.
var busy := false
## The room's gimmick (null for none): how fast it walks where it stands.
var gimmick: Gimmick
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
## The room's masterpiece (a Paintings id), shown small as the carried original or fake.
var painting := "starry_night":
	set(value):
		painting = value
		if is_node_ready():
			_carried.painting = value

@onready var _carried: FramedPainting = $Carried
@onready var rig: CharacterRig = $Rig
var _tiptoes := 0
## Distance moved this physics frame (path walk and nudges), and whether a nudge moved it.
var _moved := 0.0
var _nudged := false
var _shrug: Tween


func _ready() -> void:
	_carried.painting = painting
	_sync_carried()
	rig.stepped.connect(_on_step)
	rig.gag_started.connect(_on_gag)


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
	var step := position + direction * speed() * delta
	if not NavigationServer2D.map_get_closest_point_owner(map, step).is_valid():
		return
	var to := NavigationServer2D.map_get_closest_point(map, step)
	_moved += position.distance_to(to)
	_nudged = true
	face(direction)
	position = to
	_agent.target_position = position


## Walking speed where it stands: SPEED, slowed by the gimmick.
func speed() -> float:
	return SPEED * (gimmick.slow_at(position) if gimmick != null else 1.0)


## Stops at once and stands at `point` (a reset, a toss).
func place_at(point: Vector2) -> void:
	position = point
	_agent.target_position = point
	walking = false


## Turns toward `heading` (the rig picks its view); a zero heading keeps the facing.
func face(heading: Vector2) -> void:
	rig.face(heading)


## Turns toward `point` (what it is about to use).
func face_toward(point: Vector2) -> void:
	face(point - position)


## Shrugs with a sound: E found nothing in reach to use.
func shrug() -> void:
	if _shrug != null:
		_shrug.kill()
	_shrug = create_tween()
	for i in 2:
		_shrug.tween_property(rig, "squash", SHRUG_SCALE, SHRUG_TIME / 4.0)
		_shrug.tween_property(rig, "squash", Vector2.ONE, SHRUG_TIME / 4.0)
	Audio.play_for(self, &"shrug")
	print("[Mime] Shrugged: nothing in reach")


func _sync_carried() -> void:
	_carried.visible = carrying or has_fake
	_carried.modulate = Color.WHITE if carrying else FAKE_TINT


# The room nudges the mime from its own _physics_process, which runs before this one (the
# room is an ancestor), so a frame's nudges are counted here with the path walk.
func _physics_process(delta: float) -> void:
	if walking:
		if _agent.is_navigation_finished():
			walking = false
			print("[Mime] Arrived at %s" % position.round())
			arrived.emit(position)
		else:
			var next := _agent.get_next_path_position()
			var to := position.move_toward(next, speed() * delta)
			_moved += position.distance_to(to)
			face(to - position)
			position = to
	rig.walk(_moved, delta, not busy)
	_moved = 0.0
	_nudged = false


## A footfall: a quiet tiptoe (pitched up and down in turn), or on noisy floor the floor's
## sound for a keyboard step (a path walk's loud step is the room's, with the noise guards hear).
func _on_step() -> void:
	if gimmick != null and gimmick.noise_at(position) > 0.0:
		if _nudged:
			Audio.play_for(self, gimmick.noise_sound(position))
		return
	_tiptoes += 1
	Audio.play_for(self, &"tiptoe", 0.92 if _tiptoes % 2 == 0 else 1.08)


## Stood idle long enough: the invisible wall, with its squeak of palms on glass.
func _on_gag() -> void:
	Audio.play_for(self, &"mime_gag")
	print("[Mime] Idle: the invisible wall")


func _draw() -> void:
	if swap_progress <= 0.0:
		return
	draw_circle(RING_CENTER, RING_RADIUS + 3.0, RING_TRACK)
	draw_arc(RING_CENTER, RING_RADIUS, -PI / 2.0, -PI / 2.0 + TAU * swap_progress, 32, RING_FILL, 5.0, true)
