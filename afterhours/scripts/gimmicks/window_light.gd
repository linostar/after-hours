class_name WindowLight
extends Gimmick
## Wing 1 (Vermeer): moonlight from a tall window in the back wall falls across the floor in
## a slanted band that drifts slowly from side to side, like clouds passing the moon. In the
## band the mime is lit (guards grow suspicious LIT times as fast); elsewhere the gallery is
## dim (DIM). Drawn after Vermeer's interiors: a deep wooden window with a stone sill and
## diamond-leaded panes, the moonlit sky through them; a soft shaft of cool light from the
## glass down to the floor, where the band lies with a bright core (exactly the lit width)
## and soft edges; dust motes drift in the shaft (decoration: under 2 Hz, still under
## Reduce Motion). The light (glass, shaft, band, motes) is drawn on a layer of its own at
## full brightness in the room's night (Room.GLOW), behind the frame, lead and sill.

const LIT := 1.8
const DIM := 0.6
## The window on the back wall: its glass, and the frame width around it.
const WINDOW_RECT := Rect2(-40, 20, 80, 110)
const SASH_WIDTH := 5.0
const FLOOR_TOP := 172.0
const FLOOR_BOTTOM := 540.0
## How far the band leans right per unit down the floor.
const SLANT := 0.45
## Vermeer's palette by night: walnut frame, grey stone sill, lead, moonlit glass, cool light.
const FRAME := Color(0.3, 0.2, 0.12)
const FRAME_LIGHT := Color(0.5, 0.36, 0.22)
const SILL := Color(0.62, 0.6, 0.55)
const LEAD := Color(0.2, 0.2, 0.22, 0.85)
const GLASS_TOP := Color(0.62, 0.72, 0.92)
const GLASS_BOTTOM := Color(0.4, 0.5, 0.78)
const LIGHT := Color(0.82, 0.9, 1.0)
## The band's soft edges: each ring wider than the lit core, fainter.
const HALO_WIDTHS: Array[float] = [1.5, 1.25, 1.0]
const HALO_ALPHAS: Array[float] = [0.07, 0.11, 0.2]
const SHAFT_ALPHAS: Array[float] = [0.18, 0.07]
const GLOW := preload("res://art/glow.tres")
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
var _light: Node2D


func _ready() -> void:
	_light = Node2D.new()
	_light.name = "Light"
	_light.material = GLOW
	_light.show_behind_parent = true
	_light.draw.connect(_draw_light)
	add_child(_light)


## The band's middle at floor height `y`.
func band_x(y: float) -> float:
	return window_x + sin(TAU * _time / period) * sweep + (y - FLOOR_TOP) * SLANT


func light_at(point: Vector2) -> float:
	return LIT if absf(point.x - band_x(point.y)) <= width / 2.0 else DIM


func tick(delta: float) -> void:
	_time += delta
	queue_redraw()
	if _light != null:
		_light.queue_redraw()


func _glass() -> Rect2:
	return Rect2(WINDOW_RECT.position + Vector2(window_x, 0.0), WINDOW_RECT.size)


## The window's wood, lead and stone (in the room's night).
func _draw() -> void:
	_draw_window(_glass())


## The light (Light layer, full brightness, behind the window's wood): the moonlit glass,
## the shaft through the air from the glass to where the band meets the wall, the band, and
## the motes in the shaft.
func _draw_light() -> void:
	var glass := _glass()
	_light.draw_polygon(PackedVector2Array([glass.position, Vector2(glass.end.x, glass.position.y), glass.end, Vector2(glass.position.x, glass.end.y)]), PackedColorArray([GLASS_TOP, GLASS_TOP, GLASS_BOTTOM, GLASS_BOTTOM]))
	var top := band_x(FLOOR_TOP)
	var bottom := band_x(FLOOR_BOTTOM)
	var shaft := PackedVector2Array([glass.position + Vector2(0, glass.size.y), glass.end, Vector2(top + width / 2.0, FLOOR_TOP), Vector2(top - width / 2.0, FLOOR_TOP)])
	var high := Color(LIGHT, SHAFT_ALPHAS[0])
	var low := Color(LIGHT, SHAFT_ALPHAS[1])
	_light.draw_polygon(shaft, PackedColorArray([high, high, low, low]))
	for k in HALO_WIDTHS.size():
		var half := width / 2.0 * HALO_WIDTHS[k]
		var near := Color(LIGHT, HALO_ALPHAS[k] * 1.4)
		var far := Color(LIGHT, HALO_ALPHAS[k] * 0.7)
		_light.draw_polygon(PackedVector2Array([
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
		_light.draw_circle(at, motes.randf_range(0.7, 1.4), Color(LIGHT, 0.55))


## The window: a walnut frame round the glass (the glass itself is on the Light layer behind
## it) with a lit inner edge, the lead in a diamond lattice across it, a mullion and transom,
## and a stone sill below.
func _draw_window(glass: Rect2) -> void:
	var rim := SASH_WIDTH + 2.0
	draw_rect(Rect2(glass.position - Vector2(rim, rim), Vector2(glass.size.x + rim * 2.0, rim)), FRAME)
	draw_rect(Rect2(glass.position.x - rim, glass.end.y, glass.size.x + rim * 2.0, rim), FRAME)
	draw_rect(Rect2(glass.position.x - rim, glass.position.y, rim, glass.size.y), FRAME)
	draw_rect(Rect2(glass.end.x, glass.position.y, rim, glass.size.y), FRAME)
	draw_rect(Rect2(glass.position - Vector2(SASH_WIDTH, SASH_WIDTH), Vector2(glass.size.x + SASH_WIDTH * 2.0, 2.0)), FRAME_LIGHT)
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
