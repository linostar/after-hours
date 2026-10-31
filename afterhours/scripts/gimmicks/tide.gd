class_name Tide
extends Gimmick
## Wing 2 (Hokusai): the sea comes in. The waterline rises from the front of the floor
## (dry_y, low tide) towards the back (flood_y, high tide) and falls back in a steady
## rhythm (period). On wet floor the mime wades (SLOW of its speed) and every step splashes
## (LOUD: heard across the whole hearing range). Drawn as Prussian-blue water with a foam
## edge that curls like the print's claws.

const SLOW := 0.55
const LOUD := 1.0
const WATER := Color(0.12, 0.3, 0.62, 0.55)
const FOAM := Color(0.95, 0.93, 0.85, 0.8)
const FLOOR_BOTTOM := 540.0
## The foam edge: its point spacing, wave height and ripple speed.
const FOAM_STEP := 16.0
const FOAM_HEIGHT := 4.0
const FOAM_SPEED := 2.0

@export var dry_y := 520.0
@export var flood_y := 300.0
@export var period := 10.0
## Where in its rhythm the tide starts (0 low, 0.5 high).
@export var phase := 0.0

var _time := 0.0


## The waterline's y now: floor below it is wet.
func waterline() -> float:
	return lerpf(dry_y, flood_y, (1.0 - cos(TAU * (_time / period + phase))) / 2.0)


func slow_at(point: Vector2) -> float:
	return SLOW if point.y > waterline() else 1.0


func noise_at(point: Vector2) -> float:
	return LOUD if point.y > waterline() else 0.0


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var line := waterline()
	draw_rect(Rect2(0.0, line, 960.0, FLOOR_BOTTOM - line), WATER)
	var foam := PackedVector2Array()
	var x := 0.0
	while x <= 960.0:
		foam.append(Vector2(x, line + sin(x * 0.05 + _time * FOAM_SPEED) * FOAM_HEIGHT))
		x += FOAM_STEP
	draw_polyline(foam, FOAM, 3.0, true)
