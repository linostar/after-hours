class_name Partition
extends StaticBody2D
## A freestanding display wall on the floor, seen 3/4 top-down: its origin is the middle
## of its footprint's front edge (so Actors y-sorts it with the mime and guards). Its
## footprint (`width` x `depth`, on the floor behind the origin) blocks walking (the room
## bakes its navmesh around the nav_obstacles group) and sight (Guard.SIGHT_MASK); it is
## drawn as a face `height` tall with its top above it, in its wing's `style`:
## MUSEUM a plain gallery wall with a base and a moulding; DELFT (Vermeer) whitewashed
## plaster over a skirting of Delft-blue tiles under a wooden cap; SHOJI (Hokusai) a folding
## screen of paper panes in a wooden lattice framed in black lacquer; HEDGE (Seurat) a
## clipped hedge in pointillist dabs in a terracotta planter; STROKES (Van Gogh) a cobalt
## wall of thick swirling brush strokes, its coping lit yellow; GOTHIC (Bosch) ashlar stone
## with pointed-arch niches; MARBLE (the Louvre) veined marble with pilasters, a dark plinth
## and a cornice. Its detail (dabs, strokes, veins) is seeded from its position, so it never
## changes between visits.

enum Style { MUSEUM, DELFT, SHOJI, HEDGE, STROKES, GOTHIC, MARBLE }

const TOP := Color(0.85, 0.82, 0.74)
const FACE := Color(0.7, 0.66, 0.58)
const OUTLINE := Color(0.12, 0.1, 0.12, 0.9)

@export var width := 160.0
@export var depth := 60.0
@export var height := 90.0
@export var style := Style.MUSEUM


func _ready() -> void:
	add_to_group(&"nav_obstacles")
	var footprint := CollisionPolygon2D.new()
	footprint.polygon = PackedVector2Array([Vector2(-width / 2.0, -depth), Vector2(width / 2.0, -depth), Vector2(width / 2.0, 0.0), Vector2(-width / 2.0, 0.0)])
	add_child(footprint)


func _draw() -> void:
	var top := Rect2(-width / 2.0, -height - depth, width, depth)
	var face := Rect2(-width / 2.0, -height, width, height)
	var brush := RandomNumberGenerator.new()
	brush.seed = int(position.x * 7.0 + position.y * 13.0)
	match style:
		Style.DELFT:
			_draw_delft(top, face)
		Style.SHOJI:
			_draw_shoji(top, face)
		Style.HEDGE:
			_draw_hedge(top, face, brush)
		Style.STROKES:
			_draw_strokes(top, face, brush)
		Style.GOTHIC:
			_draw_gothic(top, face)
		Style.MARBLE:
			_draw_marble(top, face, brush)
		_:
			_draw_museum(top, face)
	draw_rect(top, OUTLINE, false, 1.2)
	draw_rect(face, OUTLINE, false, 1.5)


func _draw_museum(top: Rect2, face: Rect2) -> void:
	draw_rect(top, TOP)
	draw_rect(face, FACE)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 4.0)), TOP.darkened(0.08))
	draw_rect(Rect2(face.position.x, face.end.y - 7.0, face.size.x, 7.0), FACE.darkened(0.35))


