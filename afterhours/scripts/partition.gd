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
## A `prop` other than WALL is museum furniture on the same footprint (blocking walking and
## sight alike), trimmed in its wing's style colour (STYLE_TRIMS): a BENCH (a padded seat on
## legs), a PLINTH carrying a marble bust, or a ROPE (velvet slung between two brass
## stanchions).

enum Style { MUSEUM, DELFT, SHOJI, HEDGE, STROKES, GOTHIC, MARBLE }
enum Prop { WALL, BENCH, PLINTH, ROPE }

## How far a walker's feet keep off the footprint: half a guard across, arms out (the mime
## is narrower), so no body overlaps the wall. The navmesh is carved this far round it (a
## NavigationObstacle2D; the room's agent_radius still keeps them off the room's edges).
const WALKER_CLEARANCE := 26.0
## Walkers (guard.tscn, mime.tscn) turn a path's corner this early (their agents'
## path_desired_distance), cutting it; the carve leaves this much more so a cut corner still
## keeps WALKER_CLEARANCE.
const CORNER_SLACK := 4.0

const TOP := Color(0.85, 0.82, 0.74)
const FACE := Color(0.7, 0.66, 0.58)
const OUTLINE := Color(0.12, 0.1, 0.12, 0.9)
## Each style's trim for the furniture: the bench's cushion, the plinth's band, the rope.
const STYLE_TRIMS: Dictionary[Style, Color] = {
	Style.MUSEUM: Color(0.55, 0.12, 0.16), Style.DELFT: Color(0.2, 0.32, 0.6), Style.SHOJI: Color(0.62, 0.14, 0.12),
	Style.HEDGE: Color(0.3, 0.52, 0.28), Style.STROKES: Color(0.95, 0.78, 0.28), Style.GOTHIC: Color(0.42, 0.24, 0.42),
	Style.MARBLE: Color(0.56, 0.12, 0.14),
}
const WOOD := Color(0.4, 0.26, 0.15)
const BRASS := Color(0.82, 0.66, 0.3)
const PLINTH_STONE := Color(0.78, 0.76, 0.72)
const BUST := Color(0.93, 0.92, 0.88)

@export var width := 160.0
@export var depth := 60.0
@export var height := 90.0
@export var style := Style.MUSEUM
@export var prop := Prop.WALL


func _ready() -> void:
	add_to_group(&"nav_obstacles")
	var footprint := CollisionPolygon2D.new()
	footprint.polygon = PackedVector2Array([Vector2(-width / 2.0, -depth), Vector2(width / 2.0, -depth), Vector2(width / 2.0, 0.0), Vector2(-width / 2.0, 0.0)])
	add_child(footprint)
	var keep_off := NavigationObstacle2D.new()
	var reach := WALKER_CLEARANCE + CORNER_SLACK
	keep_off.vertices = PackedVector2Array([Vector2(-width / 2.0 - reach, -depth - reach), Vector2(width / 2.0 + reach, -depth - reach), Vector2(width / 2.0 + reach, reach), Vector2(-width / 2.0 - reach, reach)])
	keep_off.affect_navigation_mesh = true
	keep_off.carve_navigation_mesh = true
	keep_off.avoidance_enabled = false
	add_child(keep_off)


func _draw() -> void:
	var top := Rect2(-width / 2.0, -height - depth, width, depth)
	var face := Rect2(-width / 2.0, -height, width, height)
	var brush := RandomNumberGenerator.new()
	brush.seed = int(position.x * 7.0 + position.y * 13.0)
	if prop != Prop.WALL:
		_draw_prop(STYLE_TRIMS[style])
		return
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



## The furniture on the footprint (front edge at y 0, `depth` deep, `height` tall).
func _draw_prop(trim: Color) -> void:
	match prop:
		Prop.BENCH:
			_draw_bench(trim)
		Prop.PLINTH:
			_draw_plinth(trim)
		Prop.ROPE:
			_draw_rope(trim)


