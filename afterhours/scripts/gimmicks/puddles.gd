class_name Puddles
extends Gimmick
## Wing 2 (Hokusai), and part of the finale: burst pipes. A water pipe runs along the back
## wall; at each burst water pours down onto the floor in a widening stream, where its puddle
## (a flat ellipse, the 3/4 view) spreads while the pipe gushes and dries back to a damp
## patch (DAMP of its full size) while it only drips, in a steady rhythm of its own. In a
## puddle the mime wades (SLOW of its speed) and every step splashes (LOUD: heard across
## the whole hearing range); guards wade at SLOW too (Guard asks slow_at for its own spot).
## Drawn in the print's Prussian blue with a foam rim and a curling spray.

const SLOW := 0.55
const LOUD := 1.0
## The share of a puddle's full size left between gushes.
const DAMP := 0.25
## A puddle's height over its width (the floor seen at 3/4).
const FLATTEN := 0.5
const PIPE_Y := 112.0
const PIPE := Color(0.42, 0.44, 0.48)
const PIPE_SHADE := Color(0.26, 0.27, 0.3)
const WATER := Color(0.12, 0.3, 0.62, 0.6)
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


## How full puddle `i` is now: 0 (damp patch) to 1 (full size).
func level(i: int) -> float:
	var beat := beats[i] if i < beats.size() else Vector2(10.0, 0.0)
	return (1.0 - cos(TAU * (_time / beat.x + beat.y))) / 2.0


## Whether pipe `i` gushes now (its puddle is growing) rather than dripping.
func gushing(i: int) -> bool:
	var beat := beats[i] if i < beats.size() else Vector2(10.0, 0.0)
	return fposmod(_time / beat.x + beat.y, 1.0) < 0.5


## Puddle `i`'s radius across now.
func radius(i: int) -> float:
	return puddles[i].z * lerpf(DAMP, 1.0, level(i))


## Whether `point` is in a puddle now.
func wet(point: Vector2) -> bool:
	for i in puddles.size():
		var r := radius(i)
		var offset := point - Vector2(puddles[i].x, puddles[i].y)
		if (offset.x / r) ** 2 + (offset.y / (r * FLATTEN)) ** 2 <= 1.0:
			return true
	return false


func slow_at(point: Vector2) -> float:
	return SLOW if wet(point) else 1.0


func noise_at(point: Vector2) -> float:
	return LOUD if wet(point) else 0.0


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if puddles.is_empty():
		return
	draw_line(Vector2(0.0, PIPE_Y + 3.0), Vector2(Content.BASE.x, PIPE_Y + 3.0), PIPE_SHADE, 10.0)
	draw_line(Vector2(0.0, PIPE_Y), Vector2(Content.BASE.x, PIPE_Y), PIPE, 8.0)
	var x := BRACKET_GAP / 2.0
	while x < Content.BASE.x:
		draw_rect(Rect2(x - 3.0, PIPE_Y - 7.0, 6.0, 14.0), PIPE_SHADE)
		x += BRACKET_GAP
	for i in puddles.size():
		_draw_burst(i)


func _draw_burst(i: int) -> void:
	var centre := Vector2(puddles[i].x, puddles[i].y)
	var r := radius(i)
	_draw_ellipse(centre, r, WATER)
	var rim := PackedVector2Array()
	for k in 33:
		var angle := TAU * k / 32.0
		rim.append(centre + Vector2(cos(angle) * r, sin(angle) * r * FLATTEN))
	draw_polyline(rim, FOAM, 2.0, true)
	# The burst: a jagged crack in the pipe above the puddle.
	var burst := Vector2(centre.x, PIPE_Y)
	draw_polyline(PackedVector2Array([burst + Vector2(-7, -5), burst + Vector2(-2, 2), burst + Vector2(2, -3), burst + Vector2(7, 4)]), PIPE_SHADE, 3.0)
	if gushing(i):
		# A stream widening from the burst to where it lands, foam at its edges.
		var spread := puddles[i].z * STREAM_SPREAD
		var stream := PackedVector2Array([burst + Vector2(-3, 0), burst + Vector2(3, 0), centre + Vector2(spread, 0), centre + Vector2(-spread, 0)])
		draw_colored_polygon(stream, Color(WATER, 0.75))
		draw_line(stream[0], stream[3], FOAM, 2.0, true)
		draw_line(stream[1], stream[2], FOAM, 2.0, true)
		# Splash drops leaping out where it lands, curling like the print's foam claws.
		for d in SPLASH_DROPS:
			var u := fposmod(_time * DRIP_SPEED * 1.5 + float(d) / SPLASH_DROPS, 1.0)
			var side := -1.0 if d % 2 == 0 else 1.0
			var out := Vector2(side * (spread + u * 22.0), -sin(u * PI) * 18.0)
			draw_circle(centre + out, 3.0 * (1.0 - u) + 1.0, FOAM)
	else:
		# Drips falling from the burst to the damp patch.
		for d in 2:
			var u := fposmod(_time * DRIP_SPEED + d * 0.5, 1.0)
			draw_circle(burst.lerp(centre, u), 3.0, FOAM)


func _draw_ellipse(centre: Vector2, r: float, color: Color) -> void:
	var points := PackedVector2Array()
	for k in 24:
		var angle := TAU * k / 24.0
		points.append(centre + Vector2(cos(angle) * r, sin(angle) * r * FLATTEN))
	draw_colored_polygon(points, color)