## Vermeer: whitewash above a row of Delft tiles (white, a blue sprig in each, blue
## edged), a walnut cap on top.
func _draw_delft(top: Rect2, face: Rect2) -> void:
	const PLASTER := Color(0.88, 0.85, 0.78)
	const WALNUT := Color(0.34, 0.22, 0.13)
	const DELFT := Color(0.2, 0.32, 0.6)
	draw_rect(top, WALNUT)
	draw_rect(top.grow(-3.0), PLASTER.darkened(0.04))
	draw_rect(face, PLASTER)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 5.0)), WALNUT)
	var tile := minf(16.0, face.size.y * 0.3)
	var row := Rect2(face.position.x, face.end.y - tile - 3.0, face.size.x, tile)
	var count := maxi(1, int(row.size.x / tile))
	var step := row.size.x / count
	for k in count:
		var cell := Rect2(row.position.x + k * step, row.position.y, step, tile)
		draw_rect(cell.grow(-0.5), Color(0.95, 0.94, 0.9))
		draw_rect(cell.grow(-1.5), DELFT, false, 0.8)
		var mid := cell.get_center()
		draw_line(mid + Vector2(0.0, 3.5), mid - Vector2(0.0, 3.0), DELFT, 1.0)
		draw_circle(mid - Vector2(0.0, 3.0), 1.6, DELFT)
		draw_line(mid, mid + Vector2(-3.0, -1.5), DELFT, 0.9)
		draw_line(mid + Vector2(0.0, 1.0), mid + Vector2(3.0, -0.5), DELFT, 0.9)
	draw_rect(Rect2(face.position.x, face.end.y - 3.0, face.size.x, 3.0), WALNUT)


## Hokusai: a folding screen, each leaf a black lacquer frame round paper panes in a
## wooden lattice (kumiko); the top a lacquer rail.
func _draw_shoji(top: Rect2, face: Rect2) -> void:
	const LACQUER := Color(0.12, 0.09, 0.09)
	const PAPER := Color(0.93, 0.9, 0.8)
	const KUMIKO := Color(0.5, 0.36, 0.22)
	const HINOKI := Color(0.8, 0.68, 0.5)
	draw_rect(top, LACQUER)
	var board := top.grow(-3.0)
	draw_rect(board, HINOKI)
	for k in range(1, 4):
		var y := board.position.y + board.size.y * k / 4.0
		draw_line(Vector2(board.position.x, y), Vector2(board.end.x, y), HINOKI.darkened(0.15), 0.6)
	draw_rect(face, LACQUER)
	var leaves := maxi(1, int(round(face.size.x / 40.0)))
	var leaf := face.size.x / leaves
	for k in leaves:
		var pane := Rect2(face.position.x + k * leaf + 3.0, face.position.y + 4.0, leaf - 6.0, face.size.y - 10.0)
		draw_rect(pane, PAPER)
		for c in range(1, 3):
			var x := pane.position.x + pane.size.x * c / 3.0
			draw_line(Vector2(x, pane.position.y), Vector2(x, pane.end.y), KUMIKO, 1.0)
		var rows := maxi(2, int(pane.size.y / 12.0))
		for r in range(1, rows):
			var y := pane.position.y + pane.size.y * r / rows
			draw_line(Vector2(pane.position.x, y), Vector2(pane.end.x, y), KUMIKO, 1.0)


## Seurat: a clipped hedge of dabs, dark greens deep in, light greens and touches of
## yellow and blue at the edges, over a terracotta planter; dabs on the top too.
func _draw_hedge(top: Rect2, face: Rect2, brush: RandomNumberGenerator) -> void:
	const LEAVES: Array[Color] = [Color(0.2, 0.42, 0.22), Color(0.3, 0.55, 0.26), Color(0.45, 0.66, 0.3), Color(0.62, 0.72, 0.32), Color(0.85, 0.78, 0.35), Color(0.3, 0.45, 0.7)]
	const PLANTER := Color(0.66, 0.36, 0.22)
	var planter := Rect2(face.position.x, face.end.y - minf(16.0, face.size.y * 0.25), face.size.x, minf(16.0, face.size.y * 0.25))
	var hedge := Rect2(face.position, Vector2(face.size.x, face.size.y - planter.size.y))
	draw_rect(top, Color(0.24, 0.45, 0.24))
	draw_rect(hedge, Color(0.17, 0.33, 0.18))
	for area: Rect2 in [top, hedge]:
		for i in int(area.get_area() / 9.0):
			var at := Vector2(brush.randf_range(area.position.x + 1.5, area.end.x - 1.5), brush.randf_range(area.position.y + 1.5, area.end.y - 1.5))
			draw_circle(at, brush.randf_range(1.0, 1.7), LEAVES[mini(brush.randi() % LEAVES.size(), LEAVES.size() - 1)])
	draw_rect(planter, PLANTER)
	draw_rect(Rect2(planter.position, Vector2(planter.size.x, 3.0)), PLANTER.lightened(0.25))
	for i in int(planter.get_area() / 10.0):
		draw_circle(Vector2(brush.randf_range(planter.position.x + 1.0, planter.end.x - 1.0), brush.randf_range(planter.position.y + 3.0, planter.end.y - 1.0)), 0.9, PLANTER.darkened(brush.randf_range(0.1, 0.3)))