## A gallery bench: four legs, a wooden frame and a padded seat, buttoned.
func _draw_bench(trim: Color) -> void:
	var seat := Rect2(-width / 2.0, -height - depth, width, depth)
	for x: float in [-width / 2.0 + 6.0, width / 2.0 - 10.0]:
		draw_rect(Rect2(x, -height, 4.0, height), WOOD.darkened(0.2))
		draw_rect(Rect2(x + 2.0, -height - depth * 0.6, 3.0, height + depth * 0.6 - 4.0), WOOD.darkened(0.35))
	draw_rect(Rect2(-width / 2.0, -height, width, 6.0), WOOD)
	draw_rect(seat, trim)
	draw_rect(Rect2(seat.position.x, seat.end.y - 4.0, seat.size.x, 4.0), trim.darkened(0.3))
	for k in 5:
		draw_circle(Vector2(seat.position.x + seat.size.x * (k + 0.5) / 5.0, seat.get_center().y - 1.0), 1.2, trim.darkened(0.45))
	draw_rect(seat, OUTLINE, false, 1.2)
	draw_rect(Rect2(-width / 2.0, -height, width, 6.0), OUTLINE, false, 1.0)


## A stone plinth, banded in the trim, carrying a marble bust on a little socle.
func _draw_plinth(trim: Color) -> void:
	var top := Rect2(-width / 2.0, -height - depth, width, depth)
	var face := Rect2(-width / 2.0, -height, width, height)
	draw_rect(face, PLINTH_STONE.darkened(0.12))
	draw_rect(top, PLINTH_STONE)
	draw_rect(Rect2(face.position.x, face.position.y + 6.0, face.size.x, 4.0), trim)
	draw_rect(Rect2(face.position.x - 2.0, face.end.y - 6.0, face.size.x + 4.0, 6.0), PLINTH_STONE.darkened(0.25))
	var panel := face.grow_individual(-4.0, -14.0, -4.0, -10.0)
	draw_rect(panel, PLINTH_STONE.darkened(0.2))
	draw_line(Vector2(panel.position.x, panel.end.y), panel.end, PLINTH_STONE.lightened(0.1), 1.0)
	draw_rect(face, OUTLINE, false, 1.2)
	draw_rect(top, OUTLINE, false, 1.0)
	_draw_bust(top.get_center() + Vector2(0.0, 4.0))


