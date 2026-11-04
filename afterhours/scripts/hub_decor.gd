class_name HubDecor
extends Node2D
## The lobby's dressing, drawn over its walls and floor (under the doors and the actors): a
## crown moulding along the top, the wainscot's raised panels, a fluted pilaster between
## each pair of wing doors carrying a lit sconce (its flame flickering at FLICKER_HZ, held
## still under Reduce Motion), and the red carpet runner from the entrance to the back wall
## in the view's perspective, a woven museum carpet (see _draw_runner).

const WALL_TOP := 0.0
const WAINSCOT := Rect2(0, 130, 960, 40)
const CROWN := 10.0
## The wing doors' x (Hub.FIRST_DOOR_X, Hub.DOOR_GAP): pilasters stand half a gap off them.
const PILLAR_WIDTH := 18.0
const SCONCE_Y := 92.0
const FLICKER_HZ := 0.7
## The runner: its foot (its fringe hanging to the bottom edge) and head (at the back wall),
## each a centre and half width.
const RUNNER_FOOT := Vector2(480, 534)
const RUNNER_HEAD := Vector2(480, 176)
const RUNNER_FOOT_HALF := 70.0
const RUNNER_HEAD_HALF := 46.0
## How far a round motif on the runner is squashed in the view (as the floor's slabs are).
const RUNNER_SQUASH := 0.55
## The border's and the field's repeats, in half widths along the runner.
const RUNNER_WEAVE := 0.13
const RUNNER_SOWN := 0.3
## The shadow beside it on the floor (in half widths), and its fringe's threads.
const RUNNER_SHADOW := 0.06
const RUNNER_FRINGE := 36
const RUNNER_FRINGE_LENGTH := 6.0
const WALL_LIGHT := Color(0.3, 0.26, 0.38)
const WALL_DARK := Color(0.1, 0.08, 0.14)
const GILT := Color(0.79, 0.64, 0.29)
const GILT_DARK := Color(0.5, 0.38, 0.16)
const RED := Color(0.5, 0.11, 0.14)
const RED_DARK := Color(0.33, 0.06, 0.09)
const NAVY := Color(0.17, 0.12, 0.3)
const RUG_SHADE := Color(0.05, 0.02, 0.06, 0.45)
const FRINGE_THREAD := Color(0.88, 0.8, 0.6)
const FLAME := Color(1.0, 0.82, 0.4)
const HALO := Color(1.0, 0.8, 0.45, 0.16)

## The wing doors' count and spacing, from the hub.
var doors := 6
var first_x := 120.0
var gap := 144.0
var _clock := 0.0
## The runner, drawn once (the rest redraws each frame for the sconces' flicker).
var _rug: Node2D
## A step along the runner (s, 0..1) as long on the floor as a half width across.
var _along := RUNNER_SQUASH * RUNNER_HEAD_HALF / (RUNNER_FOOT.y - RUNNER_HEAD.y)


func _ready() -> void:
	_rug = Node2D.new()
	_rug.show_behind_parent = true
	_rug.draw.connect(_draw_runner)
	add_child(_rug)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	_draw_crown()
	_draw_wainscot()
	for i in doors - 1:
		_draw_pilaster(first_x + (i + 0.5) * gap)


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
	_rug.draw_colored_polygon(_runner_band(-1.0 - RUNNER_SHADOW, -1.0), Color(0, 0, 0, 0.3))
	_rug.draw_colored_polygon(_runner_band(1.0, 1.0 + RUNNER_SHADOW), Color(0, 0, 0, 0.3))
	_fill(0.0, NAVY.darkened(0.4))
	_fill(0.04, GILT_DARK)
	_fill(0.06, NAVY)
	_draw_border_weave()
	_fill(0.24, GILT)
	_fill(0.27, RED_DARK)
	_fill(0.29, RED)
	_draw_field()
	for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)]:
		_draw_spandrel(corner)
	_draw_medallion(0.5, 0.42, true)
	for s: float in [0.2, 0.8]:
		_draw_medallion(s, 0.22, false)
	# Shading: the pile darkens toward both edges and into the gloom at the back wall.
	var clear := Color(RUG_SHADE, 0.0)
	for side: float in [-1.0, 1.0]:
		var edge := PackedVector2Array([_on_runner(side, 0), _on_runner(side, 1), _on_runner(side * 0.45, 1), _on_runner(side * 0.45, 0)])
		_rug.draw_polygon(edge, PackedColorArray([RUG_SHADE, RUG_SHADE, clear, clear]))
	var back := PackedVector2Array([_on_runner(-1, 0.55), _on_runner(1, 0.55), _on_runner(1, 1), _on_runner(-1, 1)])
	var gloom := Color(RUG_SHADE, 0.3)
	_rug.draw_polygon(back, PackedColorArray([clear, clear, gloom, gloom]))
	# The fringe: knotted threads hanging off the foot onto the floor.
	for k in RUNNER_FRINGE:
		var u := lerpf(-0.95, 0.95, k / (RUNNER_FRINGE - 1.0))
		var knot := _on_runner(u, 0)
		var thread := FRINGE_THREAD if k % 2 == 0 else FRINGE_THREAD.darkened(0.15)
		_rug.draw_line(knot, knot + Vector2(u * 0.8, RUNNER_FRINGE_LENGTH), thread, 1.3, true)
		_rug.draw_circle(knot + Vector2(0, 0.8), 1.1, GILT_DARK)


