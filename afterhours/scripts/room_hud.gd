class_name RoomHud
extends Node2D
## The room's wordless heads-up display, top left beside the pause button (inside the safe
## area with the world, clear of the forgery canvas on the right):
## - the par clock: a stopwatch face whose wedge fills clockwise from the gilt par mark at
##   twelve as the wing timer runs (full at the par time, clock_fill); past par the face warms
##   smoothly toward red over WARM_TIME (warmth), never flashing;
## - the objective strip: the brush (the fake painted), the swap (the original taken) and the
##   exit (escaped), dim until done, then gold with a tick, popping once as each is done
##   (goals; no pop under Reduce Motion);
## - the wing's sketch, once the mime has it on this play (no empty slot before: the secret
##   is not given away), popping in as it is picked up.
## The room sets `room`; the HUD reads its timer and the mime's state each frame and hides in
## a hideout replay. Drawn with the room's GLOW material, at full brightness against the night.

const CLOCK_CENTER := Vector2(96, 36)
const CLOCK_RADIUS := 20.0
const ICON_CENTERS: Array[Vector2] = [Vector2(144, 32), Vector2(180, 32), Vector2(216, 32)]
const ICON_SIZE := 28.0
const ICONS: Array[Texture2D] = [preload("res://art/svg/icon_paint.svg"), preload("res://art/svg/icon_swap.svg"), preload("res://art/svg/icon_exit.svg")]
## Seconds past par for the face to warm fully.
const WARM_TIME := 4.0
## A goal's pop: how long, and how much bigger at its height.
const POP_TIME := 0.35
const POP_GROW := 0.35
const FACE := Color(0.95, 0.92, 0.84)
const FACE_WARM := Color(0.93, 0.42, 0.3)
const WEDGE := Color(0.95, 0.76, 0.3, 0.85)
const GILT := Color(0.79, 0.64, 0.29)
const INK := Color(0.1, 0.08, 0.13)
const PLATE := Color(0.1, 0.08, 0.13, 0.6)
const UNDONE := Color(1.0, 1.0, 1.0, 0.35)
const TICK := Color(0.45, 0.85, 0.4)
const SKETCH_CENTER := Vector2(258, 32)
const SKETCH_SIZE := Vector2(20, 25)

var room: Room
## The goals done as last drawn, and each one's pop clock (seconds since done; POP_TIME and
## over: no pop).
var done: Array[bool] = [false, false, false]
var _pops: Array[float] = [POP_TIME, POP_TIME, POP_TIME]
## Whether the sketch shows (the run has it), and its pop clock.
var has_sketch := false
var _sketch_pop := POP_TIME


## How full the par clock is after `elapsed` of `par` seconds (0 to 1; full at par).
static func clock_fill(elapsed: float, par: float) -> float:
	if par <= 0.0:
		return 1.0
	return clampf(elapsed / par, 0.0, 1.0)


## How warm the face is (0 to 1) after `elapsed` of `par`: 0 until par, then rising over
## WARM_TIME.
static func warmth(elapsed: float, par: float) -> float:
	return clampf((elapsed - par) / WARM_TIME, 0.0, 1.0)


## The goals [painted, swapped, escaped] for a mime that `has_fake`, is `carrying` the
## original, and has `escaped`.
static func goals(has_fake: bool, carrying: bool, escaped: bool) -> Array[bool]:
	return [has_fake or carrying or escaped, carrying or escaped, escaped]


## Where the clock is drawn (its crown included), and the objective strip's plate (room
## units): nothing the player taps or reads may sit under them.
static func clock_rect() -> Rect2:
	var reach := CLOCK_RADIUS + 3.0
	return Rect2(CLOCK_CENTER - Vector2(reach, CLOCK_RADIUS + 6.0), Vector2(reach * 2.0, CLOCK_RADIUS + 6.0 + reach))


static func sketch_rect() -> Rect2:
	return Rect2(SKETCH_CENTER - SKETCH_SIZE / 2.0, SKETCH_SIZE).grow(5.0)


