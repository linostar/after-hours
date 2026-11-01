class_name Footprints
extends Gimmick
## Wing 3 (Seurat): a sunny, dotted lawn under parasols. The mime's steps leave footprints
## in the dots (one every PRINT_GAP, fading after PRINT_LIFE; a catch wipes them): a guard
## that sees one goes to look at the newest it sees (clue_seen_by; older prints are then
## spent), and so follows the trail. Under a parasol it is shade (light 0: guards cannot see the mime) and the
## grass keeps no prints. Drawn as scattered paint dots, the parasols' shade and canopies,
## and the fading prints.

const PRINT_GAP := 26.0
## Short enough that a trail goes cold (14 s led guards to the mime again and again in the
## step 9 playtest).
const PRINT_LIFE := 6.0
const PRINT_COLOR := Color(0.18, 0.14, 0.1, 0.55)
const SHADE := Color(0.05, 0.08, 0.12, 0.35)
const POLE := Color(0.25, 0.2, 0.15)
const CANOPY_COLORS: Array[Color] = [Color(0.85, 0.35, 0.2), Color(0.25, 0.35, 0.7), Color(0.15, 0.13, 0.15)]
const DOT_COLORS: Array[Color] = [Color(0.95, 0.85, 0.35, 0.5), Color(0.35, 0.6, 0.3, 0.5), Color(0.55, 0.7, 0.95, 0.45), Color(0.9, 0.55, 0.3, 0.45)]
const DOTS := 260
const CANOPY_HEIGHT := 110.0

## The parasols: each x, y (where its pole stands) and its shade's radius on the floor.
@export var parasols: PackedVector3Array = PackedVector3Array()

## The prints: position (x, y) and age (z), oldest first.
var _prints: Array[Vector3] = []
var _last_print := Vector2.INF


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


func _draw() -> void:
	var dots := RandomNumberGenerator.new()
	dots.seed = 1884
	for i in DOTS:
		var at := Vector2(dots.randf_range(0.0, 960.0), dots.randf_range(176.0, 538.0))
		draw_circle(at, 2.5, DOT_COLORS[i % DOT_COLORS.size()])
	for parasol in parasols:
		draw_set_transform(Vector2(parasol.x, parasol.y), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, parasol.z, SHADE)
		draw_set_transform(Vector2.ZERO)
	for footprint in _prints:
		var fade := 1.0 - footprint.z / PRINT_LIFE
		var color := Color(PRINT_COLOR, PRINT_COLOR.a * fade)
		draw_circle(Vector2(footprint.x - 4.0, footprint.y), 3.0, color)
		draw_circle(Vector2(footprint.x + 4.0, footprint.y - 3.0), 3.0, color)
	for i in parasols.size():
		var foot := Vector2(parasols[i].x, parasols[i].y)
		var top := foot - Vector2(0.0, CANOPY_HEIGHT)
		draw_line(foot, top, POLE, 3.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-parasols[i].z * 0.8, 18.0), top + Vector2(0.0, -14.0), top + Vector2(parasols[i].z * 0.8, 18.0)]), CANOPY_COLORS[i % CANOPY_COLORS.size()])
