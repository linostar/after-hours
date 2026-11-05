class_name PowerFx
extends Node2D
## What the mime's powers (Powers) draw, faint white mime lines (the room gives it its GLOW
## material, so it reads against the night):
## - RING: the reach of the chosen power round the mime's feet, breathing at RING_HZ
##   (steady under Reduce Motion); the room moves it with the mime and shows or hides it;
## - BALL: the invisible ball's short arc from the mime's hand to where it lands over
##   BALL_FLIGHT (a dotted trail behind the ball's outline), landed emitted as it lands, then
##   a ripple spreading there over RIPPLE_TIME (the noise, seen), and it frees itself;
## - ROPE: the invisible rope from the mime's hand to the frame, pulled from slack to taut
##   and fading over PULL_TIME, then it frees itself;
## - BOX: the invisible box round the mime: two white gloves trace its panes over BOX_TRACE,
##   then rest palms flat on the front pane, sliding a little at PAT_HZ (still under Reduce
##   Motion), until the room frees it.
## Its clock runs on physics frames, so a run repeats.

## Emitted once, as the ball lands.
signal landed

enum Kind { RING, BALL, ROPE, BOX }

const LINE := Color(1.0, 1.0, 1.0, 0.5)
const GLOVE := Color(1.0, 1.0, 1.0, 0.9)
const GLOVE_INK := Color(0.1, 0.08, 0.13, 0.6)
## The mime's hand from its feet (where the ball and the rope leave it).
const HAND := Vector2(0, -62)
## The throw's gesture (CharacterRig.Fidget.THROW) and the ball's flight, both from the throw.
const THROW_TIME := 0.45
const BALL_FLIGHT := 0.55
const BALL_ARC := 70.0
const BALL_RADIUS := 7.0
const RIPPLE_TIME := 0.6
const RIPPLE_RADIUS := 60.0
## The rope's pull (CharacterRig.Fidget.PULL), and how far it sags before it is taut.
const PULL_TIME := 0.5
const ROPE_SAG := 24.0
## The box: its front pane (the mime's feet at the bottom's middle), the slant of its top and
## side in the 3/4 view, how long the gloves take to trace it, and the palms' slide.
const BOX_SIZE := Vector2(56, 96)
const BOX_DEPTH := Vector2(16, -12)
const BOX_TRACE := 0.6
const PAT_HZ := 0.6
const PAT_SLIDE := 4.0
const RING_HZ := 0.5
## The ball and the rope draw above everything that walks; the ring lies on the floor, under
## them (RING_Z); the room puts the box among the actors, y-sorted with them.
const FX_Z := 40
const RING_Z := -3

var kind := Kind.RING
## The ring's radius.
var radius := 0.0
## The ball's or the rope's ends (room coordinates; the node sits at the room's origin).
var from := Vector2.ZERO
var to := Vector2.ZERO
## Seconds since it started.
var age := 0.0


## A new effect of `kind` under `parent`, with GLOW (full brightness in the night).
static func spawn(parent: Node, of: Kind, glow: Material) -> PowerFx:
	var fx := PowerFx.new()
	fx.name = "Power" + String(Kind.keys()[of]).capitalize()
	fx.kind = of
	fx.z_index = RING_Z if of == Kind.RING else FX_Z
	fx.material = glow
	parent.add_child(fx)
	return fx


## Where the ball is at `t` (0 thrown, 1 landed) along its arc.
func ball_at(t: float) -> Vector2:
	return from.lerp(to, t) + Vector2(0.0, -sin(PI * t) * BALL_ARC)


func _physics_process(delta: float) -> void:
	var before := age
	age += delta
	if kind == Kind.BALL and before < BALL_FLIGHT and age >= BALL_FLIGHT:
		landed.emit()
	if (kind == Kind.BALL and age >= BALL_FLIGHT + RIPPLE_TIME) or (kind == Kind.ROPE and age >= PULL_TIME):
		queue_free()
		return
	queue_redraw()


func _calm() -> bool:
	return GameState.reduce_motion_for(self)


func _draw() -> void:
	match kind:
		Kind.RING:
			var breath := 1.0 if _calm() else 0.75 + 0.25 * sin(TAU * RING_HZ * age)
			draw_circle(Vector2.ZERO, radius, Color(1.0, 1.0, 1.0, 0.05))
			draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(LINE, LINE.a * breath), 2.0, true)
		Kind.BALL:
			_draw_ball()
		Kind.ROPE:
			_draw_rope()
		Kind.BOX:
			_draw_box()