## The runner's outline inset by `inset` half widths (as far along as across, on the floor).
func _runner_rect(inset: float) -> PackedVector2Array:
	var foot := inset * _along
	return PackedVector2Array([_on_runner(-1 + inset, foot), _on_runner(-1 + inset, 1 - foot), _on_runner(1 - inset, 1 - foot), _on_runner(1 - inset, foot)])


## A strip the runner's whole length, from `from` to `to` across.
func _runner_band(from: float, to: float) -> PackedVector2Array:
	return PackedVector2Array([_on_runner(from, 0), _on_runner(from, 1), _on_runner(to, 1), _on_runner(to, 0)])


func _fill(inset: float, color: Color) -> void:
	_rug.draw_colored_polygon(_runner_rect(inset), color)


## A point on the runner: `u` across (-1 its left edge, 1 its right), `s` along the floor (0
## its foot, 1 its head), foreshortened so equal steps of s shorten toward the back wall.
func _on_runner(u: float, s: float) -> Vector2:
	var depth := 1.0 + s * (RUNNER_FOOT_HALF / RUNNER_HEAD_HALF - 1.0)
	var near := (1.0 - 1.0 / depth) / (1.0 - RUNNER_HEAD_HALF / RUNNER_FOOT_HALF)
	return RUNNER_FOOT.lerp(RUNNER_HEAD, near) + Vector2(u * RUNNER_FOOT_HALF / depth, 0.0)


