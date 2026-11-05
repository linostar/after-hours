class_name RoomDecor
extends Node2D
## A wing room's back wall, dressed in its wing painting's style (`style`, a Paintings id;
## the room sets it with `avoid`, then adds it): the wall's own surface, a cornice along the
## top, the wainscot and skirting along the foot, and period lamps hung in the gaps between
## the paintings and whatever the gimmick draws on the wall (`avoid`, room units), each lamp
## lighting the wall and the floor below it through the room's RoomLights (`lights`).
## - pearl_earring (Vermeer): limewashed plaster, a walnut cornice, a skirting of Delft
##   tiles; brass candle sconces.
## - great_wave (Hokusai): paper wall panels in a wooden grid, a black lacquer beam, an
##   indigo dado of seigaiha waves; paper lanterns on cords from the beam (above the pipe).
## - grande_jatte (Seurat): a summer sky in dots, a white moulding, green boarding dotted
##   like the lawn; gas lamps with glass globes.
## - starry_night (Van Gogh): no wall of its own (the searchlights paint the sky there), a
##   cornice and dado of thick cobalt strokes lit yellow; café lanterns.
## - earthly_delights (Bosch): coursed ashlar, a frieze of trefoils, a blind arcade along the
##   dado; iron torches.
## - mona_lisa (the Louvre): red damask in gilt panels, a coffered gilt cornice, a veined
##   marble dado; gilt three-candle girandoles.
## Its surfaces are drawn once (seeded detail never changes); the flames (Flames child)
## redraw each frame, flickering at FLICKER_HZ, still under Reduce Motion. Drawn over the
## room's wall polygons and under the gimmick's wall features, the paintings and the lamps
## of the picture lights.

const WALL := Rect2(0, 0, 960, 130)
const WAINSCOT := Rect2(0, 130, 960, 40)
const CORNICE := 12.0
const FLICKER_HZ := 0.7
## A lamp needs this much clear wall either side of it; none hangs left of HUD_CLEAR (the
## room's HUD sits there).
const LAMP_CLEARANCE := 30.0
const HUD_CLEAR := 250.0
## How far apart two lamps in one long gap stand at least.
const LAMP_SPACING := 220.0
## Each lamp lights a patch of wall round it and a pool of floor below it.
const WALL_POOL := 52.0
const FLOOR_POOL := 80.0
const FLOOR_POOL_Y := 210.0
const POOL_LIGHT := Color(1.0, 0.82, 0.5, 0.32)
const FLOOR_LIGHT := Color(1.0, 0.82, 0.5, 0.14)
const FLAME := Color(1.0, 0.82, 0.4)
const FLAME_CORE := Color(1.0, 0.97, 0.82)
const GILT := Color(0.79, 0.64, 0.29)
const GILT_DARK := Color(0.5, 0.38, 0.16)
const INK := Color(0.08, 0.06, 0.1)
const IRON := Color(0.16, 0.15, 0.17)
const STYLES: Array[StringName] = [&"pearl_earring", &"great_wave", &"grande_jatte", &"starry_night", &"earthly_delights", &"mona_lisa"]
## Where each style's lamp hangs (the cup or flame), and its outline (lamp-local) for the
## gaps.
const LAMP_Y: Dictionary[StringName, float] = {
	&"pearl_earring": 88.0, &"great_wave": 56.0, &"grande_jatte": 84.0, &"starry_night": 84.0, &"earthly_delights": 86.0, &"mona_lisa": 62.0,
}
const LAMP_BOX := Rect2(-16, -34, 32, 58)

var style: StringName = &"pearl_earring"
var avoid: Array[Rect2] = []
var lights: RoomLights
## Where each lamp hangs (its flame), worked out on ready.
var lamps: Array[Vector2] = []
var _clock := 0.0
var _flames: Node2D


