class_name Footprints
extends Gimmick
## Wing 3 (Seurat): a sunny, dotted lawn under parasols. The mime's steps leave footprints
## in the dots (one every PRINT_GAP, fading after PRINT_LIFE; a catch wipes them): a guard
## that sees one goes to look at the newest it sees (clue_seen_by; older prints are then
## spent), and so follows the trail. Under a parasol it is shade (light 0: guards cannot see the mime) and the
## grass keeps no prints. Painted in Seurat's pointillism, every part in dots of pure colour
## set beside their complements: the lawn (sunlit yellows and greens with orange and violet
## between), each parasol's shade (violets and blues, densest at its middle) and canopy
## (its colour lit along the top and shaded beneath, on a dark pole), and the prints, pairs
## of shoe-shaped dot clusters in umber that fade. The lawn, shade and canopies are drawn
## once; only the prints are redrawn. Nothing moves but the fade.

const PRINT_GAP := 26.0
## Short enough that a trail goes cold (14 s led guards to the mime again and again in the
## step 9 playtest).
const PRINT_LIFE := 6.0
const PRINT_COLORS: Array[Color] = [Color(0.3, 0.18, 0.1, 0.8), Color(0.42, 0.22, 0.28, 0.75), Color(0.2, 0.16, 0.24, 0.8)]
## A shoe print's dots (offsets from the foot, the toe up the screen) and the two feet's
## places either side of the step.
const SOLE_DOTS: Array[Vector2] = [Vector2(0, -6), Vector2(-1.6, -3.2), Vector2(1.6, -3.2), Vector2(0, -0.8), Vector2(-1.2, 2.2), Vector2(1.2, 2.2), Vector2(0, 4.6)]
const FEET: Array[Vector2] = [Vector2(-4.5, 1.5), Vector2(4.5, -2.0)]
const POLE := Color(0.18, 0.13, 0.1)
const CANOPY_COLORS: Array[Color] = [Color(0.88, 0.36, 0.2), Color(0.25, 0.38, 0.75), Color(0.2, 0.17, 0.22)]
## Each canopy's dots of light (the complement-warmed top) and of shade (underneath).
const CANOPY_LIGHTS: Array[Color] = [Color(1.0, 0.75, 0.35), Color(0.55, 0.75, 1.0), Color(0.55, 0.45, 0.6)]
const CANOPY_SHADES: Array[Color] = [Color(0.55, 0.15, 0.3), Color(0.14, 0.18, 0.42), Color(0.08, 0.08, 0.14)]
const LAWN_COLORS: Array[Color] = [
	Color(0.98, 0.88, 0.38, 0.7), Color(0.55, 0.78, 0.32, 0.65), Color(0.3, 0.55, 0.28, 0.6),
	Color(0.95, 0.6, 0.3, 0.55), Color(0.58, 0.72, 0.98, 0.5), Color(0.7, 0.5, 0.8, 0.45),
]
const SHADE_COLORS: Array[Color] = [Color(0.22, 0.2, 0.5, 0.65), Color(0.12, 0.25, 0.4, 0.6), Color(0.45, 0.25, 0.55, 0.5), Color(0.1, 0.3, 0.25, 0.55)]
const SHADE := Color(0.05, 0.08, 0.16, 0.22)
const LAWN_DOTS := 1100
## Dots per unit of a parasol's shade area, and per canopy.
const SHADE_DENSITY := 0.05
const CANOPY_DOTS := 150
const DOT_RADIUS := 1.7
const CANOPY_HEIGHT := 110.0
const FLOOR_TOP := 176.0

## The parasols: each x, y (where its pole stands) and its shade's radius on the floor.
@export var parasols: PackedVector3Array = PackedVector3Array()

## The prints: position (x, y) and age (z), oldest first.
var _prints: Array[Vector3] = []
var _last_print := Vector2.INF
## The still painting: the lawn and shade under the prints, the canopies over them.
var _lawn: Node2D
var _canopies: Node2D


func _ready() -> void:
	_lawn = Node2D.new()
	_lawn.show_behind_parent = true
	_lawn.draw.connect(_draw_lawn)
	add_child(_lawn)
	_canopies = Node2D.new()
	_canopies.draw.connect(_draw_canopies)
	add_child(_canopies)


func in_shade(point: Vector2) -> bool:
	for parasol in parasols:
		if point.distance_to(Vector2(parasol.x, parasol.y)) <= parasol.z:
			return true
	return false


func light_at(point: Vector2) -> float:
	return 0.0 if in_shade(point) else 1.0


## The newest print `guard` can see (spending it and every older one), or Vector2.INF.
func clue_seen_by(guard: Guard) -> Vector2:
	for i in range(_prints.size() - 1, -1, -1):
		var at := Vector2(_prints[i].x, _prints[i].y)
		if guard.can_see(at):
			_prints = _prints.slice(i + 1)
			return at
	return Vector2.INF


