class_name HubDecor
extends Node2D
## The lobby's dressing, drawn over its walls and floor (under the doors and the actors): a
## crown moulding along the top, the wainscot's raised panels, a fluted pilaster between
## each pair of wing doors carrying a lit sconce (its flame flickering at FLICKER_HZ, held
## still under Reduce Motion), and the red carpet runner from the entrance to the back wall
## in the view's perspective, gold-bordered with medallions down its middle and a fringe at
## its foot.

const WALL_TOP := 0.0
const WAINSCOT := Rect2(0, 130, 960, 40)
const CROWN := 10.0
## The wing doors' x (Hub.FIRST_DOOR_X, Hub.DOOR_GAP): pilasters stand half a gap off them.
const PILLAR_WIDTH := 18.0
const SCONCE_Y := 92.0
const FLICKER_HZ := 0.7
## The runner: its foot (on the bottom edge) and head (at the back wall), each a centre and
## half width.
const RUNNER_FOOT := Vector2(480, 540)
const RUNNER_HEAD := Vector2(480, 176)
const RUNNER_FOOT_HALF := 70.0
const RUNNER_HEAD_HALF := 46.0
const MEDALLIONS := 4
const WALL_LIGHT := Color(0.3, 0.26, 0.38)
const WALL_DARK := Color(0.1, 0.08, 0.14)
const GILT := Color(0.79, 0.64, 0.29)
const GILT_DARK := Color(0.5, 0.38, 0.16)
const RED := Color(0.5, 0.11, 0.14)
const RED_DARK := Color(0.33, 0.06, 0.09)
const FLAME := Color(1.0, 0.82, 0.4)
const HALO := Color(1.0, 0.8, 0.45, 0.16)

## The wing doors' count and spacing, from the hub.
var doors := 6
var first_x := 120.0
var gap := 144.0
var _clock := 0.0


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	_draw_crown()
	_draw_wainscot()
	for i in doors - 1:
		_draw_pilaster(first_x + (i + 0.5) * gap)
	_draw_runner()


func _draw_crown() -> void:
	draw_rect(Rect2(0, WALL_TOP, 960, CROWN), GILT_DARK)
	draw_rect(Rect2(0, WALL_TOP + CROWN, 960, 3), GILT)
	for x in range(8, 960, 16):
		draw_rect(Rect2(x, WALL_TOP + 2, 6, CROWN - 4), GILT)


## Raised panels along the wainscot, a gilt rail on top.
func _draw_wainscot() -> void:
	draw_rect(Rect2(WAINSCOT.position.x, WAINSCOT.position.y - 3, WAINSCOT.size.x, 3), GILT)
	var panel := 56.0
	var x := 8.0
	while x + panel < WAINSCOT.end.x:
		var box := Rect2(x, WAINSCOT.position.y + 7, panel - 10, WAINSCOT.size.y - 14)
		draw_rect(box, WALL_LIGHT.darkened(0.35))
		draw_rect(box, WALL_DARK, false, 1.5)
		draw_line(box.position + Vector2(1, 1), Vector2(box.end.x - 1, box.position.y + 1), WALL_LIGHT, 1.0)
		x += panel


## A fluted pilaster from the crown to the wainscot, with a sconce on it.
func _draw_pilaster(x: float) -> void:
	var shaft := Rect2(x - PILLAR_WIDTH / 2.0, WALL_TOP + CROWN + 3, PILLAR_WIDTH, WAINSCOT.position.y - WALL_TOP - CROWN - 6)
	draw_rect(shaft, WALL_LIGHT)
	for k in 3:
		var fx := shaft.position.x + 4 + k * 5
		draw_line(Vector2(fx, shaft.position.y + 6), Vector2(fx, shaft.end.y - 6), WALL_DARK, 1.2)
	draw_rect(Rect2(shaft.position.x - 3, shaft.position.y, shaft.size.x + 6, 5), GILT_DARK)
	draw_rect(Rect2(shaft.position.x - 3, shaft.end.y - 5, shaft.size.x + 6, 5), GILT_DARK)
	# The sconce: a halo of light on the wall, a gilt bracket and cup, a candle and its flame.
	var flicker := 0.0 if GameState.reduce_motion_for(self) else sin(TAU * FLICKER_HZ * _clock + x * 0.05)
	var cup := Vector2(x, SCONCE_Y)
	draw_circle(cup + Vector2(0, -14), 26.0 + flicker * 1.5, HALO)
	draw_circle(cup + Vector2(0, -14), 14.0 + flicker, Color(HALO, HALO.a * 1.6))
	draw_polyline(PackedVector2Array([cup + Vector2(0, 14), cup + Vector2(-8, 8), cup + Vector2(-6, 2), cup]), GILT, 2.0, true)
	draw_rect(Rect2(cup.x - 7, cup.y - 2, 14, 4), GILT)
	draw_rect(Rect2(cup.x - 2, cup.y - 12, 4, 10), Color(0.95, 0.92, 0.82))
	var tip := cup + Vector2(flicker * 0.8, -20 - flicker)
	draw_colored_polygon(PackedVector2Array([cup + Vector2(-2.6, -12), tip, cup + Vector2(2.6, -12)]), FLAME)
	draw_circle(cup + Vector2(0, -13.5), 2.4, FLAME)


## The runner, narrowing toward the back wall: gold border, medallions, a fringe at its foot.
func _draw_runner() -> void:
	var outline := _runner(0.0)
	draw_colored_polygon(outline, RED)
	draw_polyline(_closed(_runner(6.0)), GILT, 2.0, true)
	draw_polyline(_closed(_runner(10.0)), GILT_DARK, 1.0, true)
	for i in MEDALLIONS:
		var t := (i + 0.5) / MEDALLIONS
		var centre := RUNNER_FOOT.lerp(RUNNER_HEAD, t)
		var half := lerpf(RUNNER_FOOT_HALF, RUNNER_HEAD_HALF, t)
		var squash := lerpf(0.55, 0.4, t)
		draw_set_transform(centre, 0.0, Vector2(1.0, squash))
		draw_circle(Vector2.ZERO, half * 0.45, RED_DARK)
		draw_arc(Vector2.ZERO, half * 0.45, 0.0, TAU, 24, GILT, 1.5 / squash, true)
		draw_arc(Vector2.ZERO, half * 0.25, 0.0, TAU, 16, GILT_DARK, 1.2 / squash, true)
		draw_set_transform(Vector2.ZERO)
	for k in 15:
		var x := RUNNER_FOOT.x - RUNNER_FOOT_HALF + 4 + k * (RUNNER_FOOT_HALF * 2 - 8) / 14.0
		draw_line(Vector2(x, RUNNER_FOOT.y - 4), Vector2(x, RUNNER_FOOT.y), GILT, 1.5)


## The runner's outline inset by `inset`.
func _runner(inset: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(RUNNER_FOOT.x - RUNNER_FOOT_HALF + inset, RUNNER_FOOT.y - inset),
		Vector2(RUNNER_HEAD.x - RUNNER_HEAD_HALF + inset, RUNNER_HEAD.y + inset),
		Vector2(RUNNER_HEAD.x + RUNNER_HEAD_HALF - inset, RUNNER_HEAD.y + inset),
		Vector2(RUNNER_FOOT.x + RUNNER_FOOT_HALF - inset, RUNNER_FOOT.y - inset),
	])


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	points.append(points[0])
	return points
