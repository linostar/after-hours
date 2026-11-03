class_name WindowLight
extends Gimmick
## Wing 1 (Vermeer): daylight from a tall window in the back wall falls across the floor in
## a slanted band that drifts slowly from side to side, like clouds passing. In the band the
## mime is lit (guards grow suspicious LIT times as fast); elsewhere the gallery is dim
## (DIM). Drawn after Vermeer's interiors: a deep wooden window with a stone sill and
## diamond-leaded panes, pale where the sky shows through; a soft shaft of warm light from
## the glass down to the floor, where the band lies with a bright core (exactly the lit
## width) and soft edges; dust motes drift in the shaft (decoration: under 2 Hz, still
## under Reduce Motion).

const LIT := 1.8
const DIM := 0.6
## The window on the back wall: its glass, and the frame width around it.
const WINDOW_RECT := Rect2(-40, 20, 80, 110)
const SASH_WIDTH := 5.0
const FLOOR_TOP := 172.0
const FLOOR_BOTTOM := 540.0
## How far the band leans right per unit down the floor.
const SLANT := 0.45
## Vermeer's palette: walnut frame, grey stone sill, lead, pale daylit glass, warm light.
const FRAME := Color(0.3, 0.2, 0.12)
const FRAME_LIGHT := Color(0.5, 0.36, 0.22)
const SILL := Color(0.62, 0.6, 0.55)
const LEAD := Color(0.2, 0.2, 0.22, 0.85)
const GLASS_TOP := Color(0.93, 0.95, 0.9)
const GLASS_BOTTOM := Color(0.72, 0.8, 0.84)
const LIGHT := Color(1.0, 0.93, 0.7)
## The band's soft edges: each ring wider than the lit core, fainter.
const HALO_WIDTHS: Array[float] = [1.5, 1.25, 1.0]
const HALO_ALPHAS: Array[float] = [0.05, 0.07, 0.12]
## The leaded panes' diagonal spacing.
const LEAD_GAP := 14.0
const MOTES := 16
## Dust motes rise and fall this many times a second.
const MOTE_HZ := 0.12

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
	_draw_window(glass)
	var top := band_x(FLOOR_TOP)
	var bottom := band_x(FLOOR_BOTTOM)
	# The shaft through the air, from the glass to where the band meets the wall.
	var shaft := PackedVector2Array([glass.position + Vector2(0, glass.size.y), glass.end, Vector2(top + width / 2.0, FLOOR_TOP), Vector2(top - width / 2.0, FLOOR_TOP)])
	draw_polygon(shaft, PackedColorArray([Color(LIGHT, 0.12), Color(LIGHT, 0.12), Color(LIGHT, 0.05), Color(LIGHT, 0.05)]))
	for k in HALO_WIDTHS.size():
		var half := width / 2.0 * HALO_WIDTHS[k]
		var near := Color(LIGHT, HALO_ALPHAS[k] * 1.4)
		var far := Color(LIGHT, HALO_ALPHAS[k] * 0.7)
		draw_polygon(PackedVector2Array([
			Vector2(top - half, FLOOR_TOP), Vector2(top + half, FLOOR_TOP),
			Vector2(bottom + half, FLOOR_BOTTOM), Vector2(bottom - half, FLOOR_BOTTOM),
		]), PackedColorArray([near, near, far, far]))
	var t := flourish(_time)
	var motes := RandomNumberGenerator.new()
	motes.seed = 1665
	for i in MOTES:
		var down := motes.randf()
		var across := motes.randf_range(-0.45, 0.45)
		var drift := sin(TAU * (t * MOTE_HZ + motes.randf())) * 6.0
		var at := shaft[3].lerp(shaft[0], 1.0 - down).lerp(shaft[2].lerp(shaft[1], 1.0 - down), 0.5 + across) + Vector2(drift * 0.5, drift)
		draw_circle(at, motes.randf_range(0.7, 1.4), Color(LIGHT, 0.55))


## The window: a walnut frame with a lit inner edge, the sky graded down the glass, the
## lead in a diamond lattice across it, a mullion and transom, and a stone sill below.
func _draw_window(glass: Rect2) -> void:
	draw_rect(glass.grow(SASH_WIDTH + 2.0), FRAME)
	draw_rect(Rect2(glass.position - Vector2(SASH_WIDTH, SASH_WIDTH), Vector2(glass.size.x + SASH_WIDTH * 2.0, 2.0)), FRAME_LIGHT)
	draw_polygon(PackedVector2Array([glass.position, Vector2(glass.end.x, glass.position.y), glass.end, Vector2(glass.position.x, glass.end.y)]), PackedColorArray([GLASS_TOP, GLASS_TOP, GLASS_BOTTOM, GLASS_BOTTOM]))
	var outline := PackedVector2Array([glass.position, Vector2(glass.end.x, glass.position.y), glass.end, Vector2(glass.position.x, glass.end.y)])
	var c := -glass.size.y
	while c < glass.size.x + glass.size.y:
		for slope: float in [1.0, -1.0]:
			var start := glass.position + (Vector2(c, 0) if slope > 0.0 else Vector2(glass.size.x - c, 0))
			var line := PackedVector2Array([start, start + Vector2(slope, 1.0) * (glass.size.x + glass.size.y)])
			for inside: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(line, outline):
				draw_polyline(inside, LEAD, 1.0, true)
		c += LEAD_GAP
	draw_rect(Rect2(glass.get_center().x - SASH_WIDTH / 2.0, glass.position.y, SASH_WIDTH, glass.size.y), FRAME)
	draw_rect(Rect2(glass.position.x, glass.position.y + glass.size.y * 0.38, glass.size.x, SASH_WIDTH), FRAME)
	draw_rect(Rect2(glass.position.x - SASH_WIDTH - 5.0, glass.end.y + SASH_WIDTH, glass.size.x + SASH_WIDTH * 2.0 + 10.0, 5.0), SILL)
	draw_rect(Rect2(glass.position.x - SASH_WIDTH - 5.0, glass.end.y + SASH_WIDTH + 4.0, glass.size.x + SASH_WIDTH * 2.0 + 10.0, 1.5), SILL.darkened(0.35))
