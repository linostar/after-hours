class_name Puddles
extends Gimmick
## Wing 2 (Hokusai), and part of the finale: burst pipes. A water pipe runs along the back
## wall; at each burst water pours down onto the floor in a widening stream, where its puddle
## (a flat ellipse, the 3/4 view) spreads while the pipe gushes and dries back to a damp
## patch (DAMP of its full size) while it only drips, in a steady rhythm of its own. In a
## puddle the mime wades (SLOW of its speed) and every step splashes (LOUD: heard across
## the whole hearing range); guards wade at SLOW too (Guard asks slow_at for its own spot).
## Drawn in the print's Prussian blue with a foam rim and splash drops, in three layers: the
## pipe and its cracks on the wall (behind the paintings), the puddles on the floor, and the
## falling water (in front of the paintings, behind the actors). A pipe whose data is broken
## (no beat, a period or radius not above 0) is reported and left out.

const SLOW := 0.55
const LOUD := 1.0
## The share of a puddle's full size left between gushes.
const DAMP := 0.25
## A puddle's height over its width (the floor seen at 3/4).
const FLATTEN := 0.5
const PIPE_Y := 112.0
const PIPE := Color(0.42, 0.44, 0.48)
const PIPE_SHADE := Color(0.26, 0.27, 0.3)
const WATER := Color(0.06, 0.2, 0.45, 0.7)
## The falling stream is thinner than a puddle: it is water in the air, not wet floor.
const STREAM_ALPHA := 0.45
## Absolute z: the wall pipe just above the walls (under the paintings at -9), the falling
## water above the paintings and the fake's icon (-8), under the actors (0).
const PIPE_Z := -10
const SPRAY_Z := -7
const FOAM := Color(0.95, 0.93, 0.85, 0.85)
const BRACKET_GAP := 160.0
## The stream's width where it lands, as a share of the puddle's radius.
const STREAM_SPREAD := 0.3
const DRIP_SPEED := 1.6
const SPLASH_DROPS := 5

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


## The puddles, on the floor.
func _draw() -> void:
	for i in puddles.size():
		if usable(i):
			var points := _ellipse(Vector2(puddles[i].x, puddles[i].y), radius(i))
			draw_colored_polygon(points, WATER)
			points.append(points[0])
			draw_polyline(points, FOAM, 2.0, true)


## The pipe along the wall, its brackets and a crack above each usable puddle.
func _draw_pipe() -> void:
	if puddles.is_empty():
		return
	_pipe.draw_line(Vector2(0.0, PIPE_Y + 3.0), Vector2(Content.BASE.x, PIPE_Y + 3.0), PIPE_SHADE, 10.0)
	_pipe.draw_line(Vector2(0.0, PIPE_Y), Vector2(Content.BASE.x, PIPE_Y), PIPE, 8.0)
	var x := BRACKET_GAP / 2.0
	while x < Content.BASE.x:
		_pipe.draw_rect(Rect2(x - 3.0, PIPE_Y - 7.0, 6.0, 14.0), PIPE_SHADE)
		x += BRACKET_GAP
	for i in puddles.size():
		if usable(i):
			var burst := Vector2(puddles[i].x, PIPE_Y)
			_pipe.draw_polyline(PackedVector2Array([burst + Vector2(-7, -5), burst + Vector2(-2, 2), burst + Vector2(2, -3), burst + Vector2(7, 4)]), PIPE_SHADE, 3.0)


## The water falling from each burst: a widening stream with splash drops while it gushes,
## drips while it does not.
func _draw_spray() -> void:
	for i in puddles.size():
		if not usable(i):
			continue
		var centre := Vector2(puddles[i].x, puddles[i].y)
		var burst := Vector2(centre.x, PIPE_Y)
		if gushing(i):
			var spread := puddles[i].z * STREAM_SPREAD
			var stream := PackedVector2Array([burst + Vector2(-3, 0), burst + Vector2(3, 0), centre + Vector2(spread, 0), centre + Vector2(-spread, 0)])
			_spray.draw_colored_polygon(stream, Color(WATER, STREAM_ALPHA))
			_spray.draw_line(stream[0], stream[3], FOAM, 2.0, true)
			_spray.draw_line(stream[1], stream[2], FOAM, 2.0, true)
			# Splash drops leaping out where it lands, after the print's foam claws.
			for d in SPLASH_DROPS:
				var u := fposmod(_time * DRIP_SPEED * 1.5 + float(d) / SPLASH_DROPS, 1.0)
				var side := -1.0 if d % 2 == 0 else 1.0
				_spray.draw_circle(centre + Vector2(side * (spread + u * 22.0), -sin(u * PI) * 18.0), 3.0 * (1.0 - u) + 1.0, FOAM)
		else:
			for d in 2:
				var u := fposmod(_time * DRIP_SPEED + d * 0.5, 1.0)
				_spray.draw_circle(burst.lerp(centre, u), 3.0, FOAM)


## A flat ellipse's outline points around `centre`, `r` across.
func _ellipse(centre: Vector2, r: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 32:
		var angle := TAU * k / 32.0
		points.append(centre + Vector2(cos(angle) * r, sin(angle) * r * FLATTEN))
	return points