func _draw_ball() -> void:
	var t := minf(age / BALL_FLIGHT, 1.0)
	var dots := floori(t * 10.0)
	for i in dots:
		draw_circle(ball_at(i / 10.0), 1.8, Color(LINE, LINE.a * 0.7))
	if t < 1.0:
		# A little squash as it falls; the outline dashed, mimed.
		var at := ball_at(t)
		var points := 16
		for i in points:
			if i % 2 == 0:
				draw_arc(at, BALL_RADIUS, TAU * i / points, TAU * (i + 1) / points, 3, GLOVE, 2.0, true)
		return
	var spread := clampf((age - BALL_FLIGHT) / RIPPLE_TIME, 0.0, 1.0)
	draw_set_transform(to, 0.0, Vector2(1.0, 0.45))
	draw_arc(Vector2.ZERO, lerpf(BALL_RADIUS, RIPPLE_RADIUS, ease(spread, 0.4)), 0.0, TAU, 48, Color(GLOVE, 0.8 * (1.0 - spread)), 3.0, true)
	draw_set_transform(Vector2.ZERO)


func _draw_rope() -> void:
	var t := clampf(age / PULL_TIME, 0.0, 1.0)
	var sag := ROPE_SAG * (1.0 - ease(t * 2.0 if t < 0.5 else 1.0, 0.5))
	var points := PackedVector2Array()
	for i in 17:
		var u := i / 16.0
		points.append(from.lerp(to, u) + Vector2(0.0, sin(PI * u) * sag))
	var color := Color(GLOVE, 0.75 * (1.0 - t * t))
	for i in range(0, points.size() - 1, 2):
		draw_line(points[i], points[i + 1], color, 2.5, true)


## The box's edges (front pane, top, right side) from the feet, in tracing order.
static func box_edges() -> Array[PackedVector2Array]:
	var half := BOX_SIZE.x / 2.0
	var top := -BOX_SIZE.y
	var foot_l := Vector2(-half, 0.0)
	var foot_r := Vector2(half, 0.0)
	var top_l := Vector2(-half, top)
	var top_r := Vector2(half, top)
	return [
		PackedVector2Array([foot_l, top_l]), PackedVector2Array([top_l, top_r]), PackedVector2Array([top_r, foot_r]), PackedVector2Array([foot_r, foot_l]),
		PackedVector2Array([top_l, top_l + BOX_DEPTH]), PackedVector2Array([top_l + BOX_DEPTH, top_r + BOX_DEPTH]),
		PackedVector2Array([top_r, top_r + BOX_DEPTH]), PackedVector2Array([top_r + BOX_DEPTH, foot_r + BOX_DEPTH]), PackedVector2Array([foot_r + BOX_DEPTH, foot_r]),
	]


func _draw_box() -> void:
	var edges := box_edges()
	var traced := clampf(age / BOX_TRACE, 0.0, 1.0) * edges.size()
	var gloves: Array[Vector2] = []
	for i in edges.size():
		var share := clampf(traced - i, 0.0, 1.0)
		if share <= 0.0:
			break
		var end := edges[i][0].lerp(edges[i][1], share)
		draw_dashed_line(edges[i][0], end, LINE, 2.0, 6.0, true, true)
		if share < 1.0:
			gloves = [end, end + Vector2(8, 4)]
	if gloves.is_empty():
		# Traced: the palms rest flat on the front pane.
		var slide := 0.0 if _calm() else PAT_SLIDE * sin(TAU * PAT_HZ * age)
		gloves = [Vector2(-13.0, -58.0 + slide), Vector2(13.0, -58.0 - slide)]
	for i in gloves.size():
		_draw_glove(gloves[i], -1.0 if i == 0 else 1.0)


## A white glove's palm at `at`, fingers up, its thumb to the `side`.
func _draw_glove(at: Vector2, side: float) -> void:
	for f in 3:
		var x := at.x + (f - 1) * 3.2
		draw_line(Vector2(x, at.y - 2.0), Vector2(x, at.y - 9.0), GLOVE, 2.8, true)
	draw_line(at + Vector2(side * 4.0, 1.0), at + Vector2(side * 8.0, -3.0), GLOVE, 2.6, true)
	draw_circle(at, 5.0, GLOVE)
	draw_arc(at, 5.0, 0.0, TAU, 16, GLOVE_INK, 1.0, true)
