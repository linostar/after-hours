class_name Sketch
extends Node2D
## A wing's hidden sketch (Paintings.SKETCHES, `texture`), tucked behind a tilt frame or
## inside a hiding portrait (the room's sketch_in). It is not drawn until that hiding place is
## used: then it slips out from behind it and flutters down (drop: FALL_TIME, swaying SWAY to
## either side, falling straight under Reduce Motion) to lie on the floor at its position, a
## glint pulsing on its corner at GLINT_HZ (held still under Reduce Motion) so the eye finds
## it. The room walks the mime to it on a tap (rect) or E, then takes it (take: it pops up and
## fades, POP_TIME). Its position is where it lies.

enum State { HIDDEN, FALLING, LYING, TAKEN }

## Its size lying on the floor, and how far round it a tap still means it.
const SIZE := Vector2(24, 30)
const TAP_MARGIN := 14.0
const FALL_TIME := 0.9
const SWAY := 14.0
## Swings from side to side on the way down (a falling sheet), over FALL_TIME.
const SWAYS := 2.0
const GLINT_HZ := 0.6
const GLINT := Color(1.0, 0.95, 0.75)
const POP_TIME := 0.35
const POP_GROW := 0.6

var texture: Texture2D
var state := State.HIDDEN
## Where it is drawn from its resting place while falling (and its tilt), and the pop.
var _offset := Vector2.ZERO
var _tilt := 0.0
var _pop := 0.0
var _clock := 0.0


## Where a tap means it (only while it lies on the floor).
func rect() -> Rect2:
	return Rect2(position - SIZE / 2.0, SIZE).grow(TAP_MARGIN)


## Slips out at `from` (room units) and flutters down to its resting place.
func drop(from: Vector2) -> void:
	state = State.FALLING
	var calm := GameState.reduce_motion_for(self)
	var fall := create_tween()
	fall.tween_method(_fall_step.bind(from - position, calm), 0.0, 1.0, FALL_TIME)
	fall.tween_callback(lie)


## Lies on the floor at its resting place (dropped earlier on this play).
func lie() -> void:
	state = State.LYING
	_offset = Vector2.ZERO
	_tilt = 0.0
	queue_redraw()


## Taken by the mime: it pops up and fades out.
func take() -> void:
	state = State.TAKEN
	var pop := create_tween()
	pop.tween_property(self, "_pop", 1.0, POP_TIME)
	pop.tween_callback(hide)


func _fall_step(t: float, start: Vector2, calm: bool) -> void:
	var sway := 0.0 if calm else sin(t * TAU * SWAYS) * (1.0 - t)
	_offset = start * (1.0 - t * t) + Vector2(sway * SWAY, 0.0)
	_tilt = sway * 0.5
	queue_redraw()


func _process(delta: float) -> void:
	if state == State.LYING or state == State.TAKEN:
		_clock += delta
		queue_redraw()


func _draw() -> void:
	if state == State.HIDDEN or texture == null:
		return
	var grow := 1.0 + POP_GROW * _pop
	draw_set_transform(_offset + Vector2(0.0, -SIZE.y * 0.5 * _pop), _tilt, Vector2.ONE * grow)
	var fade := Color(1.0, 1.0, 1.0, 1.0 - _pop)
	draw_rect(Rect2(-SIZE / 2.0 + Vector2(2, 2), SIZE), Color(0.0, 0.0, 0.0, 0.25 * fade.a))
	draw_texture_rect(texture, Rect2(-SIZE / 2.0, SIZE), false, fade)
	if state == State.LYING:
		var pulse := 0.5 if GameState.reduce_motion_for(self) else 0.5 + 0.5 * sin(TAU * GLINT_HZ * _clock)
		var at := Vector2(SIZE.x * 0.5 - 3.0, -SIZE.y * 0.5 + 3.0)
		var reach := 3.0 + 3.0 * pulse
		draw_line(at - Vector2(reach, 0), at + Vector2(reach, 0), Color(GLINT, 0.4 + 0.6 * pulse), 1.4, true)
		draw_line(at - Vector2(0, reach), at + Vector2(0, reach), Color(GLINT, 0.4 + 0.6 * pulse), 1.4, true)
	draw_set_transform(Vector2.ZERO)
