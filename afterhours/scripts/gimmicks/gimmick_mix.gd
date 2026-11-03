class_name GimmickMix
extends Gimmick
## Wing 6 (Leonardo), the finale: every earlier wing's gimmick at once. Its Gimmick children
## all apply: light is their product (shade from any still hides the mime), slowing their
## product, loudness the loudest, the clue the first child's that shows one; each child
## ticks with the room and knows the mime. The glass over the masterpiece (glass_rect: the
## Mona Lisa hangs under glass) is drawn in Leonardo's sfumato: no hard line anywhere, a
## smoky cool haze graded across the pane, soft diagonal glare bands fading out at their
## edges, a faint lit rim, and a soft glint drifting slowly across (decoration: under 2 Hz,
## still under Reduce Motion).

const HAZE_TOP := Color(0.82, 0.9, 0.95, 0.2)
const HAZE_BOTTOM := Color(0.55, 0.62, 0.6, 0.08)
const GLARE := Color(1.0, 0.98, 0.92)
## The glare bands: where each crosses the pane (share of its width), its width (share) and
## how bright its middle is.
const GLARES: Array[Vector3] = [Vector3(0.3, 0.6, 0.3), Vector3(0.72, 0.32, 0.13)]
const RIM := Color(0.9, 0.95, 1.0, 0.25)
## The drifting glint's passes across the pane per second.
const GLINT_HZ := 0.05

@export var glass_rect := Rect2()

var _time := 0.0
## The glass, drawn just above the paintings.
var _glass: Node2D


func _ready() -> void:
	_glass = Node2D.new()
	_glass.z_as_relative = false
	_glass.z_index = -8
	_glass.draw.connect(_draw_glass)
	add_child(_glass)


func parts() -> Array[Gimmick]:
	var found: Array[Gimmick] = []
	for child in get_children():
		if child is Gimmick:
			found.append(child)
	return found


func light_at(point: Vector2) -> float:
	var light := 1.0
	for part in parts():
		light *= part.light_at(point)
	return light


func slow_at(point: Vector2) -> float:
	var slow := 1.0
	for part in parts():
		slow *= part.slow_at(point)
	return slow


func noise_at(point: Vector2) -> float:
	var loudest := 0.0
	for part in parts():
		loudest = maxf(loudest, part.noise_at(point))
	return loudest


## The loudest part's footstep sound.
func noise_sound(point: Vector2) -> StringName:
	var loudest: Gimmick = null
	for part in parts():
		if loudest == null or part.noise_at(point) > loudest.noise_at(point):
			loudest = part
	return loudest.noise_sound(point) if loudest != null else &"tiptoe"


func clue_seen_by(guard: Guard) -> Vector2:
	for part in parts():
		var clue := part.clue_seen_by(guard)
		if clue != Vector2.INF:
			return clue
	return Vector2.INF


func tick(delta: float) -> void:
	_time += delta
	for part in parts():
		part.mime = mime
		part.tick(delta)
	if glass_rect.has_area():
		_glass.queue_redraw()


func forget() -> void:
	for part in parts():
		part.forget()


## The glass: the haze graded down the pane, each glare band a soft diagonal (bright in its
## middle, clear at both edges), the glint, and a faint rim.
func _draw_glass() -> void:
	if not glass_rect.has_area():
		return
	var g := glass_rect
	_glass.draw_polygon(PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)]), PackedColorArray([HAZE_TOP, HAZE_TOP, HAZE_BOTTOM, HAZE_BOTTOM]))
	var bands: Array[Vector3] = GLARES.duplicate()
	var glint := fposmod(flourish(_time) * GLINT_HZ, 1.0)
	bands.append(Vector3(lerpf(-0.4, 1.4, glint), 0.35, 0.16))
	for band in bands:
		_glare(g, band.x, band.y, band.z)
	var rim := PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y), g.position])
	_glass.draw_polyline(rim, RIM, 1.0, true)


## A glare band across `g` leaning up-right, centred `at` across it, `width` wide (shares of
## the pane's width), clipped to the pane: clear at both edges, `bright` in its middle.
func _glare(g: Rect2, at: float, width: float, bright: float) -> void:
	var lean := g.size.y * 0.45
	var pane := PackedVector2Array([g.position, Vector2(g.end.x, g.position.y), g.end, Vector2(g.position.x, g.end.y)])
	var half := g.size.x * width / 2.0
	var x := g.position.x + g.size.x * at
	for side: float in [-1.0, 1.0]:
		var edge := x + side * half
		var strip := PackedVector2Array([Vector2(x + lean, g.position.y), Vector2(edge + lean, g.position.y), Vector2(edge - lean, g.end.y), Vector2(x - lean, g.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(strip, pane):
			var colors := PackedColorArray()
			for point in piece:
				# Bright on the band's middle line, clear at its edge.
				var middle := x + lean * (1.0 - 2.0 * (point.y - g.position.y) / g.size.y)
				colors.append(Color(GLARE, bright * clampf(1.0 - absf(point.x - middle) / half, 0.0, 1.0)))
			_glass.draw_polygon(piece, colors)
