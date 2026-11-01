class_name Creatures
extends Gimmick
## Wing 5 (Bosch): the garden's creatures roam the museum. Each walks its own loop (loops:
## centre x, y and radius; an ellipse half as tall as wide, at its own pace); a step within
## REACH of one makes it squawk: a noise (LOUD share of the hearing range) the nearest guard
## comes to look at. Drawn as Bosch's beasts (a giant strawberry, a long-legged bird, a fish
## on legs) with a ring around any the mime is close enough to startle.

const REACH := 45.0
const LOUD := 0.8
## Seconds for one loop, the first creature; each next one is a little slower.
const BASE_PERIOD := 11.0
const PERIOD_STEP := 2.5
const STARTLED := Color(0.9, 0.25, 0.2, 0.7)
const STRAWBERRY := Color(0.85, 0.15, 0.2)
const SEED := Color(1.0, 0.9, 0.5)
const LEAF := Color(0.25, 0.55, 0.25)
const BIRD := Color(0.3, 0.45, 0.8)
const BEAK := Color(0.95, 0.6, 0.2)
const FISH := Color(0.6, 0.65, 0.7)
const LEG := Color(0.2, 0.15, 0.12)

@export var loops: PackedVector3Array = PackedVector3Array()

var _time := 0.0


## Where creature `i` is now.
func creature_at(i: int) -> Vector2:
	var turn := TAU * _time / (BASE_PERIOD + PERIOD_STEP * i) + float(i) * 2.0
	return Vector2(loops[i].x, loops[i].y) + Vector2(cos(turn), sin(turn) * 0.5) * loops[i].z


func noise_at(point: Vector2) -> float:
	for i in loops.size():
		if point.distance_to(creature_at(i)) <= REACH:
			return LOUD
	return 0.0


func noise_sound(_point: Vector2) -> StringName:
	return &"creature"


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	for i in loops.size():
		var at := creature_at(i)
		if mime != null and mime.visible and mime.position.distance_to(at) <= REACH:
			draw_arc(at + Vector2(0, -18), 30.0, 0.0, TAU, 32, STARTLED, 3.0, true)
		match i % 3:
			0:
				draw_circle(at + Vector2(0, -18), 16.0, STRAWBERRY)
				for seed_at: Vector2 in [Vector2(-6, -24), Vector2(5, -20), Vector2(-3, -12), Vector2(7, -29)]:
					draw_circle(at + seed_at, 1.8, SEED)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -32), at + Vector2(0, -40), at + Vector2(10, -32)]), LEAF)
			1:
				draw_line(at + Vector2(-5, 0), at + Vector2(-3, -20), LEG, 2.0)
				draw_line(at + Vector2(5, 0), at + Vector2(3, -20), LEG, 2.0)
				draw_circle(at + Vector2(0, -28), 12.0, BIRD)
				draw_circle(at + Vector2(9, -40), 6.0, BIRD)
				draw_colored_polygon(PackedVector2Array([at + Vector2(14, -42), at + Vector2(26, -39), at + Vector2(14, -37)]), BEAK)
			2:
				draw_line(at + Vector2(-6, 0), at + Vector2(-4, -12), LEG, 2.0)
				draw_line(at + Vector2(6, 0), at + Vector2(4, -12), LEG, 2.0)
				draw_colored_polygon(PackedVector2Array([at + Vector2(-18, -20), at + Vector2(0, -28), at + Vector2(16, -20), at + Vector2(0, -12)]), FISH)
				draw_colored_polygon(PackedVector2Array([at + Vector2(16, -20), at + Vector2(26, -28), at + Vector2(26, -12)]), FISH)