## Van Gogh: cobalt plaster laid in thick short strokes curling along the wall, the coping
## on top lit yellow as if by the café's lamps.
func _draw_strokes(top: Rect2, face: Rect2, brush: RandomNumberGenerator) -> void:
	const BLUES: Array[Color] = [Color(0.16, 0.25, 0.55), Color(0.24, 0.36, 0.68), Color(0.12, 0.18, 0.42), Color(0.35, 0.48, 0.78)]
	const LAMP: Array[Color] = [Color(0.95, 0.8, 0.3), Color(0.98, 0.9, 0.5), Color(0.85, 0.62, 0.22)]
	# The top: blue strokes, warming to lamplight toward its front edge.
	draw_rect(top, BLUES[0])
	for i in int(top.get_area() / 16.0):
		var at := Vector2(brush.randf_range(top.position.x + 3.0, top.end.x - 6.0), brush.randf_range(top.position.y + 2.0, top.end.y - 2.0))
		var lit := (at.y - top.position.y) / top.size.y > 0.7
		var colour := LAMP[brush.randi() % LAMP.size()] if lit else BLUES[brush.randi() % BLUES.size()]
		draw_line(at, at + Vector2(5.0, brush.randf_range(-1.0, 1.0)), colour, 2.0, true)
	draw_rect(face, BLUES[2])
	for i in int(face.get_area() / 14.0):
		var at := Vector2(brush.randf_range(face.position.x + 3.0, face.end.x - 3.0), brush.randf_range(face.position.y + 3.0, face.end.y - 3.0))
		# The flow curls round slowly along the wall, like the painting's sky.
		var flow := Vector2.from_angle(sin(at.x * 0.06) * 0.9 + cos(at.y * 0.09) * 0.5) * brush.randf_range(4.0, 7.0)
		draw_line(at, at + flow, BLUES[brush.randi() % BLUES.size()], 2.2, true)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 3.0)), LAMP[2])