## The x of every lamp for the wall's occupied `rects` with lamps of `box` (lamp-local)
## hung at `y`: one in the middle of each clear gap wide enough, more in a long one, none
## left of HUD_CLEAR.
static func lamp_xs(rects: Array[Rect2], y: float, box: Rect2) -> Array[float]:
	var spans: Array[Vector2] = []
	var band := Rect2(0.0, y + box.position.y, WALL.size.x, box.size.y)
	for rect in rects:
		if rect.intersects(band):
			spans.append(Vector2(rect.position.x - LAMP_CLEARANCE, rect.end.x + LAMP_CLEARANCE))
	spans.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var xs: Array[float] = []
	var from := HUD_CLEAR
	spans.append(Vector2(WALL.end.x - LAMP_CLEARANCE, INF))
	for span in spans:
		var to := span.x
		var spare := to - from - box.size.x
		if spare >= 0.0:
			var count := 1 + int(spare / LAMP_SPACING)
			for k in count:
				xs.append(lerpf(from + box.size.x / 2.0, to - box.size.x / 2.0, (k + 0.5) / count) if count > 1 else (from + to) / 2.0)
		from = maxf(from, span.y)
	return xs


func _ready() -> void:
	if not style in STYLES:
		(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("RoomDecor: unknown style '%s'; the wall stays plain" % style)
		return
	var y: float = LAMP_Y[style]
	for x in lamp_xs(avoid, y, LAMP_BOX):
		lamps.append(Vector2(x, y))
	if lights != null:
		var pools: Array[Array] = []
		for lamp in lamps:
			pools.append([lamp + Vector2(0, -6), WALL_POOL, POOL_LIGHT])
			pools.append([Vector2(lamp.x, FLOOR_POOL_Y), FLOOR_POOL, FLOOR_LIGHT])
		lights.pools = pools
	_flames = Node2D.new()
	_flames.name = "Flames"
	_flames.material = preload("res://art/glow.tres")
	_flames.draw.connect(_draw_flames)
	add_child(_flames)


func _process(delta: float) -> void:
	_clock += delta
	if _flames != null:
		_flames.queue_redraw()


func _draw() -> void:
	if not style in STYLES:
		return
	var brush := RandomNumberGenerator.new()
	brush.seed = hash(style)
	match style:
		&"pearl_earring":
			_draw_vermeer(brush)
		&"great_wave":
			_draw_hokusai()
		&"grande_jatte":
			_draw_seurat(brush)
		&"starry_night":
			_draw_van_gogh(brush)
		&"earthly_delights":
			_draw_bosch()
		&"mona_lisa":
			_draw_louvre(brush)
	draw_line(Vector2(0, WAINSCOT.end.y - 0.5), Vector2(960, WAINSCOT.end.y - 0.5), INK, 1.5)
	for lamp in lamps:
		_draw_lamp(lamp)


## Vermeer: limewash brushed in soft vertical sweeps, a walnut cornice, a walnut rail over a
## skirting of Delft tiles (a sprig in each).
func _draw_vermeer(brush: RandomNumberGenerator) -> void:
	const PLASTER := Color(0.66, 0.62, 0.54)
	const WALNUT := Color(0.32, 0.21, 0.12)
	const DELFT := Color(0.2, 0.32, 0.6)
	draw_rect(WALL, PLASTER)
	for i in 160:
		var x := brush.randf_range(0.0, 960.0)
		var top := brush.randf_range(CORNICE, 90.0)
		draw_line(Vector2(x, top), Vector2(x + brush.randf_range(-3.0, 3.0), top + brush.randf_range(20.0, 50.0)), PLASTER.lightened(brush.randf_range(0.02, 0.08)), brush.randf_range(3.0, 7.0))
	draw_rect(Rect2(0, 0, 960, CORNICE), WALNUT)
	draw_rect(Rect2(0, CORNICE, 960, 3), WALNUT.lightened(0.25))
	draw_rect(Rect2(0, CORNICE + 3, 960, 2), WALNUT.darkened(0.3))
	draw_rect(WAINSCOT, Color(0.94, 0.93, 0.88))
	var tile := 20.0
	for k in int(960 / tile):
		var cell := Rect2(k * tile, WAINSCOT.position.y + 6, tile, tile)
		draw_rect(cell.grow(-1.0), DELFT, false, 1.0)
		var mid := cell.get_center()
		draw_line(mid + Vector2(0, 4), mid - Vector2(0, 3.5), DELFT, 1.2)
		draw_circle(mid - Vector2(0, 3.5), 2.0, DELFT)
		draw_line(mid, mid + Vector2(-3.5, -2), DELFT, 1.0)
		draw_line(mid + Vector2(0, 1), mid + Vector2(3.5, -1), DELFT, 1.0)
	draw_rect(Rect2(0, WAINSCOT.position.y - 2, 960, 8), WALNUT)
	draw_rect(Rect2(0, WAINSCOT.end.y - 10, 960, 10), WALNUT.darkened(0.2))


## Hokusai: paper panels in a hinoki grid, a black lacquer beam (nageshi), an indigo dado of
## seigaiha waves (rows of nested arcs).
func _draw_hokusai() -> void:
	const PAPER := Color(0.82, 0.78, 0.66)
	const HINOKI := Color(0.52, 0.38, 0.22)
	const LACQUER := Color(0.1, 0.07, 0.07)
	const INDIGO := Color(0.13, 0.19, 0.38)
	const WAVE := Color(0.62, 0.7, 0.86)
	draw_rect(WALL, PAPER)
	var panel := 80.0
	for k in int(960 / panel) + 1:
		draw_rect(Rect2(k * panel - 3, CORNICE, 6, WALL.end.y - CORNICE), HINOKI)
	for y: float in [46.0, 88.0]:
		draw_rect(Rect2(0, y - 1.5, 960, 3), HINOKI.darkened(0.15))
	draw_rect(Rect2(0, 0, 960, CORNICE + 4), LACQUER)
	draw_rect(Rect2(0, CORNICE + 4, 960, 2), HINOKI)
	draw_rect(WAINSCOT, INDIGO)
	var r := 10.0
	var row := 0
	var y0 := WAINSCOT.end.y - 2.0
	while y0 > WAINSCOT.position.y + 2.0:
		var x := -r if row % 2 == 0 else 0.0
		while x < 960.0 + r:
			for k in 3:
				draw_arc(Vector2(x, y0), r - k * 3.2, PI, TAU, 12, WAVE if k != 1 else INDIGO.lightened(0.25), 1.4, true)
			x += r * 2.0
		y0 -= r * 0.75
		row += 1
	draw_rect(Rect2(0, WAINSCOT.position.y - 3, 960, 5), LACQUER)


## Seurat: a pale summer sky laid in dots, a white plaster moulding, green boarding dotted
## like the lawn under a white rail.
func _draw_seurat(brush: RandomNumberGenerator) -> void:
	const SKY := Color(0.6, 0.68, 0.8)
	const SKY_DOTS: Array[Color] = [Color(0.75, 0.82, 0.92), Color(0.9, 0.86, 0.7), Color(0.52, 0.6, 0.78), Color(0.85, 0.72, 0.75)]
	const GREEN := Color(0.22, 0.4, 0.24)
	const LAWN_DOTS: Array[Color] = [Color(0.35, 0.55, 0.28), Color(0.6, 0.7, 0.3), Color(0.15, 0.3, 0.2), Color(0.85, 0.75, 0.35)]
	draw_rect(WALL, SKY)
	for i in 1400:
		draw_circle(Vector2(brush.randf_range(0, 960), brush.randf_range(CORNICE, WALL.end.y)), brush.randf_range(0.9, 1.5), SKY_DOTS[brush.randi() % SKY_DOTS.size()])
	draw_rect(Rect2(0, 0, 960, CORNICE), Color(0.9, 0.88, 0.82))
	draw_rect(Rect2(0, CORNICE, 960, 2), Color(0.6, 0.6, 0.58))
	draw_rect(WAINSCOT, GREEN)
	for i in 900:
		draw_circle(Vector2(brush.randf_range(0, 960), brush.randf_range(WAINSCOT.position.y + 4, WAINSCOT.end.y - 2)), brush.randf_range(0.9, 1.4), LAWN_DOTS[brush.randi() % LAWN_DOTS.size()])
	for x in range(0, 960, 24):
		draw_line(Vector2(x, WAINSCOT.position.y + 4), Vector2(x, WAINSCOT.end.y), GREEN.darkened(0.35), 1.0)
	draw_rect(Rect2(0, WAINSCOT.position.y - 2, 960, 6), Color(0.9, 0.88, 0.82))


## Van Gogh: the sky is the searchlights' own; a cornice and a dado of thick cobalt strokes
## following a slow flow, their rails lit yellow.
func _draw_van_gogh(brush: RandomNumberGenerator) -> void:
	const BLUES: Array[Color] = [Color(0.12, 0.18, 0.42), Color(0.2, 0.3, 0.6), Color(0.08, 0.12, 0.3), Color(0.3, 0.42, 0.72)]
	const LAMP_YELLOW := Color(0.95, 0.78, 0.3)
	draw_rect(Rect2(0, 0, 960, CORNICE), BLUES[2])
	draw_rect(WAINSCOT, BLUES[2])
	for band: Rect2 in [Rect2(0, 0, 960, CORNICE), WAINSCOT]:
		for i in int(band.get_area() / 18.0):
			var at := Vector2(brush.randf_range(0, 960), brush.randf_range(band.position.y + 2, band.end.y - 2))
			var flow := Vector2.from_angle(sin(at.x * 0.05) * 0.7) * brush.randf_range(5.0, 8.0)
			draw_line(at, at + flow, BLUES[brush.randi() % BLUES.size()], 2.4, true)
	draw_rect(Rect2(0, CORNICE, 960, 2.5), LAMP_YELLOW)
	draw_rect(Rect2(0, WAINSCOT.position.y - 2, 960, 3), LAMP_YELLOW)


## Bosch: coursed ashlar (offset joints), a frieze of trefoils under a stone cornice, a blind
## arcade of pointed arches along the dado.
func _draw_bosch() -> void:
	const STONE := Color(0.5, 0.46, 0.4)
	const JOINT := Color(0.32, 0.29, 0.25)
	const DEEP := Color(0.2, 0.17, 0.16)
	draw_rect(WALL, STONE)
	var course := 22.0
	var y := CORNICE + 14.0
	var row := 0
	while y < WALL.end.y:
		draw_line(Vector2(0, y), Vector2(960, y), JOINT, 1.2)
		var x := 0.0 if row % 2 == 0 else 30.0
		while x < 960.0:
			draw_line(Vector2(x, y), Vector2(x, minf(y + course, WALL.end.y)), JOINT, 1.0)
			x += 60.0
		y += course
		row += 1
	draw_rect(Rect2(0, 0, 960, CORNICE), STONE.darkened(0.2))
	draw_rect(Rect2(0, CORNICE, 960, 14), STONE.lightened(0.08))
	for x in range(10, 960, 24):
		var c := Vector2(x, CORNICE + 7)
		for a: float in [-PI / 2.0, PI / 6.0, PI * 5.0 / 6.0]:
			draw_circle(c + Vector2.from_angle(a) * 2.6, 2.4, DEEP)
	draw_rect(Rect2(0, CORNICE + 14, 960, 2), JOINT)
	draw_rect(WAINSCOT, STONE.darkened(0.12))
	var arch := 32.0
	for x in range(0, 960, int(arch)):
		var left := x + 5.0
		var right := x + arch - 5.0
		var base := WAINSCOT.end.y - 4.0
		var spring := WAINSCOT.position.y + 18.0
		var apex := Vector2((left + right) / 2.0, WAINSCOT.position.y + 6.0)
		var niche := PackedVector2Array([Vector2(left, base), Vector2(left, spring), apex, Vector2(right, spring), Vector2(right, base)])
		draw_colored_polygon(niche, DEEP)
		niche.append(niche[0])
		draw_polyline(niche, STONE.lightened(0.15), 1.2)


## The Louvre: red damask (a sown fleuron) in gilt-framed panels, a coffered gilt cornice, a
## veined marble dado under a gilt rail.
func _draw_louvre(brush: RandomNumberGenerator) -> void:
	const DAMASK := Color(0.42, 0.08, 0.1)
	const DAMASK_FIGURE := Color(0.52, 0.13, 0.14)
	const MARBLE := Color(0.82, 0.8, 0.75)
	const VEIN := Color(0.55, 0.52, 0.5)
	draw_rect(WALL, DAMASK)
	var step := 24.0
	for row in int(WALL.size.y / step) + 1:
		for col in int(960 / step) + 1:
			var c := Vector2(col * step + (step / 2.0 if row % 2 == 1 else 0.0), CORNICE + 10 + row * step)
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -6), c + Vector2(4, 0), c + Vector2(0, 6), c + Vector2(-4, 0)]), DAMASK_FIGURE)
			draw_circle(c + Vector2(0, -8), 1.3, DAMASK_FIGURE)
	var panel := 240.0
	for k in 4:
		draw_rect(Rect2(k * panel + 8, CORNICE + 10, panel - 16, WALL.end.y - CORNICE - 20), GILT_DARK, false, 2.0)
	draw_rect(Rect2(0, 0, 960, CORNICE + 4), GILT_DARK)
	for x in range(0, 960, 20):
		draw_rect(Rect2(x + 3, 2, 14, CORNICE - 2), GILT)
		draw_rect(Rect2(x + 6, 5, 8, CORNICE - 8), GILT_DARK)
	draw_rect(Rect2(0, CORNICE + 4, 960, 2), GILT)
	draw_rect(WAINSCOT, MARBLE)
	for i in 26:
		var at := Vector2(brush.randf_range(0, 960), brush.randf_range(WAINSCOT.position.y + 4, WAINSCOT.end.y - 4))
		var points := PackedVector2Array([at])
		for k in 4:
			at += Vector2(brush.randf_range(8, 18), brush.randf_range(-5, 5))
			points.append(Vector2(at.x, clampf(at.y, WAINSCOT.position.y + 3, WAINSCOT.end.y - 3)))
		draw_polyline(points, VEIN, 0.8, true)
	draw_rect(Rect2(0, WAINSCOT.position.y - 3, 960, 5), GILT)