## A classical marble bust in profile, facing left, on the plinth's top at `base` (its
## socle's foot), lit from the upper left: a turned socle, a chest cut in a curve with a toga
## slung over the left shoulder in folds and pinned by a brooch, a neck, and a head with
## sculpted curls under a laurel wreath tied at the back, its ribbons trailing.
func _draw_bust(base: Vector2) -> void:
	const SHADE := Color(0.22, 0.2, 0.3, 0.3)
	const LINE := Color(0.12, 0.1, 0.12, 0.7)
	var deep := BUST.darkened(0.3)
	draw_set_transform(base)
	# The socle: a foot slab, a waisted stem and a tablet under the chest.
	for slab: Rect2 in [Rect2(-7, -2.5, 14, 2.5), Rect2(-3, -6, 6, 3.5), Rect2(-6.5, -8, 13, 2)]:
		draw_rect(slab, BUST.darkened(0.08))
		draw_rect(Rect2(slab.end.x - slab.size.x * 0.35, slab.position.y, slab.size.x * 0.35, slab.size.y), SHADE)
		draw_rect(slab, LINE, false, 0.8)
	# The chest, its foot cut in a curve.
	var chest := PackedVector2Array([Vector2(-11, -10), Vector2(-6, -8.6), Vector2(0, -8), Vector2(6, -8.6), Vector2(11, -10),
		Vector2(13, -15), Vector2(12, -19), Vector2(8, -21), Vector2(3, -22), Vector2(-4, -22), Vector2(-9, -21),
		Vector2(-13, -18), Vector2(-13, -13)])
	draw_colored_polygon(chest, BUST)
	draw_colored_polygon(PackedVector2Array([Vector2(6, -8.6), Vector2(11, -10), Vector2(13, -15), Vector2(12, -19), Vector2(8, -21), Vector2(7, -14)]), SHADE)
	# The toga: slung from the left shoulder across to the right hip, in three folds.
	var toga := PackedVector2Array([Vector2(-13, -18), Vector2(-9, -21), Vector2(-4, -22), Vector2(4, -14), Vector2(11, -10),
		Vector2(6, -8.6), Vector2(0, -8), Vector2(-6, -8.6), Vector2(-11, -10), Vector2(-13, -13)])
	draw_colored_polygon(toga, BUST.darkened(0.04))
	for k in 3:
		var lift := k * 3.2
		draw_polyline(PackedVector2Array([Vector2(-12, -15 - lift * 0.5), Vector2(-6, -12 - lift), Vector2(1, -9.5 - lift * 0.6), Vector2(7, -9.2)]), deep, 0.9, true)
		draw_polyline(PackedVector2Array([Vector2(-12, -14.2 - lift * 0.5), Vector2(-6, -11.2 - lift), Vector2(1, -8.8 - lift * 0.6)]), BUST.lightened(0.5), 0.6, true)
	draw_polyline(PackedVector2Array([Vector2(-4, -22), Vector2(4, -14), Vector2(11, -10)]), deep, 1.0, true)
	draw_circle(Vector2(-10, -18.5), 1.6, BUST.darkened(0.15))
	draw_circle(Vector2(-10.4, -18.9), 0.6, BUST.lightened(0.5))
	draw_polyline(_closed(chest), LINE, 0.9, true)
	# The neck, shaded behind the jaw.
	var neck := PackedVector2Array([Vector2(-4, -21.5), Vector2(4, -21.5), Vector2(5, -27), Vector2(-2.5, -26.5)])
	draw_colored_polygon(neck, BUST.darkened(0.06))
	draw_colored_polygon(PackedVector2Array([Vector2(1.5, -21.5), Vector2(4, -21.5), Vector2(5, -27), Vector2(2, -26)]), SHADE)
	draw_line(Vector2(-4, -21.5), Vector2(-2.5, -26.5), LINE, 0.8, true)
	draw_line(Vector2(4, -21.5), Vector2(5, -27), LINE, 0.8, true)
	# The head in profile: skull, brow, nose, lips and chin.
	draw_set_transform(base + Vector2(0, -33))
	var head := PackedVector2Array([Vector2(0, -10), Vector2(5, -8), Vector2(7.5, -4), Vector2(7.5, 0), Vector2(5.5, 4),
		Vector2(2.5, 6.5), Vector2(-1, 8.2), Vector2(-3.5, 8.5), Vector2(-5, 7.2), Vector2(-5.2, 5.8), Vector2(-4.8, 5),
		Vector2(-5.8, 4.2), Vector2(-5.6, 3), Vector2(-7.6, 2.4), Vector2(-6.2, -1.2), Vector2(-6.4, -2.6),
		Vector2(-6, -5.5), Vector2(-3.5, -8.8)])
	draw_colored_polygon(head, BUST)
	draw_colored_polygon(PackedVector2Array([Vector2(1, 2), Vector2(4, 0), Vector2(7.5, 0), Vector2(5.5, 4), Vector2(2.5, 6.5), Vector2(-1, 8.2)]), SHADE)
	draw_line(Vector2(-6, -2.8), Vector2(-2.6, -2.3), deep, 0.9, true)
	draw_line(Vector2(-4.9, -1.2), Vector2(-3, -0.8), LINE, 0.9, true)
	draw_line(Vector2(-5.9, 2.7), Vector2(-5, 2.9), deep, 0.7, true)
	draw_line(Vector2(-5.1, 5), Vector2(-3.9, 5.3), deep, 0.7, true)
	draw_line(Vector2(-4.5, 3), Vector2(-2, 5.5), BUST.darkened(0.12), 0.8, true)
	draw_arc(Vector2(2.2, 0.6), 1.7, -PI * 0.5, PI * 0.6, 8, deep, 0.9, true)
	draw_polyline(_closed(head), LINE, 0.9, true)
	# Curls over the crown and down to the nape.
	var curls := [Vector2(-4.6, -7.4), Vector2(-2, -9.2), Vector2(1, -9.6), Vector2(4, -8.6), Vector2(6.2, -6.4),
		Vector2(7.4, -3.6), Vector2(7.6, -0.6), Vector2(6.6, 2.2), Vector2(4.6, -5), Vector2(1.6, -6.6), Vector2(4.8, -2.6)]
	for curl: Vector2 in curls:
		draw_circle(curl, 2.8, LINE)
	for curl: Vector2 in curls:
		draw_circle(curl, 2.3, BUST.darkened(0.04))
		draw_arc(curl, 1.2, 0.3, PI * 1.6, 6, deep, 0.7, true)
	# The laurel: leaves paired along a band from the brow round to a tie at the back.
	var tie := Vector2(7.6, -2.2)
	var band := PackedVector2Array()
	for k in 7:
		band.append(Vector2(-5.4, -5.6).lerp(tie, k / 6.0) + Vector2(0, -sin(k / 6.0 * PI) * 1.8))
	draw_polyline(band, deep, 1.0, true)
	for k in 6:
		for side: float in [-1.0, 1.0]:
			draw_set_transform(base + Vector2(0, -33) + band[k], (band[k + 1] - band[k]).angle() + side * 0.6, Vector2(1.0, 0.45))
			draw_circle(Vector2(1.9, 0), 2.1, BUST.darkened(0.16))
			draw_arc(Vector2(1.9, 0), 2.1, 0.0, TAU, 10, LINE, 1.2, true)
			draw_line(Vector2(0.4, 0), Vector2(3.4, 0), BUST.lightened(0.5), 0.8)
	draw_set_transform(base + Vector2(0, -33))
	draw_polyline(PackedVector2Array([tie, tie + Vector2(2.6, 4), tie + Vector2(2.2, 7.5)]), BUST.darkened(0.1), 1.3, true)
	draw_polyline(PackedVector2Array([tie, tie + Vector2(1.2, 4.5), tie + Vector2(0.4, 8)]), BUST.darkened(0.18), 1.1, true)
	draw_circle(tie, 1.3, BUST.darkened(0.15))
	draw_set_transform(Vector2.ZERO)


## Two brass stanchions at the footprint's ends with a velvet rope slung between them.
func _draw_rope(trim: Color) -> void:
	var y := -depth / 2.0
	for x: float in [-width / 2.0 + 4.0, width / 2.0 - 4.0]:
		draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.45))
		draw_circle(Vector2.ZERO, 7.0, BRASS.darkened(0.3))
		draw_set_transform(Vector2.ZERO)
		draw_rect(Rect2(x - 2.0, y - height, 4.0, height), BRASS)
		draw_line(Vector2(x - 1.0, y - height), Vector2(x - 1.0, y), BRASS.lightened(0.3), 1.0)
		draw_circle(Vector2(x, y - height - 3.0), 4.0, BRASS)
	var sag := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		sag.append(Vector2(lerpf(-width / 2.0 + 4.0, width / 2.0 - 4.0, t), y - height + 4.0 + sin(t * PI) * height * 0.35))
	draw_polyline(sag, trim.darkened(0.3), 5.0, true)
	draw_polyline(sag, trim, 3.0, true)


func _closed(points: PackedVector2Array) -> PackedVector2Array:
	points.append(points[0])
	return points