func forget() -> void:
	_prints.clear()
	_last_print = Vector2.INF
	queue_redraw()


func tick(delta: float) -> void:
	for i in _prints.size():
		_prints[i].z += delta
	while not _prints.is_empty() and _prints[0].z > PRINT_LIFE:
		_prints.pop_front()
	if mime != null and mime.visible and mime.walking and not in_shade(mime.position):
		if _last_print == Vector2.INF or mime.position.distance_to(_last_print) >= PRINT_GAP:
			_prints.append(Vector3(mime.position.x, mime.position.y, 0.0))
			_last_print = mime.position
	queue_redraw()


## The prints: two shoe-shaped clusters of umber dots each, fading with age.
func _draw() -> void:
	for footprint in _prints:
		var fade := 1.0 - footprint.z / PRINT_LIFE
		var at := Vector2(footprint.x, footprint.y)
		for foot in FEET:
			for k in SOLE_DOTS.size():
				var color := PRINT_COLORS[k % PRINT_COLORS.size()]
				draw_circle(at + foot + SOLE_DOTS[k], 1.5, Color(color, color.a * fade))


## The lawn in dots of sunlit colour, then each parasol's shade in cool dots, densest at its
## middle (seeded: the same painting every time).
func _draw_lawn() -> void:
	var dots := RandomNumberGenerator.new()
	dots.seed = 1884
	for i in LAWN_DOTS:
		var at := Vector2(dots.randf_range(0.0, 960.0), dots.randf_range(FLOOR_TOP, 538.0))
		_dab(_lawn, at, dots.randf_range(0.8, 1.2), LAWN_COLORS[i % LAWN_COLORS.size()])
	for parasol in parasols:
		var foot := Vector2(parasol.x, parasol.y)
		_lawn.draw_set_transform(foot, 0.0, Vector2(1.0, 0.45))
		_lawn.draw_circle(Vector2.ZERO, parasol.z, SHADE)
		_lawn.draw_set_transform(Vector2.ZERO)
		for i in int(PI * parasol.z * parasol.z * 0.45 * SHADE_DENSITY):
			var reach := sqrt(dots.randf()) * parasol.z
			var angle := dots.randf() * TAU
			_dab(_lawn, foot + Vector2(cos(angle), sin(angle) * 0.45) * reach, 1.0, SHADE_COLORS[i % SHADE_COLORS.size()])


## Each parasol: a dark pole with a finial, its canopy a scalloped dome of dots, lit on top
## and shaded underneath, under an outline of the canopy's colour.
func _draw_canopies() -> void:
	var dots := RandomNumberGenerator.new()
	dots.seed = 1886
	for i in parasols.size():
		var foot := Vector2(parasols[i].x, parasols[i].y)
		var top := foot - Vector2(0.0, CANOPY_HEIGHT)
		var reach := parasols[i].z * 0.8
		var color := CANOPY_COLORS[i % CANOPY_COLORS.size()]
		_canopies.draw_line(foot, top + Vector2(0, -16), POLE, 3.0, true)
		_canopies.draw_circle(top + Vector2(0, -18), 2.5, POLE)
		var dome := PackedVector2Array()
		for k in 17:
			var a := PI + PI * k / 16.0
			dome.append(top + Vector2(cos(a) * reach, sin(a) * 30.0 + 16.0))
		var scallops := 6
		# Back along the hem from the right edge to the left, dipping between the ribs.
		for k in range(1, scallops):
			var x := lerpf(reach, -reach, float(k) / scallops)
			dome.append(top + Vector2(x, 16.0 + (0.0 if k % 2 == 0 else 5.0)))
		_canopies.draw_colored_polygon(dome, Color(color, 0.9))
		for k in CANOPY_DOTS:
			var u := dots.randf()
			var a := PI + PI * dots.randf()
			var at := top + Vector2(cos(a) * reach, sin(a) * 30.0 + 16.0) * sqrt(u)
			var lit := at.y < top.y + 2.0
			var palette := CANOPY_LIGHTS if lit else CANOPY_SHADES
			_dab(_canopies, at, 0.9, palette[i % palette.size()] if k % 3 != 0 else color.lightened(0.15))
		dome.append(dome[0])
		_canopies.draw_polyline(dome, color.darkened(0.45), 1.5, true)


## A dot of paint at `at`, `size` times DOT_RADIUS, a touch wider than tall (a brush tip).
func _dab(canvas: CanvasItem, at: Vector2, size: float, color: Color) -> void:
	canvas.draw_set_transform(at, 0.0, Vector2(1.25, 1.0))
	canvas.draw_circle(Vector2.ZERO, DOT_RADIUS * size, color)
	canvas.draw_set_transform(Vector2.ZERO)
