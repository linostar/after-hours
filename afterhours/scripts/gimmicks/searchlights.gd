class_name Searchlights
extends Gimmick
## Wing 4 (Van Gogh): a starry night inside the museum. Pools of light circle slowly over the
## floor, each on its own orbit like the painting's swirls (orbits: centre x, y and orbit
## radius; neighbours turn opposite ways). Outside them the room is night (NIGHT: guards are
## slow to notice the mime); in a pool the mime is lit (LIT) and revealed: the first active
## guard within hearing range to look is shown where it stands (clue_seen_by), once each
## time it steps in.
## Drawn as the night over the floor, still stars on the back wall and the swirling pools.

const SPOT_RADIUS := 55.0
const LIT := 2.5
const NIGHT := 0.5
const NIGHT_TINT := Color(0.04, 0.06, 0.2, 0.35)
const POOL := Color(1.0, 0.9, 0.4, 0.45)
const STAR := Color(1.0, 0.95, 0.7, 0.85)
## Stars painted on the back wall (still: nothing twinkles).
const STARS := 22
const SWIRL := Color(1.0, 0.95, 0.6, 0.55)
const FLOOR_TOP := 172.0

@export var orbits: PackedVector3Array = PackedVector3Array()
## Seconds for one turn of every orbit.
@export var period := 9.0

var _time := 0.0
## The stars, on the wall behind the paintings (drawn once).
var _sky: Node2D
## Whether the mime has already been revealed in the pool it stands in.
var _revealed := false


func _ready() -> void:
	_sky = Node2D.new()
	_sky.z_as_relative = false
	_sky.z_index = -10
	_sky.draw.connect(_draw_sky)
	add_child(_sky)


func _draw_sky() -> void:
	var stars := RandomNumberGenerator.new()
	stars.seed = 1889
	for i in STARS:
		_sky.draw_circle(Vector2(stars.randf_range(10.0, 950.0), stars.randf_range(8.0, 120.0)), stars.randf_range(1.5, 3.5), STAR)


## Where each pool of light is now.
func spots() -> PackedVector2Array:
	var at := PackedVector2Array()
	for i in orbits.size():
		var turn := (1.0 if i % 2 == 0 else -1.0) * TAU * _time / period + float(i)
		at.append(Vector2(orbits[i].x, orbits[i].y) + Vector2(cos(turn), sin(turn)) * orbits[i].z)
	return at


func lit(point: Vector2) -> bool:
	for spot in spots():
		if point.distance_to(spot) <= SPOT_RADIUS:
			return true
	return false


func light_at(point: Vector2) -> float:
	return LIT if lit(point) else NIGHT


func clue_seen_by(guard: Guard) -> Vector2:
	if mime == null or not mime.visible or _revealed or not guard.active or not lit(mime.position):
		return Vector2.INF
	if guard.global_position.distance_to(mime.position) >= GuardBrain.HEARING_RANGE:
		return Vector2.INF
	_revealed = true
	return mime.position


func tick(delta: float) -> void:
	_time += delta
	if mime != null and not lit(mime.position):
		_revealed = false
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0.0, FLOOR_TOP, 960.0, 540.0 - FLOOR_TOP), NIGHT_TINT)
	var turn := TAU * _time / period
	for spot in spots():
		draw_circle(spot, SPOT_RADIUS, POOL)
		draw_arc(spot, SPOT_RADIUS * 0.6, turn, turn + PI * 1.2, 24, SWIRL, 3.0, true)
		draw_arc(spot, SPOT_RADIUS * 0.85, turn + PI, turn + PI * 1.9, 24, SWIRL, 2.0, true)
