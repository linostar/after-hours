class_name Puddles
extends Gimmick
## Wing 2 (Hokusai), and part of the finale: burst pipes. A water pipe runs along the back
## wall; at each burst water pours down onto the floor in a widening stream, where its puddle
## (a flat ellipse, the 3/4 view) spreads while the pipe gushes and dries back to a damp
## patch (DAMP of its full size) while it only drips, in a steady rhythm of its own. In a
## puddle the mime wades (SLOW of its speed) and every step splashes (LOUD: heard across
## the whole hearing range); guards wade at SLOW too (Guard asks slow_at for its own spot).
## Drawn as a Hokusai woodblock print (flat fills, inked outlines, claw-fingered foam), in
## three layers: the iron pipe on the wall (flanges, wall brackets, each burst a torn hole
## with its metal peeled back; behind the paintings), the puddles on the floor (flat
## Prussian blue rings with foam claws on the rim), and the falling water (in front of the
## paintings, behind the actors: a stream with flowing streaks, foam claws at the mouth and
## splash crests where it lands, or falling drips). The foam's sway, the streaks' flow, the
## crests and the drops are decoration: each repeats under 2 Hz and stands still under
## Reduce Motion. A pipe whose data is broken (no beat, a period or radius not above 0) is
## reported and left out.

const SLOW := 0.55
const LOUD := 1.0
## The share of a puddle's full size left between gushes.
const DAMP := 0.25
## A puddle's height over its width (the floor seen at 3/4).
const FLATTEN := 0.5
const PIPE_Y := 112.0
const PIPE_RADIUS := 6.0
const FLANGE_RADIUS := 9.5
## The print's palette: flat Prussian blue water in three tones, foam, ink and iron.
const PRUSSIAN := Color(0.1, 0.23, 0.49)
const PRUSSIAN_LIGHT := Color(0.32, 0.52, 0.75)
const PRUSSIAN_DEEP := Color(0.04, 0.1, 0.27)
const INK := Color(0.06, 0.07, 0.14)
const FOAM := Color(0.97, 0.94, 0.85)
const IRON := Color(0.4, 0.45, 0.52)
const IRON_LIGHT := Color(0.63, 0.68, 0.75)
const IRON_DARK := Color(0.24, 0.27, 0.34)
## The falling stream lets the room show through a little: it is water in the air.
const STREAM_ALPHA := 0.82
## Absolute z: the wall pipe just above the walls (under the paintings at -9), the falling
## water above the paintings and the fake's icon (-8), under the actors (0).
const PIPE_Z := -10
const SPRAY_Z := -7
const BRACKET_GAP := 160.0
## The stream's width where it lands, as a share of the puddle's radius.
const STREAM_SPREAD := 0.3
const SPLASH_DROPS := 5
## Decorative cycles per second (all under the 2 Hz flash limit): drips falling, splash
## crests and drops, the foam claws' sway and the streaks flowing down the stream.
const DRIP_HZ := 1.2
const SPLASH_HZ := 0.8
const FOAM_HZ := 0.5
const FLOW_HZ := 1.5

## Per burst: the puddle's centre (floor) and full radius (x, y, radius); the pipe bursts
## above it, on the back wall.
@export var puddles := PackedVector3Array()
## Per burst: seconds per gush-and-dry rhythm and where in it the room starts (0 dry,
## 0.5 at full size).
@export var beats := PackedVector2Array()

var _time := 0.0
var _pipe: Node2D
var _spray: Node2D