## A motif's outline (in half widths, round on the floor) laid on the runner at `at` (u, s).
func _on_rug(at: Vector2, local: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	for p in local:
		points.append(_on_runner(at.x + p.x, at.y + p.y * _along))
	return points


## A closed outline `radius` round with `sides` corners (4: a lozenge), stretched `long`
## times along the runner and scalloped `lobes` times by `scallop` of its radius.
func _motif(radius: float, sides: int, long := 1.0, lobes := 0, scallop := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in sides:
		var a := TAU * k / sides
		var r := radius * (1.0 + scallop * cos(lobes * a))
		points.append(Vector2(r * cos(a), r * sin(a) * long))
	return points


## The border, woven down both sides and across both ends: gilt lozenges with crimson
## hearts on a running chain, a gilt bead between each pair.
func _draw_border_weave() -> void:
	const MID := 0.85
	var ends := (1 - MID) * _along
	for side: float in [-MID, MID]:
		_rug.draw_line(_on_runner(side, ends), _on_runner(side, 1 - ends), GILT_DARK, 1.0, true)
	var steps := int((1 - 2 * ends) / (RUNNER_WEAVE * _along))
	for i in steps:
		var s := ends + (i + 0.5) * (1 - 2 * ends) / steps
		for side: float in [-MID, MID]:
			_weave_knot(Vector2(side, s), i, false)
	var across := int(2 * MID / RUNNER_WEAVE)
	for end: float in [ends, 1 - ends]:
		_rug.draw_line(_on_runner(-MID, end), _on_runner(MID, end), GILT_DARK, 1.0, true)
		for i in across:
			_weave_knot(Vector2(lerpf(-MID, MID, (i + 0.5) / across), end), i, true)


## The border's `i`th repeat at `at`: a lozenge (long the way the border runs) or a bead.
func _weave_knot(at: Vector2, i: int, across: bool) -> void:
	if i % 2 == 1:
		_rug.draw_colored_polygon(_on_rug(at, _motif(0.025, 8)), GILT)
		return
	var long := 0.55 if across else 1.9
	var size := 0.075 if across else 0.055
	_rug.draw_colored_polygon(_on_rug(at, _motif(size, 4, long)), GILT)
	_rug.draw_colored_polygon(_on_rug(at, _motif(size * 0.45, 4, long)), RED)


## The field: staggered rows of small dark lozenges, each with a gilt seed.
func _draw_field() -> void:
	var foot := 0.3 * _along
	var rows := int((1 - 2 * foot) / (RUNNER_SOWN * _along))
	for row in rows:
		var s := foot + (row + 0.5) * (1 - 2 * foot) / rows
		var offset := 0.0 if row % 2 == 0 else 0.5
		for col in range(-3, 3):
			var u := (col + offset) * 0.27
			if absf(u) > 0.62:
				continue
			_rug.draw_colored_polygon(_on_rug(Vector2(u, s), _motif(0.06, 4, 1.3)), RED_DARK)
			_rug.draw_colored_polygon(_on_rug(Vector2(u, s), _motif(0.018, 6)), GILT_DARK)


## A scalloped quarter medallion filling the field's corner at `corner` (u -1 or 1, s 0 or 1).
func _draw_spandrel(corner: Vector2) -> void:
	var at := Vector2(corner.x * 0.71, lerpf(0.29 * _along, 1 - 0.29 * _along, corner.y))
	var toward := Vector2(-corner.x, 1 - 2 * corner.y)
	var quarter := PackedVector2Array([Vector2.ZERO])
	for k in 13:
		var a := PI / 2.0 * k / 12.0
		quarter.append(Vector2(toward.x * cos(a), toward.y * sin(a)) * 0.34 * (1.0 + 0.08 * cos(a * 8.0)))
	var shape := _on_rug(at, quarter)
	_rug.draw_colored_polygon(shape, NAVY)
	shape.remove_at(0)
	_rug.draw_polyline(shape, GILT, 1.4, true)
	for k in 3:
		var a := PI / 2.0 * (k + 0.5) / 3.0
		var leaf := Vector2(toward.x * cos(a), toward.y * sin(a)) * 0.19
		_rug.draw_colored_polygon(_on_rug(at + Vector2(leaf.x, leaf.y * _along), _motif(0.045, 4, 1.6)), GILT_DARK)


## A scalloped medallion at `s` down the middle, `radius` across: an indigo rim edged in gilt
## round a crimson heart holding an eight-petalled gilt rosette; `pendants` caps it at both
## ends with gilt-rimmed lozenges.
func _draw_medallion(s: float, radius: float, pendants: bool) -> void:
	const LONG := 1.7
	var at := Vector2(0.0, s)
	if pendants:
		for end: float in [-1.0, 1.0]:
			var cap := at + Vector2(0.0, end * radius * (LONG + 0.65) * _along)
			_rug.draw_colored_polygon(_on_rug(cap, _motif(0.11, 4, 1.9)), GILT_DARK)
			_rug.draw_colored_polygon(_on_rug(cap, _motif(0.07, 4, 1.9)), NAVY)
			_rug.draw_colored_polygon(_on_rug(cap, _motif(0.025, 8)), GILT)
	var rim := _on_rug(at, _motif(radius, 48, LONG, 12, 0.07))
	_rug.draw_colored_polygon(rim, NAVY)
	_rug.draw_polyline(_closed(rim), GILT, 1.6, true)
	var heart := _on_rug(at, _motif(radius * 0.7, 32, LONG))
	_rug.draw_colored_polygon(heart, RED)
	_rug.draw_polyline(_closed(heart), GILT_DARK, 1.0, true)
	for k in 8:
		var a := TAU * k / 8.0
		var petal := PackedVector2Array()
		# Out from the centre (t -8) to the tip (t 0) and back, widest halfway.
		for t in range(-7, 9):
			var bulge := sin(PI * absf(t) / 8.0) * 0.32 * signf(t)
			var reach := radius * 0.55 * (8 - absf(t)) / 8.0
			petal.append(Vector2(cos(a + bulge), sin(a + bulge) * LONG) * reach)
		_rug.draw_colored_polygon(_on_rug(at, petal), GILT)
	_rug.draw_colored_polygon(_on_rug(at, _motif(radius * 0.14, 12, LONG)), NAVY)
	_rug.draw_colored_polygon(_on_rug(at, _motif(radius * 0.06, 8, LONG)), GILT)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	points.append(points[0])
	return points
