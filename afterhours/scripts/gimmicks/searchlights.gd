class_name Searchlights
extends Gimmick
## Wing 4 (Van Gogh): a starry night inside the museum. Pools of light circle slowly over the
## floor, each on its own orbit like the painting's swirls (orbits: centre x, y and orbit
## radius; neighbours turn opposite ways). Outside them the room is night (NIGHT: guards are
## slow to notice the mime); in a pool the mime is lit (LIT) and revealed: the first active
## guard within hearing range to look is shown where it stands (clue_seen_by), once each
## time it steps in.
## Painted in Van Gogh's brushwork, short thick strokes following the flow: on the back
## wall (behind the paintings, drawn once) a night sky of swirling blue currents with haloed
## stars; over the floor (drawn once) the night's dark strokes; each pool a yellow glow of
## concentric stroke rings turning with its orbit (no faster: still under 2 Hz), its edge
## (exactly the lit radius) a bright ring of strokes.

const SPOT_RADIUS := 55.0
const LIT := 2.5
const NIGHT := 0.5
const NIGHT_TINT := Color(0.04, 0.06, 0.2, 0.35)
const POOL := Color(1.0, 0.86, 0.35, 0.3)
## The pool's stroke rings (share of the radius) and their colours, inside out.
const RINGS: Array[float] = [0.3, 0.55, 0.78, 1.0]
const RING_COLORS: Array[Color] = [Color(1.0, 0.98, 0.85, 0.85), Color(1.0, 0.85, 0.3, 0.75), Color(0.95, 0.65, 0.2, 0.7), Color(1.0, 0.9, 0.45, 0.9)]
const STAR := Color(1.0, 0.95, 0.7, 0.9)
const STAR_HALO: Array[Color] = [Color(0.95, 0.85, 0.35, 0.8), Color(0.75, 0.82, 0.95, 0.6)]
## Stars painted on the back wall (still: nothing twinkles), the first BIG_STARS haloed.
const STARS := 22
const BIG_STARS := 7
const SKY_STROKES: Array[Color] = [Color(0.35, 0.5, 0.85, 0.55), Color(0.2, 0.3, 0.65, 0.6), Color(0.55, 0.7, 0.95, 0.45), Color(0.12, 0.18, 0.45, 0.55)]
const NIGHT_STROKES: Array[Color] = [Color(0.08, 0.12, 0.35, 0.35), Color(0.15, 0.22, 0.5, 0.25), Color(0.05, 0.08, 0.22, 0.35)]
const GLOW := preload("res://art/glow.tres")
const WALL_TOP := 4.0
const WALL_BOTTOM := 124.0
const FLOOR_TOP := 172.0

@export var orbits: PackedVector3Array = PackedVector3Array()
## Seconds for one turn of every orbit.
@export var period := 9.0
## Whether it paints its starry sky on the back wall and its night strokes on the floor
## (off in the finale, whose Louvre dressing keeps its own walls).
@export var sky := true

var _time := 0.0
## The sky on the wall behind the paintings, and the night over the floor (drawn once).
var _sky: Node2D
var _night: Node2D
## Whether the mime has already been revealed in the pool it stands in.
var _revealed := false


func _ready() -> void:
	# The pools (drawn here) light the room's night at full brightness; the sky and the
	# night's strokes (layers of their own) stay in it.
	material = GLOW
	_sky = Node2D.new()
	_sky.z_as_relative = false
	_sky.z_index = -10
	_sky.draw.connect(_draw_sky)
	_sky.visible = sky
	add_child(_sky)
	_night = Node2D.new()
	_night.show_behind_parent = true
	_night.draw.connect(_draw_night)
	_night.visible = sky
	add_child(_night)


