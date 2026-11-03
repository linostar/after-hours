class_name Gimmick
extends Node2D
## A room's twist (one per wing; the room uses its child named Gimmick, if any). This base
## changes nothing; a wing's subclass answers, for a point in room coordinates:
## - light_at: how lit the mime is there (scales how fast a guard's suspicion fills; 0 is
##   shade, where guards cannot see it at all; above 1 a light shaft or a searchlight);
## - slow_at: the mime's walking speed there, as a share of Mime.SPEED;
## - noise_at: how loud its footsteps are there (0 silent; else a noise every
##   STEP_NOISE_GAP while it walks, heard by the nearest guard within that share of
##   GuardBrain.HEARING_RANGE);
## - clue_seen_by: a point `guard` now notices (a trace the mime left) and goes to look at, or
##   Vector2.INF for none (the room asks every frame, for each guard not chasing);
## and moves itself on in tick, which the room calls each physics frame it runs (not while
## a screen change fades or after the escape), so the gimmick and the room keep time. After a
## catch the room calls forget: traces the mime left go (the room starts afresh).

## Seconds between two noisy footsteps.
const STEP_NOISE_GAP := 0.5

## The room's mime (set by the room).
var mime: Mime


func light_at(_point: Vector2) -> float:
	return 1.0


func slow_at(_point: Vector2) -> float:
	return 1.0


func noise_at(_point: Vector2) -> float:
	return 0.0


## The sound of a loud footstep at `point` (where noise_at is above 0).
func noise_sound(_point: Vector2) -> StringName:
	return &"tiptoe"


func clue_seen_by(_guard: Guard) -> Vector2:
	return Vector2.INF


func tick(_delta: float) -> void:
	pass


func forget() -> void:
	pass


## Whether purely decorative motion is stilled (the Reduce Motion setting). Gameplay timing
## (lights moving, pipes gushing) never is; only flourishes drawn on top of it.
func reduce_motion() -> bool:
	if not is_inside_tree():
		return false
	var game := get_node_or_null(GameState.AUTOLOAD_PATH) as GameState
	return game != null and game.setting("reduce_motion")


## The clock decoration is drawn at: `time`, or 0 (still) under Reduce Motion.
func flourish(time: float) -> float:
	return 0.0 if reduce_motion() else time


## The points of a spiral around `centre` from radius `from` to `to`, starting at `angle`
## and turning `turn` radians (negative turns the other way), flattened by `squash`: the
## curl shared by the woodblock foam lace and the Van Gogh swirls.
static func spiral(centre: Vector2, from: float, to: float, angle: float, turn: float, squash := 1.0, steps := 14) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in steps + 1:
		var t := float(k) / steps
		var r := lerpf(from, to, t)
		var a := angle + turn * t
		points.append(centre + Vector2(cos(a) * r, sin(a) * r * squash))
	return points


## `points` stroked `width` wide in `color` over an `ink` outline (a print's or a brush's
## line), with round ends.
static func inked_line(canvas: CanvasItem, points: PackedVector2Array, color: Color, width: float, ink: Color, outline := 1.5) -> void:
	canvas.draw_polyline(points, ink, width + outline * 2.0, true)
	for end: Vector2 in [points[0], points[points.size() - 1]]:
		canvas.draw_circle(end, width / 2.0 + outline, ink)
	canvas.draw_polyline(points, color, width, true)
	for end: Vector2 in [points[0], points[points.size() - 1]]:
		canvas.draw_circle(end, width / 2.0, color)