## The lamp's fixture at `at` (its flame's foot), in its style; the flame is drawn by Flames.
func _draw_lamp(at: Vector2) -> void:
	match style:
		&"great_wave":
			const PAPER := Color(0.95, 0.88, 0.7)
			draw_line(Vector2(at.x, CORNICE + 6), at + Vector2(0, -22), INK, 1.2)
			draw_rect(Rect2(at + Vector2(-7, -22), Vector2(14, 4)), INK)
			draw_rect(Rect2(at + Vector2(-7, 14), Vector2(14, 4)), INK)
			var body := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				body.append(at + Vector2(-11.0 * sin(PI * (0.15 + 0.7 * t)), lerpf(-18.0, 14.0, t)))
			for i in 13:
				var t := 1.0 - i / 12.0
				body.append(at + Vector2(11.0 * sin(PI * (0.15 + 0.7 * t)), lerpf(-18.0, 14.0, t)))
			draw_colored_polygon(body, PAPER)
			for k in range(-12, 14, 6):
				draw_line(at + Vector2(-9.5, k), at + Vector2(9.5, k), Color(0.7, 0.5, 0.3, 0.7), 0.8)
			draw_circle(at + Vector2(0, -2), 4.0, Color(0.75, 0.15, 0.12))
		&"grande_jatte":
			draw_polyline(PackedVector2Array([at + Vector2(0, 20), at + Vector2(-10, 14), at + Vector2(-8, 4), at + Vector2(0, 2)]), IRON, 2.4, true)
			draw_rect(Rect2(at + Vector2(-5, 0), Vector2(10, 3)), IRON)
			draw_circle(at + Vector2(0, -9), 9.0, Color(0.95, 0.95, 0.88, 0.85))
			draw_arc(at + Vector2(0, -9), 9.0, 0.0, TAU, 20, IRON, 1.2, true)
		&"starry_night":
			draw_polyline(PackedVector2Array([at + Vector2(14, -26), at + Vector2(0, -26), at + Vector2(0, -20)]), IRON, 2.4, true)
			var cage := PackedVector2Array([at + Vector2(-8, -20), at + Vector2(8, -20), at + Vector2(6, 8), at + Vector2(-6, 8)])
			draw_colored_polygon(cage, Color(0.98, 0.82, 0.35))
			cage.append(cage[0])
			draw_polyline(cage, IRON, 2.0, true)
			draw_line(at + Vector2(0, -20), at + Vector2(0, 8), IRON, 1.2)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -20), at + Vector2(0, -28), at + Vector2(10, -20)]), IRON)
		&"earthly_delights":
			draw_polyline(PackedVector2Array([at + Vector2(0, 22), at + Vector2(-9, 12), at + Vector2(-3, 4)]), IRON, 3.0, true)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-6, 0), at + Vector2(6, 0), at + Vector2(3, 8), at + Vector2(-3, 8)]), IRON)
		&"mona_lisa":
			draw_polyline(PackedVector2Array([at + Vector2(0, 22), at + Vector2(0, 6)]), GILT, 3.0, true)
			draw_arc(at + Vector2(0, 2), 12.0, 0.0, PI, 12, GILT, 2.2, true)
			for dx: float in [-12.0, 0.0, 12.0]:
				draw_rect(Rect2(at + Vector2(dx - 3, -2), Vector2(6, 3)), GILT)
				draw_rect(Rect2(at + Vector2(dx - 1.5, -10), Vector2(3, 8)), Color(0.95, 0.92, 0.82))
		_:
			draw_polyline(PackedVector2Array([at + Vector2(0, 20), at + Vector2(-8, 14), at + Vector2(-6, 6), at + Vector2(0, 4)]), GILT, 2.0, true)
			draw_rect(Rect2(at.x - 7, at.y + 2, 14, 4), GILT)
			draw_rect(Rect2(at.x - 2, at.y - 8, 4, 10), Color(0.95, 0.92, 0.82))