## The sky: wavy currents of short strokes flowing across the wall, curling into a swirl at
## a few places, then the stars, each big one in rings of yellow and blue strokes.
func _draw_sky() -> void:
	var brush := RandomNumberGenerator.new()
	brush.seed = 1889
	for row in 6:
		var y := lerpf(WALL_TOP + 10.0, WALL_BOTTOM - 8.0, row / 5.0)
		var x := brush.randf_range(-20.0, 0.0)
		while x < 960.0:
			var along := brush.randf_range(10.0, 18.0)
			var wave := sin(x / 70.0 + row * 1.7) * 7.0
			var next := sin((x + along) / 70.0 + row * 1.7) * 7.0
			_sky.draw_line(Vector2(x, y + wave), Vector2(x + along, y + next), SKY_STROKES[brush.randi() % SKY_STROKES.size()], brush.randf_range(2.0, 3.5), true)
			x += along + brush.randf_range(2.0, 6.0)
	for swirl in 3:
		var centre := Vector2(brush.randf_range(120.0, 840.0), brush.randf_range(40.0, 90.0))
		for k in 3:
			var turn := spiral(centre, 30.0 - k * 8.0, 8.0 - k * 2.0, brush.randf() * TAU, 4.5, 0.6, 18)
			for s in range(0, turn.size() - 1, 2):
				_sky.draw_line(turn[s], turn[s + 1], SKY_STROKES[(s + k) % SKY_STROKES.size()], 3.0, true)
	for i in STARS:
		var at := Vector2(brush.randf_range(10.0, 950.0), brush.randf_range(8.0, 120.0))
		var size := brush.randf_range(1.5, 3.5)
		if i < BIG_STARS:
			for ring in 2:
				var r := size * (2.6 + ring * 1.8)
				for k in 8:
					var a := TAU * k / 8.0 + ring * 0.4
					_sky.draw_arc(at, r, a, a + 0.5, 4, STAR_HALO[ring], 2.0, true)
		_sky.draw_circle(at, size, STAR)


## The night over the floor: a dark wash and short dark strokes flowing in slow waves.
func _draw_night() -> void:
	_night.draw_rect(Rect2(0.0, FLOOR_TOP, 960.0, 540.0 - FLOOR_TOP), NIGHT_TINT)
	var brush := RandomNumberGenerator.new()
	brush.seed = 1890
	for i in 420:
		var at := Vector2(brush.randf_range(0.0, 960.0), brush.randf_range(FLOOR_TOP + 4.0, 536.0))
		var flow := Vector2.from_angle(sin(at.x / 90.0 + at.y / 60.0) * 0.6) * brush.randf_range(6.0, 11.0)
		_night.draw_line(at, at + flow, NIGHT_STROKES[i % NIGHT_STROKES.size()], brush.randf_range(2.0, 3.0), true)


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
	Audio.play_for(self, &"searchlight")
	return mime.position


func tick(delta: float) -> void:
	_time += delta
	if mime != null and not lit(mime.position):
		_revealed = false
	queue_redraw()


## Each pool: a yellow glow, rings of short strokes turning with its orbit (each ring the
## other way round), a bright edge of strokes at the lit radius.
func _draw() -> void:
	var turn := TAU * _time / period
	for i in spots().size():
		var spot := spots()[i]
		draw_circle(spot, SPOT_RADIUS, POOL)
		draw_circle(spot, SPOT_RADIUS * 0.45, Color(POOL, 0.35))
		for ring in RINGS.size():
			var r := SPOT_RADIUS * RINGS[ring]
			var strokes := 5 + ring * 4
			var spin := turn * (1.0 if ring % 2 == 0 else -1.0) + ring * 0.7 + i
			for k in strokes:
				var a := spin + TAU * k / strokes
				# Each stroke curls inward a little along its length (a swirl, not a ring),
				# except on the edge, which stays at the lit radius.
				var inward := 0.0 if ring == RINGS.size() - 1 else r * 0.18
				var length := TAU / strokes * (0.55 + 0.25 * float((k * 7 + ring * 3) % 4) / 3.0)
				var stroke := spiral(spot, r, r - inward, a, length, 1.0, 6)
				draw_polyline(stroke, RING_COLORS[(ring + k % 2) % RING_COLORS.size()] if ring < RINGS.size() - 1 else RING_COLORS[ring], 3.5 if ring == RINGS.size() - 1 else 3.0, true)
		draw_circle(spot, 4.0, RING_COLORS[0])