func _ready() -> void:
	for i in puddles.size():
		if not usable(i):
			(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("Puddles at %s: pipe %d is left out (puddle %s, beat %s): it needs a beat with a period above 0 and a radius above 0" % [get_path(), i, puddles[i], str(beats[i]) if i < beats.size() else "missing"])
	_pipe = _layer(PIPE_Z, _draw_pipe)
	_spray = _layer(SPRAY_Z, _draw_spray)


func _layer(z: int, drawing: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.z_as_relative = false
	layer.z_index = z
	layer.draw.connect(drawing)
	add_child(layer)
	return layer


## Whether pipe `i` has what it needs: a beat with a period above 0, a radius above 0.
func usable(i: int) -> bool:
	return i < beats.size() and beats[i].x > 0.0 and puddles[i].z > 0.0


## How full puddle `i` is now: 0 (damp patch) to 1 (full size).
func level(i: int) -> float:
	return (1.0 - cos(TAU * (_time / beats[i].x + beats[i].y))) / 2.0


## Whether pipe `i` gushes now (its puddle is growing) rather than dripping.
func gushing(i: int) -> bool:
	return fposmod(_time / beats[i].x + beats[i].y, 1.0) < 0.5


## Puddle `i`'s radius across now.
func radius(i: int) -> float:
	return puddles[i].z * lerpf(DAMP, 1.0, level(i))


## Whether `point` is in a puddle now.
func wet(point: Vector2) -> bool:
	for i in puddles.size():
		if not usable(i):
			continue
		var r := radius(i)
		var offset := point - Vector2(puddles[i].x, puddles[i].y)
		if (offset.x / r) ** 2 + (offset.y / (r * FLATTEN)) ** 2 <= 1.0:
			return true
	return false


func slow_at(point: Vector2) -> float:
	return SLOW if wet(point) else 1.0


func noise_at(point: Vector2) -> float:
	return LOUD if wet(point) else 0.0


func noise_sound(_point: Vector2) -> StringName:
	return &"splash"


## Moves time on; a pipe that starts gushing sounds its burst.
func tick(delta: float) -> void:
	var was: Array[bool] = []
	for i in puddles.size():
		was.append(usable(i) and gushing(i))
	_time += delta
	for i in puddles.size():
		if usable(i) and gushing(i) and not was[i]:
			Audio.play_for(self, &"pipe_burst")
	queue_redraw()
	if _spray != null:
		_spray.queue_redraw()


## The puddles, on the floor: an inked rim, flat rings of Prussian blue, ripples, and foam
## claws curling along the far rim.
func _draw() -> void:
	var t := flourish(_time)
	for i in puddles.size():
		if not usable(i):
			continue
		var centre := Vector2(puddles[i].x, puddles[i].y)
		var r := radius(i)
		draw_colored_polygon(_ellipse(centre, r + 2.0), INK)
		draw_colored_polygon(_ellipse(centre, r), PRUSSIAN)
		var inner := centre + Vector2(r * 0.08, -r * FLATTEN * 0.14)
		draw_colored_polygon(_ellipse(inner, r * 0.64), PRUSSIAN_LIGHT)
		draw_colored_polygon(_ellipse(inner + Vector2(r * 0.04, -r * FLATTEN * 0.08), r * 0.32), PRUSSIAN)
		draw_polyline(spiral(centre, r * 0.82, r * 0.82, PI * 0.2, PI * 0.55, FLATTEN), FOAM, 1.5, true)
		draw_polyline(spiral(inner, r * 0.48, r * 0.48, PI * 1.15, PI * 0.5, FLATTEN), FOAM, 1.2, true)
		var claws := maxi(2, int(r / 18.0))
		for k in claws:
			var angle := PI + PI * (k + 0.5) / claws
			var at := centre + Vector2(cos(angle) * r, sin(angle) * r * FLATTEN)
			var dir := signf(cos(angle)) if absf(cos(angle)) > 0.1 else 1.0
			_claw(self, at, 5.0 + r * 0.06, dir, sin(TAU * (t * FOAM_HZ + k * 0.3)) * 0.2)


## The iron pipe along the wall: inked, lit along its top; flanges at its joints, brackets
## strapping it to the wall, and the torn burst above each usable puddle.
func _draw_pipe() -> void:
	if puddles.is_empty():
		return
	var top := PIPE_Y - PIPE_RADIUS
	_pipe.draw_rect(Rect2(0.0, top - 1.5, Content.BASE.x, PIPE_RADIUS * 2.0 + 3.0), INK)
	_pipe.draw_rect(Rect2(0.0, top, Content.BASE.x, PIPE_RADIUS * 2.0), IRON)
	_pipe.draw_rect(Rect2(0.0, top + 1.5, Content.BASE.x, 2.5), IRON_LIGHT)
	_pipe.draw_rect(Rect2(0.0, PIPE_Y + PIPE_RADIUS - 3.0, Content.BASE.x, 2.0), IRON_DARK)
	var x := BRACKET_GAP / 2.0
	while x < Content.BASE.x:
		_bracket(x)
		_flange(x + BRACKET_GAP / 2.0)
		x += BRACKET_GAP
	for i in puddles.size():
		if usable(i):
			_burst(Vector2(puddles[i].x, PIPE_Y))


## A strap round the pipe, screwed to a plate on the wall above.
func _bracket(x: float) -> void:
	var top := PIPE_Y - PIPE_RADIUS
	_pipe.draw_rect(Rect2(x - 7.0, top - 13.0, 14.0, 5.5), INK)
	_pipe.draw_rect(Rect2(x - 5.5, top - 11.5, 11.0, 2.5), IRON_DARK)
	_pipe.draw_rect(Rect2(x - 4.0, top - 9.0, 8.0, PIPE_RADIUS * 2.0 + 10.5), INK)
	_pipe.draw_rect(Rect2(x - 2.5, top - 8.0, 5.0, PIPE_RADIUS * 2.0 + 8.5), IRON)
	_pipe.draw_rect(Rect2(x - 2.5, top - 8.0, 1.5, PIPE_RADIUS * 2.0 + 8.5), IRON_LIGHT)
	for side: float in [-4.0, 4.0]:
		_pipe.draw_circle(Vector2(x + side, top - 10.2), 1.2, IRON_LIGHT)


## A joint's flange: a collar wider than the pipe with a bolt top and bottom.
func _flange(x: float) -> void:
	if x >= Content.BASE.x:
		return
	_pipe.draw_rect(Rect2(x - 4.5, PIPE_Y - FLANGE_RADIUS - 1.5, 9.0, FLANGE_RADIUS * 2.0 + 3.0), INK)
	_pipe.draw_rect(Rect2(x - 3.0, PIPE_Y - FLANGE_RADIUS, 6.0, FLANGE_RADIUS * 2.0), IRON)
	_pipe.draw_rect(Rect2(x - 3.0, PIPE_Y - FLANGE_RADIUS, 1.5, FLANGE_RADIUS * 2.0), IRON_LIGHT)
	for side: float in [-1.0, 1.0]:
		_pipe.draw_circle(Vector2(x, PIPE_Y + side * (FLANGE_RADIUS - 2.2)), 1.3, INK)


## The burst: a torn, inked hole with dark water inside, its iron peeled back in curling
## flaps.
func _burst(at: Vector2) -> void:
	var hole := PackedVector2Array()
	for k in 12:
		var angle := TAU * k / 12.0
		var reach := 1.0 if k % 2 == 0 else 0.62
		hole.append(at + Vector2(cos(angle) * 9.0, sin(angle) * (PIPE_RADIUS + 1.0)) * reach)
	_pipe.draw_colored_polygon(hole, INK)
	_pipe.draw_colored_polygon(_ellipse(at + Vector2(0.0, 1.0), 4.5), PRUSSIAN_DEEP)
	# Each flap: its angle out of the hole, its length and which way its tip curls.
	for flap: Vector3 in [Vector3(-2.4, 10.0, -1.0), Vector3(-0.7, 11.0, 1.0), Vector3(2.2, 8.0, -1.0), Vector3(0.8, 9.0, 1.0)]:
		var out := Vector2.from_angle(flap.x)
		var across := out.orthogonal() * 3.2
		var base := at + out * Vector2(8.0, PIPE_RADIUS)
		var tip := base + out * flap.y
		var curl := tip + across.normalized() * flap.z * 3.0 - out * 1.5
		# Round the outline in order: the curl sits on the side it bends to.
		var petal := PackedVector2Array([base - across, tip, curl, base + across] if flap.z > 0.0 else [base - across, curl, tip, base + across])
		_pipe.draw_colored_polygon(petal, IRON)
		petal.append(petal[0])
		_pipe.draw_polyline(petal, INK, 1.5, true)
		_pipe.draw_line(base, tip, IRON_LIGHT, 1.0, true)


## The water falling from each burst. Gushing: an inked stream, lighter down its middle,
## streaks flowing down it, foam claws flaring from the mouth and splash crests and drops
## where it lands. Dripping: drops falling from the burst.
func _draw_spray() -> void:
	var t := flourish(_time)
	for i in puddles.size():
		if not usable(i):
			continue
		var centre := Vector2(puddles[i].x, puddles[i].y)
		var burst := Vector2(centre.x, PIPE_Y + 3.0)
		if not gushing(i):
			for d in 2:
				var u := fposmod(t * DRIP_HZ + d * 0.5, 1.0)
				_drop(burst.lerp(centre, u * u), 2.6)
			continue
		var spread := puddles[i].z * STREAM_SPREAD
		var stream := PackedVector2Array([burst + Vector2(-5, 0), burst + Vector2(5, 0), centre + Vector2(spread, 0), centre + Vector2(-spread, 0)])
		_spray.draw_colored_polygon(stream, Color(PRUSSIAN, STREAM_ALPHA))
		_spray.draw_colored_polygon(PackedVector2Array([burst + Vector2(-1.5, 0), burst + Vector2(2, 0), centre + Vector2(spread * 0.35, 0), centre + Vector2(-spread * 0.15, 0)]), Color(PRUSSIAN_LIGHT, STREAM_ALPHA))
		var flow := fposmod(t * FLOW_HZ, 1.0)
		for lane: float in [-0.6, 0.1, 0.55]:
			for dash in 4:
				var from := (dash + flow) / 4.0
				var to := minf(from + 0.1, 1.0)
				_spray.draw_line(burst.lerp(centre, from) + Vector2(lane * lerpf(5.0, spread, from), 0), burst.lerp(centre, to) + Vector2(lane * lerpf(5.0, spread, to), 0), FOAM, 1.4, true)
		_spray.draw_line(stream[0], stream[3], INK, 2.0, true)
		_spray.draw_line(stream[1], stream[2], INK, 2.0, true)
		for side: float in [-1.0, 1.0]:
			_claw(_spray, burst + Vector2(side * 5.0, 1.0), 9.0, side, sin(TAU * t * FOAM_HZ) * 0.25 * side)
		for k in 4:
			var side := -1.0 if k % 2 == 0 else 1.0
			var reach := spread * (1.1 if k < 2 else 0.45)
			var bob := sin(TAU * (t * SPLASH_HZ + k * 0.25))
			_claw(_spray, centre + Vector2(side * reach, -2.0 - bob * 2.0), 14.0 if k < 2 else 10.0, side, bob * 0.2)
		for d in SPLASH_DROPS:
			var u := fposmod(t * SPLASH_HZ + float(d) / SPLASH_DROPS, 1.0)
			var side := -1.0 if d % 2 == 0 else 1.0
			_drop(centre + Vector2(side * (spread + u * 22.0), -sin(u * PI) * 18.0), 2.6 * (1.0 - u) + 1.0)


## A foam claw at `base` about `size` big: a stalk rising and curling over toward `dir`
## (1 right, -1 left), its crest split into fingers, leaning `sway` radians.
func _claw(canvas: CanvasItem, base: Vector2, size: float, dir: float, sway: float) -> void:
	var centre := base + Vector2(dir * size * 0.45, -size * 0.75).rotated(sway)
	var reach := base.distance_to(centre)
	var start := (base - centre).angle()
	# A tapered band between two spirals: wide at the stalk, thin at the curled tip.
	var outer := spiral(centre, reach, reach * 0.3, start, 4.2 * dir, 1.0, 12)
	var inner := spiral(centre, reach * 0.45, reach * 0.26, start, 4.2 * dir, 1.0, 12)
	inner.reverse()
	var band := outer + inner
	# The claw's fingers: points leaving the outer edge across its crest.
	for k: int in [4, 6, 8]:
		var out := (outer[k] - centre).normalized()
		var finger := PackedVector2Array([outer[k] - out.orthogonal() * dir * size * 0.12, outer[k] + out * size * 0.38 + out.orthogonal() * dir * size * 0.18, outer[k] + out.orthogonal() * dir * size * 0.12])
		canvas.draw_colored_polygon(finger, FOAM)
		finger.append(finger[0])
		canvas.draw_polyline(finger, INK, 1.0, true)
	canvas.draw_colored_polygon(band, FOAM)
	band.append(band[0])
	canvas.draw_polyline(band, INK, 1.2, true)


## A falling drop: an inked bead of blue with a glint of foam.
func _drop(at: Vector2, r: float) -> void:
	_spray.draw_circle(at, r + 1.0, INK)
	_spray.draw_circle(at, r, PRUSSIAN_LIGHT)
	_spray.draw_circle(at - Vector2(r, r) * 0.3, r * 0.35, FOAM)


## A flat ellipse's outline points around `centre`, `r` across.
func _ellipse(centre: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 32:
		var angle := TAU * k / 32.0
		points.append(centre + Vector2(cos(angle) * r, sin(angle) * r * FLATTEN))
	return points