## Every lamp's flame (or glowing heart), flickering unless Reduce Motion stills it.
func _draw_flames() -> void:
	var calm := GameState.reduce_motion_for(self)
	for at in lamps:
		var flicker := 0.0 if calm else sin(TAU * FLICKER_HZ * _clock + at.x * 0.05)
		match style:
			&"great_wave":
				_flames.draw_circle(at + Vector2(0, -2), 9.0 + flicker, Color(1.0, 0.75, 0.4, 0.35))
			&"grande_jatte":
				_flames.draw_circle(at + Vector2(0, -9), 5.0 + flicker * 0.6, FLAME_CORE)
				_flames.draw_circle(at + Vector2(0, -9), 7.5 + flicker, Color(FLAME, 0.5))
			&"starry_night":
				_flames.draw_circle(at + Vector2(0, -6), 4.5 + flicker * 0.6, FLAME_CORE)
			&"mona_lisa":
				for dx: float in [-12.0, 0.0, 12.0]:
					_flame(at + Vector2(dx, -10), flicker, 0.8)
			&"earthly_delights":
				_flame(at, flicker, 1.8)
			_:
				_flame(at + Vector2(0, -8), flicker, 1.0)


## A candle's flame at `foot`, `size` times a candle's.
func _flame(foot: Vector2, flicker: float, size: float) -> void:
	var tip := foot + Vector2(flicker * 0.8, (-9.0 - flicker) * size)
	_flames.draw_colored_polygon(PackedVector2Array([foot + Vector2(-2.8 * size, 0), tip, foot + Vector2(2.8 * size, 0)]), FLAME)
	_flames.draw_circle(foot + Vector2(0, -1.5 * size), 2.6 * size, FLAME)
	_flames.draw_circle(foot + Vector2(0, -1.5 * size), 1.3 * size, FLAME_CORE)