static func plate_rect() -> Rect2:
	var left := ICON_CENTERS[0] - Vector2(ICON_SIZE * 0.5 + 6.0, ICON_SIZE * 0.5 + 4.0)
	var right := ICON_CENTERS[ICON_CENTERS.size() - 1] + Vector2(ICON_SIZE * 0.5 + 6.0, ICON_SIZE * 0.5 + 4.0)
	return Rect2(left, right - left)


func _process(delta: float) -> void:
	if room == null:
		return
	visible = not room.run.replaying
	if not visible:
		return
	var now := goals(room.mime.has_fake, room.mime.carrying, room.finished)
	var calm := GameState.reduce_motion_for(self)
	for i in now.size():
		if now[i] and not done[i]:
			_pops[i] = POP_TIME if calm else 0.0
		elif not now[i]:
			_pops[i] = POP_TIME
		_pops[i] = minf(_pops[i] + delta, POP_TIME)
	done = now
	if room.run.has_sketch and not has_sketch:
		_sketch_pop = POP_TIME if calm else 0.0
	has_sketch = room.run.has_sketch
	_sketch_pop = minf(_sketch_pop + delta, POP_TIME)
	queue_redraw()


func _draw() -> void:
	if room == null:
		return
	_draw_clock(clock_fill(room.elapsed, room.par_time), warmth(room.elapsed, room.par_time))
	var plate := plate_rect()
	var cap := plate.size.y * 0.5
	draw_rect(Rect2(plate.position + Vector2(cap, 0.0), plate.size - Vector2(cap * 2.0, 0.0)), PLATE)
	draw_circle(plate.position + Vector2(cap, cap), cap, PLATE)
	draw_circle(plate.end - Vector2(cap, cap), cap, PLATE)
	for i in ICONS.size():
		var grow := 1.0 + POP_GROW * sin(PI * _pops[i] / POP_TIME)
		var size := Vector2.ONE * ICON_SIZE * grow
		draw_texture_rect(ICONS[i], Rect2(ICON_CENTERS[i] - size * 0.5, size), false, Color.WHITE if done[i] else UNDONE)
		if done[i]:
			var at := ICON_CENTERS[i] + Vector2(9, 9)
			draw_circle(at, 6.5, INK)
			draw_polyline(PackedVector2Array([at + Vector2(-3.5, 0.0), at + Vector2(-1.0, 2.8), at + Vector2(3.8, -3.0)]), TICK, 2.2, true)
	var picture: Texture2D = Paintings.SKETCHES.get(StringName(room.run.wing.painting))
	if has_sketch and picture != null:
		var grow := 1.0 + POP_GROW * sin(PI * _sketch_pop / POP_TIME)
		var area := sketch_rect()
		draw_rect(area, PLATE)
		draw_texture_rect(picture, Rect2(SKETCH_CENTER - SKETCH_SIZE * grow / 2.0, SKETCH_SIZE * grow), false)


## The stopwatch: crown, face (warming past par), the filled wedge from twelve, the par
## mark at twelve and the hand at the wedge's edge.
func _draw_clock(fill: float, warm: float) -> void:
	var c := CLOCK_CENTER
	draw_rect(Rect2(c + Vector2(-4, -CLOCK_RADIUS - 6), Vector2(8, 5)), GILT)
	draw_circle(c, CLOCK_RADIUS + 3.0, INK)
	draw_circle(c, CLOCK_RADIUS, FACE.lerp(FACE_WARM, warm))
	if fill > 0.0:
		var points := PackedVector2Array([c])
		var steps := maxi(2, ceili(fill * 40.0))
		for i in steps + 1:
			var angle := -PI * 0.5 + TAU * fill * i / steps
			points.append(c + Vector2.from_angle(angle) * (CLOCK_RADIUS - 2.0))
		draw_colored_polygon(points, WEDGE.lerp(FACE_WARM, warm))
	draw_arc(c, CLOCK_RADIUS + 1.5, 0.0, TAU, 40, GILT, 2.0, true)
	draw_line(c + Vector2(0, -CLOCK_RADIUS - 1.0), c + Vector2(0, -CLOCK_RADIUS + 6.0), INK, 3.0, true)
	draw_line(c, c + Vector2.from_angle(-PI * 0.5 + TAU * fill) * (CLOCK_RADIUS - 4.0), INK, 2.5, true)
	draw_circle(c, 2.5, INK)
