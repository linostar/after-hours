class_name WindowLight
extends Gimmick
## Wing 1 (Vermeer): daylight from a tall window in the back wall falls across the floor in
## a slanted band that drifts slowly from side to side, like clouds passing. In the band the
## mime is lit (guards grow suspicious LIT times as fast); elsewhere the gallery is dim
## (DIM). Drawn as the window and a soft warm band on the floor.

const LIT := 1.8
const DIM := 0.6
const WINDOW := Color(0.85, 0.9, 0.95, 0.9)
const SASH := Color(0.32, 0.24, 0.16)
## The window on the back wall: its glass, and the sash width around and across it.
const WINDOW_RECT := Rect2(-40, 20, 80, 110)
const SASH_WIDTH := 5.0
const BEAM := Color(1.0, 0.95, 0.75, 0.16)
const FLOOR_TOP := 172.0
const FLOOR_BOTTOM := 540.0
## How far the band leans right per unit down the floor.
const SLANT := 0.45

## The band's middle where it meets the back wall at rest, how far it drifts each way, the
## seconds of one drift there and back, and its width.
@export var window_x := 300.0
@export var sweep := 220.0
@export var period := 14.0
@export var width := 130.0

var _time := 0.0


## The band's middle at floor height `y`.
func band_x(y: float) -> float:
	return window_x + sin(TAU * _time / period) * sweep + (y - FLOOR_TOP) * SLANT


func light_at(point: Vector2) -> float:
	return LIT if absf(point.x - band_x(point.y)) <= width / 2.0 else DIM


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var glass := Rect2(WINDOW_RECT.position + Vector2(window_x, 0.0), WINDOW_RECT.size)
	draw_rect(glass.grow(SASH_WIDTH), SASH)
	draw_rect(glass, WINDOW)
	draw_rect(Rect2(glass.get_center().x - SASH_WIDTH / 2.0, glass.position.y, SASH_WIDTH, glass.size.y), SASH)
	draw_rect(Rect2(glass.position.x, glass.get_center().y - SASH_WIDTH / 2.0, glass.size.x, SASH_WIDTH), SASH)
	var top := band_x(FLOOR_TOP)
	var bottom := band_x(FLOOR_BOTTOM)
	draw_colored_polygon(PackedVector2Array([
		Vector2(top - width / 2.0, FLOOR_TOP), Vector2(top + width / 2.0, FLOOR_TOP),
		Vector2(bottom + width / 2.0, FLOOR_BOTTOM), Vector2(bottom - width / 2.0, FLOOR_BOTTOM),
	]), BEAM)