## Bosch: ashlar stone, coursed blocks with offset joints, a row of pointed-arch niches
## shadowed within, a moulded string course above them; the top a stone slab.
func _draw_gothic(top: Rect2, face: Rect2) -> void:
	const STONE := Color(0.64, 0.6, 0.52)
	const JOINT := Color(0.45, 0.41, 0.35)
	const NICHE := Color(0.24, 0.2, 0.2)
	draw_rect(top, STONE.lightened(0.12))
	var slab := 30.0
	var seam := top.position.x + slab
	while seam < top.end.x - 4.0:
		draw_line(Vector2(seam, top.position.y), Vector2(seam, top.end.y), JOINT, 0.8)
		seam += slab
	draw_line(Vector2(top.position.x, top.get_center().y), Vector2(top.end.x, top.get_center().y), JOINT, 0.8)
	draw_rect(face, STONE)
	var course := 12.0
	var rows := int(face.size.y / course)
	for r in range(1, rows + 1):
		var y := face.end.y - r * course
		if y > face.position.y:
			draw_line(Vector2(face.position.x, y), Vector2(face.end.x, y), JOINT, 0.8)
		var x := face.position.x + (12.0 if r % 2 else 0.0)
		while x < face.end.x:
			draw_line(Vector2(x, maxf(y, face.position.y)), Vector2(x, y + course), JOINT, 0.8)
			x += 24.0
	var arches := maxi(1, int(face.size.x / 34.0))
	var span := face.size.x / arches
	var tall := face.size.y * 0.55
	for k in arches:
		var mid := face.position.x + span * (k + 0.5)
		var half := span * 0.26
		var foot := face.end.y - 6.0
		var spring := foot - tall * 0.6
		var points := PackedVector2Array([Vector2(mid - half, foot), Vector2(mid - half, spring)])
		for s in 7:
			var u := float(s) / 6.0
			points.append(Vector2(mid - half * cos(u * PI / 2.0), spring - tall * 0.4 * sin(u * PI / 2.0)))
		for s in range(5, -1, -1):
			var u := float(s) / 6.0
			points.append(Vector2(mid + half * cos(u * PI / 2.0), spring - tall * 0.4 * sin(u * PI / 2.0)))
		points.append_array(PackedVector2Array([Vector2(mid + half, spring), Vector2(mid + half, foot)]))
		draw_colored_polygon(points, NICHE)
		points.append(points[0])
		draw_polyline(points, STONE.lightened(0.2), 1.2, true)
	draw_rect(Rect2(face.position.x, face.end.y - tall - 12.0, face.size.x, 3.0), STONE.lightened(0.18))


## The Louvre: cream marble veined in grey, pilasters at the ends and between bays, a dark
## plinth and a moulded cornice; the top marble too.
func _draw_marble(top: Rect2, face: Rect2, brush: RandomNumberGenerator) -> void:
	const MARBLE := Color(0.9, 0.87, 0.8)
	const VEIN := Color(0.62, 0.6, 0.58, 0.8)
	const PLINTH := Color(0.36, 0.31, 0.3)
	draw_rect(top, MARBLE.lightened(0.04))
	draw_rect(face, MARBLE)
	for area: Rect2 in [top, face]:
		for i in maxi(2, int(area.get_area() / 900.0)):
			var at := Vector2(brush.randf_range(area.position.x, area.end.x), brush.randf_range(area.position.y, area.end.y))
			var vein := PackedVector2Array([at])
			for s in 4:
				at += Vector2(brush.randf_range(4.0, 9.0), brush.randf_range(-4.0, 4.0))
				vein.append(Vector2(clampf(at.x, area.position.x, area.end.x), clampf(at.y, area.position.y, area.end.y)))
			draw_polyline(vein, VEIN, 0.7, true)
	var bays := maxi(1, int(round(face.size.x / 60.0)))
	for k in bays + 1:
		var x := face.position.x + face.size.x * k / bays
		var pilaster := Rect2(clampf(x - 4.0, face.position.x, face.end.x - 8.0), face.position.y + 6.0, 8.0, face.size.y - 16.0)
		draw_rect(pilaster, MARBLE.lightened(0.06))
		draw_line(pilaster.position + Vector2(2.5, 2.0), Vector2(pilaster.position.x + 2.5, pilaster.end.y - 2.0), VEIN, 0.6)
		draw_line(pilaster.position + Vector2(5.5, 2.0), Vector2(pilaster.position.x + 5.5, pilaster.end.y - 2.0), VEIN, 0.6)
	draw_rect(Rect2(face.position, Vector2(face.size.x, 6.0)), MARBLE.darkened(0.12))
	draw_line(face.position + Vector2(0.0, 6.0), Vector2(face.end.x, face.position.y + 6.0), PLINTH, 0.8)
	draw_rect(Rect2(face.position.x, face.end.y - 10.0, face.size.x, 10.0), PLINTH)
	draw_line(Vector2(face.position.x, face.end.y - 10.0), Vector2(face.end.x, face.end.y - 10.0), MARBLE.darkened(0.3), 1.0)
