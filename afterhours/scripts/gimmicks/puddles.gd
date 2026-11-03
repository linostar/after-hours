class_name Puddles
extends Gimmick
## Wing 2 (Hokusai), and part of the finale: burst pipes. A water pipe runs along the back
## wall; at each burst water pours down onto the floor in a widening stream, where its puddle
## (a flat ellipse, the 3/4 view) spreads while the pipe gushes and dries back to a damp
## patch (DAMP of its full size) while it only drips, in a steady rhythm of its own. In a
## puddle the mime wades (SLOW of its speed) and every step splashes (LOUD: heard across
## the whole hearing range); guards wade at SLOW too (Guard asks slow_at for its own spot).
## Drawn as a Hokusai woodblock print (muted Prussian tones, cream foam, indigo key-block
## ink and spray), in three layers: the iron pipe on the wall (flanges, wall
## brackets, each burst a torn hole with its metal peeled back; behind the paintings), the
## puddles on the floor (a darker wet sheen, a soft inked rim, the water shading from deep in the middle,
## a highlight crescent, foam lace and lapping splashes on the rim, ripples spreading from where the
## water lands), and the falling water (in front of the paintings, behind the actors: a
## ribboned stream with streaks speeding down it, thinning in and out with the gush, a crown
## of foam crests and drops flung on ballistic arcs where it lands; between gushes drops that
## swell, stretch, fall and burst). Every pipe moves on its own offsets. All of it is
## decoration: each cycle repeats under 2 Hz and stands still under
## Reduce Motion. A pipe whose data is broken (no beat, a period or radius not above 0) is
## reported and left out.

const SLOW := 0.55
const LOUD := 1.0
## The share of a puddle's full size left between gushes.
const DAMP := 0.25
## A puddle's height over its width (the floor seen at 3/4).
const FLATTEN := 0.5
const PIPE_Y := 112.0
const PIPE_RADIUS := 6.0
const FLANGE_RADIUS := 9.5
## The print's palette (after the Great Wave): Prussian blue in three muted, faded tones
## (the puddles shade smoothly between them), cream foam (the paper, never pure white),
## indigo key-block ink, and iron.
const PRUSSIAN_DEEP := Color("2e4259")
const PRUSSIAN := Color("4a6280")
const PRUSSIAN_LIGHT := Color("8099b0")
## The puddle's gradient: rings from the deep middle out to the rim.
const SHADE_RINGS := 7
const INK := Color("141a33")
const FOAM := Color("f3ecd8")
## The darker sheen of wet floor round a puddle.
const WET := Color(0.08, 0.1, 0.2, 0.16)
const IRON := Color(0.4, 0.45, 0.52)
const IRON_LIGHT := Color(0.63, 0.68, 0.75)
const IRON_DARK := Color(0.24, 0.27, 0.34)
## The falling stream lets the room show through a little: it is water in the air.
const STREAM_ALPHA := 0.9
## Absolute z: the wall pipe just above the walls (under the paintings at -9), the falling
## water above the paintings and the fake's icon (-8), under the actors (0).
const PIPE_Z := -10
const SPRAY_Z := -7
const BRACKET_GAP := 160.0
## The stream's width where it lands, as a share of the puddle's radius.
const STREAM_SPREAD := 0.3
const SPLASH_DROPS := 9
const CROWN_SPIKES := 9
const RIPPLES := 3
## How fast a stream thins in and out at the start and end of its gush (a share of the gush).
const GUSH_EASE := 0.06
## A stream thinner than this (a share of full) is not drawn.
const MIN_FLOW := 0.1
## Where in its cycle (0..1) a drip lands.
const DRIP_LAND := 0.82
## Decorative cycles per second (all under the 2 Hz flash limit): drips forming, falling and
## bursting; splash drops' flights (the slowest drop flies 0.8x as often, the fastest 1.25x);
## the crown's crests rising and falling; the mouth's jets and the rim splashes' lapping; the streaks flowing down the
## stream (each lane 0.7x to 1x of it); the ripples spreading; the stream's ribbons waving and
## the puddle's bands shimmering.
const DRIP_HZ := 0.8
const SPLASH_HZ := 0.9
const CROWN_HZ := 0.7
const FOAM_HZ := 0.4
const FLOW_HZ := 1.4
const RIPPLE_HZ := 0.6
const WAVE_HZ := 0.5
const SHIMMER_HZ := 0.2

## Per burst: the puddle's centre (floor) and full radius (x, y, radius); the pipe bursts
## above it, on the back wall.
@export var puddles := PackedVector3Array()
## Per burst: seconds per gush-and-dry rhythm and where in it the room starts (0 dry,
## 0.5 at full size).
@export var beats := PackedVector2Array()

var _time := 0.0
var _pipe: Node2D
var _spray: Node2D


func _ready() -> void:
	for i in puddles.size():
		if not usable(i):
			(get_node(GameState.AUTOLOAD_PATH) as GameState).report_error("Puddles at %s: pipe %d is left out (puddle %s, beat %s): it needs a beat with a period above 0 and a radius above 0" % [get_path(), i, puddles[i], str(beats[i]) if i < beats.size() else "missing"])
	_pipe = _layer(PIPE_Z, _draw_pipe)
	_spray = _layer(SPRAY_Z, _draw_spray)


func _layer(z: int, drawing: Callable) -> Node2D:
	var layer := Node2D.new()
	layer.z_as_relative = false
	layer.z_index = z
	layer.draw.connect(drawing)
	add_child(layer)
	return layer


## Whether pipe `i` has what it needs: a beat with a period above 0, a radius above 0.
func usable(i: int) -> bool:
	return i < beats.size() and beats[i].x > 0.0 and puddles[i].z > 0.0


## How full puddle `i` is now: 0 (damp patch) to 1 (full size).
func level(i: int) -> float:
	return (1.0 - cos(TAU * (_time / beats[i].x + beats[i].y))) / 2.0


## Whether pipe `i` gushes now (its puddle is growing) rather than dripping.
func gushing(i: int) -> bool:
	return fposmod(_time / beats[i].x + beats[i].y, 1.0) < 0.5


## Puddle `i`'s radius across now.
func radius(i: int) -> float:
	return puddles[i].z * lerpf(DAMP, 1.0, level(i))


## Whether `point` is in a puddle now.
func wet(point: Vector2) -> bool:
	for i in puddles.size():
		if not usable(i):
			continue
		var r := radius(i)
		var offset := point - Vector2(puddles[i].x, puddles[i].y)
		if (offset.x / r) ** 2 + (offset.y / (r * FLATTEN)) ** 2 <= 1.0:
			return true
	return false


func slow_at(point: Vector2) -> float:
	return SLOW if wet(point) else 1.0


func noise_at(point: Vector2) -> float:
	return LOUD if wet(point) else 0.0


func noise_sound(_point: Vector2) -> StringName:
	return &"splash"


## Moves time on; a pipe that starts gushing sounds its burst.
func tick(delta: float) -> void:
	var was: Array[bool] = []
	for i in puddles.size():
		was.append(usable(i) and gushing(i))
	_time += delta
	for i in puddles.size():
		if usable(i) and gushing(i) and not was[i]:
			Audio.play_for(self, &"pipe_burst")
	queue_redraw()
	if _spray != null:
		_spray.queue_redraw()


## A per-pipe offset so no two pipes or puddles move in step.
func _seed(i: int) -> float:
	return fposmod(puddles[i].x * 0.0131 + puddles[i].y * 0.0077 + i * 0.37, 1.0)


## A steady pseudo-random 0..1 for pipe `i`'s `k`-th thing (a drop's arc, a crest's height).
static func _hash(i: int, k: int) -> float:
	return fposmod(sin(i * 12.9898 + k * 78.233) * 43758.5453, 1.0)


## How far into its gush pipe `i` is (0..1), or -1 while it drips.
func _gush(i: int) -> float:
	var at := fposmod(_time / beats[i].x + beats[i].y, 1.0)
	return at * 2.0 if at < 0.5 else -1.0


## The stream's strength: thinning in at the start of a gush and out at its end.
func _flow(i: int) -> float:
	var g := _gush(i)
	if g < 0.0:
		return 0.0
	return smoothstep(0.0, GUSH_EASE, g) * (1.0 - smoothstep(1.0 - GUSH_EASE, 1.0, g))


## The puddles, on the floor: a darker wet sheen round each, a soft inked rim, the water
## shading smoothly from deep in the middle to light at the rim (the far-left shelf lit), a
## cream highlight crescent, a foam lace and spray dots along the near rim, splashes lapping
## up round the rim, and ripples spreading from where the water lands (the stream, or each
## drip).
func _draw() -> void:
	var t := flourish(_time)
	for i in puddles.size():
		if not usable(i):
			continue
		var offset := _seed(i)
		var centre := Vector2(puddles[i].x, puddles[i].y)
		var r := radius(i)
		var shimmer := t * SHIMMER_HZ + offset
		draw_colored_polygon(_ellipse(centre + Vector2(0.0, 2.0), r * 1.22 + 6.0, 0.05, shimmer, offset), WET)
		draw_colored_polygon(_ellipse(centre + Vector2(0.0, 1.0), r * 1.08 + 3.0, 0.05, shimmer, offset + 1.0), WET)
		draw_colored_polygon(_ellipse(centre, r + 1.5, 0.025, shimmer, offset), Color(INK, 0.55))
		_shade(centre, r, shimmer, offset)
		_crescent(centre, r, offset)
		_ripples(i, centre, r, t)
		_lace(centre, r, t, offset)
		var splashes := maxi(3, int(r / 16.0))
		for k in splashes:
			_rim_splash(i, k, centre, r, TAU * (k + 0.5 + (_hash(i, k) - 0.5) * 0.5) / splashes, t)


## The water's body: SHADE_RINGS rings from the deep middle (a little toward the near side)
## out to the rim, drawn as quads with a colour at each corner so the tones blend: deep in
## the middle, mid across, lighter at the rim, and lighter still on the far-left shelf where
## the room's light falls.
func _shade(centre: Vector2, r: float, shimmer: float, offset: float) -> void:
	var middle := centre + Vector2(r * 0.07, r * FLATTEN * 0.12)
	var rings: Array[PackedVector2Array] = []
	var tones: Array[PackedColorArray] = []
	for k in SHADE_RINGS + 1:
		var f := float(k) / SHADE_RINGS
		var ring := _ellipse(middle.lerp(centre, f), r * f, 0.025 * f, shimmer, offset)
		var depth := PRUSSIAN_DEEP.lerp(PRUSSIAN, smoothstep(0.0, 0.7, f)).lerp(PRUSSIAN_LIGHT, smoothstep(0.6, 1.0, f) * 0.35)
		var tone := PackedColorArray()
		for m in ring.size():
			var angle := TAU * m / ring.size()
			var lit := pow(0.5 + 0.5 * cos(angle - PI * 1.25), 2.0) * smoothstep(0.25, 0.9, f) * 0.55
			tone.append(depth.lerp(PRUSSIAN_LIGHT, lit))
		rings.append(ring)
		tones.append(tone)
	for k in SHADE_RINGS:
		var inner := rings[k]
		var outer := rings[k + 1]
		for m in inner.size():
			var n := (m + 1) % inner.size()
			draw_primitive(PackedVector2Array([inner[m], inner[n], outer[n], outer[m]]), PackedColorArray([tones[k][m], tones[k][n], tones[k + 1][n], tones[k + 1][m]]), PackedVector2Array())


## The highlight: a cream crescent on the far-left shelf, tapered at both ends.
func _crescent(centre: Vector2, r: float, offset: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var from := PI * (1.08 + offset * 0.05)
	var to := PI * 1.52
	for k in 13:
		var u := float(k) / 12.0
		var angle := lerpf(from, to, u)
		var dir := Vector2(cos(angle), sin(angle) * FLATTEN)
		outer.append(centre + dir * r * 0.86)
		inner.append(centre + Vector2(r * 0.03, r * FLATTEN * 0.06) + dir * r * lerpf(0.86, 0.74, sin(PI * u)))
	inner.reverse()
	draw_colored_polygon(outer + inner, Color(FOAM, 0.55))


## Rings spreading over puddle `i` from where its water lands, eased out and fading: a few
## at a time while it gushes, one per drip while it drips.
func _ripples(i: int, centre: Vector2, r: float, t: float) -> void:
	var rings: Array[float] = []
	var flow := _flow(i)
	if flow > 0.0:
		for k in RIPPLES:
			rings.append(fposmod(t * RIPPLE_HZ + float(k) / RIPPLES + _seed(i), 1.0))
	else:
		# A drip lands at DRIP_LAND of its cycle; its ring spreads over the next 70 %.
		# and a fainter one follows it out.
		var age := fposmod(t * DRIP_HZ + _seed(i) - DRIP_LAND, 1.0) / 0.7
		for lag: float in [0.0, 0.22]:
			if age - lag >= 0.0 and age - lag < 1.0:
				rings.append(age - lag)
	for age in rings:
		var spread := 1.0 - (1.0 - age) * (1.0 - age)
		var ring := _ellipse(centre, lerpf(3.0, r * 0.85, spread))
		ring.append(ring[0])
		var fade := (1.0 - age) * (1.0 - age) * (flow if flow > 0.0 else 1.0)
		draw_polyline(ring, Color(FOAM, 0.75 * fade), lerpf(1.8, 0.8, age), true)


## Splash `k` of puddle `i` at `angle` round its rim, on its own beat: a cream wavelet
## laps up along the rim and settles back, flinging three droplets out on arcs. Full
## while the pipe gushes, smaller while it drips.
func _rim_splash(i: int, k: int, centre: Vector2, r: float, angle: float, t: float) -> void:
	var u := fposmod(t * SPLASH_HZ * lerpf(0.55, 0.85, _hash(i, k + 300)) + _hash(i, k + 320), 1.0)
	var rise := sin(PI * u)
	var size := lerpf(0.45, 1.0, _flow(i)) * (3.0 + r * 0.05)
	var height := size * 0.75 * rise
	if height < 0.8:
		return
	# The wavelet: a low swell of water over an arc of the rim, its back rounded, highest a
	# little past the middle, foam riding its crest.
	var span := (10.0 + size * 3.0) / r
	var crest := PackedVector2Array()
	var foot := PackedVector2Array()
	for m in 13:
		var s := float(m) / 12.0
		var a := angle + span * (s - 0.5)
		var on_rim := centre + Vector2(cos(a), sin(a) * FLATTEN) * r
		crest.append(on_rim + Vector2(0.0, -height * pow(sin(PI * s), 1.6) * lerpf(0.85, 1.0, s)))
		foot.append(on_rim + Vector2(0.0, 0.8))
	# A strip of quads, foot to crest: the swell thins to slivers at its ends, which a
	# polygon triangulation rejects.
	var body := PackedColorArray()
	body.resize(4)
	body.fill(PRUSSIAN_LIGHT)
	for m in 12:
		draw_primitive(PackedVector2Array([foot[m], foot[m + 1], crest[m + 1], crest[m]]), body, PackedVector2Array())
	draw_polyline(crest, INK, 2.8, true)
	draw_polyline(crest.slice(2, 11), Color(FOAM, lerpf(0.6, 1.0, rise)), 1.8, true)
	# Droplets thrown off the crest: outward from the puddle and up, falling back as it settles.
	var out := Vector2(cos(angle), sin(angle) * FLATTEN)
	var top := centre + out * r + Vector2(0.0, -height)
	for d in 3:
		var spread := (d - 1.0) * 0.6
		var reach := size * lerpf(1.2, 2.2, _hash(i, k * 3 + d + 340))
		var at := top + (out + out.orthogonal() * spread).normalized() * reach * u + Vector2(0.0, -size * 4.8 * u * (1.0 - u) + size * u)
		_bead(at, lerpf(1.8, 0.8, u) * (1.0 if d == 1 else 0.8), (1.0 - u) * 0.9, self)


## Spray fanning out of the burst while it gushes: tapered jets each side, lengthening and
## shortening on their own beats.
func _mouth_spray(i: int, burst: Vector2, t: float, flow: float) -> void:
	for side: float in [-1.0, 1.0]:
		for j in 3:
			var aim := Vector2(side, 0.0).rotated(side * lerpf(0.15, 1.05, j / 2.0))
			var pulse := 0.5 + 0.5 * sin(TAU * (t * FOAM_HZ * lerpf(0.8, 1.2, _hash(i, j + 360)) + _hash(i, j + 380) + side * 0.25))
			var length := (7.0 + 5.0 * _hash(i, j + 400)) * lerpf(0.65, 1.0, pulse) * flow
			var root := burst + Vector2(side * 2.5, 1.0)
			var tip := root + aim * length
			var across := aim.orthogonal() * lerpf(2.2, 1.4, j / 2.0) * flow
			var jet := PackedVector2Array([root - across, root.lerp(tip, 0.5) - across * 0.6, tip, root.lerp(tip, 0.5) + across * 0.6, root + across])
			_spray.draw_colored_polygon(jet, PRUSSIAN_LIGHT)
			jet.append(jet[0])
			_spray.draw_polyline(jet, INK, 1.0, true)
			_spray.draw_line(root, root.lerp(tip, 0.8), Color(FOAM, 0.9), 1.0, true)


## Foam along the near rim: broken cream dashes drifting slowly round, and spray dots.
func _lace(centre: Vector2, r: float, t: float, offset: float) -> void:
	var dashes := maxi(3, int(r / 12.0))
	for k in dashes:
		var from := PI * (0.08 + 0.84 * (k + 0.15 * sin(TAU * (t * FOAM_HZ * 0.5 + offset + k * 0.21))) / dashes)
		draw_polyline(spiral(centre, r * 0.9, r * 0.9, from, PI * 0.45 / dashes, FLATTEN, 5), FOAM, 1.4, true)
	for k in dashes + 2:
		var angle := PI * (0.05 + 0.9 * (k + 0.5) / (dashes + 2))
		var at := centre + Vector2(cos(angle), sin(angle) * FLATTEN) * r * (1.02 + 0.06 * sin(k * 2.3 + offset * 9.0))
		draw_circle(at, 1.1 + 0.5 * fposmod(k * 0.618 + offset, 1.0), FOAM)


## The iron pipe along the wall: inked, lit along its top; flanges at its joints, brackets
## strapping it to the wall, and the torn burst above each usable puddle.
func _draw_pipe() -> void:
	if puddles.is_empty():
		return
	var top := PIPE_Y - PIPE_RADIUS
	_pipe.draw_rect(Rect2(0.0, top - 1.5, Content.BASE.x, PIPE_RADIUS * 2.0 + 3.0), INK)
	_pipe.draw_rect(Rect2(0.0, top, Content.BASE.x, PIPE_RADIUS * 2.0), IRON)
	_pipe.draw_rect(Rect2(0.0, top + 1.5, Content.BASE.x, 2.5), IRON_LIGHT)
	_pipe.draw_rect(Rect2(0.0, PIPE_Y + PIPE_RADIUS - 3.0, Content.BASE.x, 2.0), IRON_DARK)
	var x := BRACKET_GAP / 2.0
	while x < Content.BASE.x:
		_bracket(x)
		_flange(x + BRACKET_GAP / 2.0)
		x += BRACKET_GAP
	for i in puddles.size():
		if usable(i):
			_burst(Vector2(puddles[i].x, PIPE_Y))


## A strap round the pipe, screwed to a plate on the wall above.
func _bracket(x: float) -> void:
	var top := PIPE_Y - PIPE_RADIUS
	_pipe.draw_rect(Rect2(x - 7.0, top - 13.0, 14.0, 5.5), INK)
	_pipe.draw_rect(Rect2(x - 5.5, top - 11.5, 11.0, 2.5), IRON_DARK)
	_pipe.draw_rect(Rect2(x - 4.0, top - 9.0, 8.0, PIPE_RADIUS * 2.0 + 10.5), INK)
	_pipe.draw_rect(Rect2(x - 2.5, top - 8.0, 5.0, PIPE_RADIUS * 2.0 + 8.5), IRON)
	_pipe.draw_rect(Rect2(x - 2.5, top - 8.0, 1.5, PIPE_RADIUS * 2.0 + 8.5), IRON_LIGHT)
	for side: float in [-4.0, 4.0]:
		_pipe.draw_circle(Vector2(x + side, top - 10.2), 1.2, IRON_LIGHT)


## A joint's flange: a collar wider than the pipe with a bolt top and bottom.
func _flange(x: float) -> void:
	if x >= Content.BASE.x:
		return
	_pipe.draw_rect(Rect2(x - 4.5, PIPE_Y - FLANGE_RADIUS - 1.5, 9.0, FLANGE_RADIUS * 2.0 + 3.0), INK)
	_pipe.draw_rect(Rect2(x - 3.0, PIPE_Y - FLANGE_RADIUS, 6.0, FLANGE_RADIUS * 2.0), IRON)
	_pipe.draw_rect(Rect2(x - 3.0, PIPE_Y - FLANGE_RADIUS, 1.5, FLANGE_RADIUS * 2.0), IRON_LIGHT)
	for side: float in [-1.0, 1.0]:
		_pipe.draw_circle(Vector2(x, PIPE_Y + side * (FLANGE_RADIUS - 2.2)), 1.3, INK)


## The burst: a torn, inked hole with dark water inside, its iron peeled back in curling
## flaps.
func _burst(at: Vector2) -> void:
	var hole := PackedVector2Array()
	for k in 12:
		var angle := TAU * k / 12.0
		var reach := 1.0 if k % 2 == 0 else 0.62
		hole.append(at + Vector2(cos(angle) * 9.0, sin(angle) * (PIPE_RADIUS + 1.0)) * reach)
	_pipe.draw_colored_polygon(hole, INK)
	_pipe.draw_colored_polygon(_ellipse(at + Vector2(0.0, 1.0), 4.5), PRUSSIAN_DEEP)
	# Each flap: its angle out of the hole, its length and which way its tip curls.
	for flap: Vector3 in [Vector3(-2.4, 10.0, -1.0), Vector3(-0.7, 11.0, 1.0), Vector3(2.2, 8.0, -1.0), Vector3(0.8, 9.0, 1.0)]:
		var out := Vector2.from_angle(flap.x)
		var across := out.orthogonal() * 3.2
		var base := at + out * Vector2(8.0, PIPE_RADIUS)
		var tip := base + out * flap.y
		var curl := tip + across.normalized() * flap.z * 3.0 - out * 1.5
		# Round the outline in order: the curl sits on the side it bends to.
		var petal := PackedVector2Array([base - across, tip, curl, base + across] if flap.z > 0.0 else [base - across, curl, tip, base + across])
		_pipe.draw_colored_polygon(petal, IRON)
		petal.append(petal[0])
		_pipe.draw_polyline(petal, INK, 1.5, true)
		_pipe.draw_line(base, tip, IRON_LIGHT, 1.0, true)


## The water falling from each burst. Gushing: a ribboned stream (deep, mid and light bands
## waving down it, inked edges) thinning in and out with the gush, cream streaks speeding
## down it, jets and spray fanning from the mouth, and where it lands a crown of foam crests
## (the far ones behind the stream, the near ones in front) and drops flying out on
## ballistic arcs, each on its own timing. Dripping: a drop swells under the burst,
## stretches, falls faster and faster and bursts into a small crown where it lands.
func _draw_spray() -> void:
	var t := flourish(_time)
	for i in puddles.size():
		if not usable(i):
			continue
		var centre := Vector2(puddles[i].x, puddles[i].y)
		var burst := Vector2(centre.x, PIPE_Y + 3.0)
		var flow := _flow(i)
		if flow <= 0.0:
			_drip(i, burst, centre, t)
		# The first and last instants of a gush are too thin to draw (and to triangulate).
		if flow < MIN_FLOW:
			continue
		var spread := puddles[i].z * STREAM_SPREAD * lerpf(0.5, 1.0, flow)
		_crown(i, centre, spread, t, flow, true)
		_stream(i, burst, centre, spread, t, flow)
		_crown(i, centre, spread, t, flow, false)
		_mouth_spray(i, burst, t, flow)
		for k in 4:
			var u := fposmod(t * SPLASH_HZ * 0.9 + k * 0.25 + _seed(i), 1.0)
			var side := -1.0 if k % 2 == 0 else 1.0
			# Spray off the mouth: a short hop out and down the wall.
			_bead(burst + Vector2(side * (5.0 + 12.0 * u), 2.0 - 20.0 * u * (1.0 - u) + 8.0 * u), 1.6 * (1.0 - u) + 0.4, 1.0 - u)
		for d in SPLASH_DROPS:
			_flying_drop(i, d, centre, spread, t, flow)


## The stream from `burst` to `centre`: three bands, each a ribbon whose middle waves down it.
func _stream(i: int, burst: Vector2, centre: Vector2, spread: float, t: float, flow: float) -> void:
	var offset := _seed(i)
	var mouth := 4.5 * flow
	# Each band: its width share, its shift toward the lit (left) side, colour.
	var bands: Array[Array] = [[1.0, 0.0, Color(PRUSSIAN_DEEP, STREAM_ALPHA)], [0.62, -0.22, Color(PRUSSIAN, STREAM_ALPHA)], [0.26, -0.42, Color(PRUSSIAN_LIGHT, STREAM_ALPHA)]]
	var steps := 24
	for band: Array in bands:
		var left := PackedVector2Array()
		var right := PackedVector2Array()
		for k in steps + 1:
			var v := float(k) / steps
			var half := lerpf(mouth, spread, pow(v, 1.3)) * float(band[0])
			var wave := sin(TAU * (v * 1.4 - t * WAVE_HZ + offset + float(band[0]))) * (0.6 + 2.2 * v) * flow
			var mid := burst.lerp(centre, v) + Vector2(wave + float(band[1]) * lerpf(mouth, spread, pow(v, 1.3)), 0.0)
			left.append(mid - Vector2(half, 0.0))
			right.append(mid + Vector2(half, 0.0))
		var edge := right.duplicate()
		edge.reverse()
		_spray.draw_colored_polygon(left + edge, band[2])
		if band[0] == 1.0:
			_spray.draw_polyline(left, INK, 1.6, true)
			_spray.draw_polyline(right, INK, 1.6, true)
	# Streaks: cream lines speeding down (falling, so each accelerates and stretches), each
	# lane at its own pace so they never march in step.
	for lane in 5:
		var across := lerpf(-0.62, 0.55, lane / 4.0)
		var pace := lerpf(0.7, 1.0, _hash(i, lane + 20))
		for k in 3:
			var f := fposmod(t * FLOW_HZ * pace + k / 3.0 + _hash(i, lane), 1.0)
			var from := f * f
			var to := minf(from + 0.04 + 0.14 * f, 1.0)
			var line := PackedVector2Array()
			for m in 4:
				var v := lerpf(from, to, m / 3.0)
				var half := lerpf(mouth, spread, pow(v, 1.3))
				var wave := sin(TAU * (v * 1.4 - t * WAVE_HZ + offset + 1.0)) * (0.6 + 2.2 * v) * flow
				line.append(burst.lerp(centre, v) + Vector2(wave + across * half, 0.0))
			_spray.draw_polyline(line, Color(FOAM, sin(PI * f) * 0.95), 1.3, true)


## The crown where the stream lands: on the far side a churning cream ring of white water
## (drawn first), then a sheet of water thrown up round the landing ring, flaring outward,
## its rim scalloped into CROWN_SPIKES rounded lobes that each rise and fall on their own
## beat, a bead flung off each peak; `far` draws the far half (behind the stream), else the
## near half (in front of it).
func _crown(i: int, centre: Vector2, spread: float, t: float, flow: float, far: bool) -> void:
	var ring := spread * 1.1
	if far:
		var churn := _ellipse(centre, ring * 1.05, 0.12, t * WAVE_HZ + _seed(i), _seed(i))
		_spray.draw_colored_polygon(churn, Color(FOAM, 0.9 * flow))
		churn.append(churn[0])
		_spray.draw_polyline(churn, Color(INK, flow), 1.2, true)
		_spray.draw_colored_polygon(_ellipse(centre, ring * 0.7, 0.1, t * WAVE_HZ * 0.8, _seed(i) + 2.0), Color(PRUSSIAN_LIGHT, flow))
	# Each lobe's peak: its angle round the ring and its height now.
	var peaks: Array[Vector2] = []
	for k in CROWN_SPIKES:
		var rise := 0.5 + 0.5 * sin(TAU * (t * CROWN_HZ + _hash(i, k + 60)))
		peaks.append(Vector2(TAU * (k + 0.3 * _hash(i, k + 40)) / CROWN_SPIKES, (9.0 + 9.0 * _hash(i, k + 80)) * (0.3 + 0.7 * rise) * flow))
	var lobe := TAU / CROWN_SPIKES * 0.2
	# The sheet over the half ring: its rim (the lobes' heights summed, flared outward as it
	# rises) and its foot on the ring.
	var rim := PackedVector2Array()
	var foot := PackedVector2Array()
	var from := PI if far else 0.0
	var steps := 36
	for m in steps + 1:
		var a := from + PI * m / steps
		var lift := 0.0
		for peak in peaks:
			var gap := angle_difference(a, peak.x) / lobe
			lift += peak.y * exp(-gap * gap)
		# Taper to nothing where the half ring meets the stream's sides.
		lift *= sin(PI * m / steps) ** 0.5
		var out := Vector2(cos(a), sin(a) * FLATTEN)
		foot.append(centre + out * ring)
		rim.append(centre + out * (ring + lift * 0.9) + Vector2(0.0, -lift))
	# Drawn as a strip of quads, foot to rim: the sheet thins to slivers between the lobes and
	# at its ends, which a polygon triangulation rejects. Its upper share is cream foam.
	var water := PackedColorArray()
	water.resize(4)
	water.fill(Color(PRUSSIAN_LIGHT, flow))
	var foam := PackedColorArray()
	foam.resize(4)
	foam.fill(Color(FOAM, 0.95 * flow))
	for m in steps:
		var froth_a := rim[m].lerp(foot[m], 0.35)
		var froth_b := rim[m + 1].lerp(foot[m + 1], 0.35)
		_spray.draw_primitive(PackedVector2Array([foot[m], foot[m + 1], froth_b, froth_a]), water, PackedVector2Array())
		_spray.draw_primitive(PackedVector2Array([froth_a, froth_b, rim[m + 1], rim[m]]), foam, PackedVector2Array())
	_spray.draw_polyline(rim, Color(INK, flow), 1.2, true)
	for peak in peaks:
		if (sin(peak.x) < 0.0) != far or peak.y < 3.0:
			continue
		var out := Vector2(cos(peak.x), sin(peak.x) * FLATTEN)
		var top := centre + out * (ring + peak.y * 0.9) + Vector2(0.0, -peak.y)
		_bead(top + out * peak.y * 0.3 + Vector2(0.0, -2.0 - peak.y * 0.25), 0.9 + peak.y * 0.07, flow)


## Splash drop `d` of pipe `i`: flung from the landing ring on a parabola (constant speed
## across, rising and falling under gravity), its own pace and launch so none move together.
func _flying_drop(i: int, d: int, centre: Vector2, spread: float, t: float, flow: float) -> void:
	var pace := lerpf(0.8, 1.25, _hash(i, d + 120))
	var u := fposmod(t * SPLASH_HZ * pace + _hash(i, d + 140), 1.0)
	var side := -1.0 if d % 2 == 0 else 1.0
	var start := centre + Vector2(side * spread * lerpf(0.4, 1.0, _hash(i, d + 160)), lerpf(-2.0, 3.0, _hash(i, d + 180)))
	var across := side * lerpf(10.0, 34.0, _hash(i, d + 200)) * flow
	var apex := lerpf(10.0, 30.0, _hash(i, d + 220)) * flow
	var at := start + Vector2(across * u, -4.0 * apex * u * (1.0 - u) + 5.0 * u)
	var size := lerpf(2.6, 1.2, u) * lerpf(0.7, 1.15, _hash(i, d + 240))
	_bead(at, size, 1.0 - smoothstep(0.8, 1.0, u))


## A drip's cycle under the burst: it swells (0 to 0.35), stretches and falls, faster and
## faster, to the puddle (to DRIP_LAND) and bursts into a small crown and two flecks.
func _drip(i: int, burst: Vector2, centre: Vector2, t: float) -> void:
	var q := fposmod(t * DRIP_HZ + _seed(i), 1.0)
	if q < 0.35:
		var swell := q / 0.35
		var size := lerpf(1.0, 3.2, swell)
		var hang := burst + Vector2(0.0, 2.0 + size * (0.6 + swell))
		_spray.draw_colored_polygon(PackedVector2Array([burst + Vector2(-1.4, 0.0), burst + Vector2(1.4, 0.0), hang + Vector2(size * 0.8, 0.0), hang + Vector2(-size * 0.8, 0.0)]), INK)
		_water_bead(hang, size)
	elif q < DRIP_LAND:
		var f := (q - 0.35) / (DRIP_LAND - 0.35)
		var at := burst.lerp(centre, f * f)
		var tail := 2.0 + 10.0 * f
		var size := 3.0
		_spray.draw_colored_polygon(PackedVector2Array([at + Vector2(-size - 0.8, 0.0), at + Vector2(0.0, -size - tail), at + Vector2(size + 0.8, 0.0)]), INK)
		_spray.draw_colored_polygon(PackedVector2Array([at + Vector2(-size, 0.0), at + Vector2(0.0, -size - tail + 1.5), at + Vector2(size, 0.0)]), PRUSSIAN_LIGHT)
		_water_bead(at, size)
	else:
		var b := (q - DRIP_LAND) / (1.0 - DRIP_LAND)
		var rise := sin(PI * b)
		for k in 4:
			var side := -1.0 if k < 2 else 1.0
			var base := centre + Vector2(side * (2.0 + 2.5 * (k % 2)), 0.0)
			var tip := base + Vector2(side * (1.5 + 2.0 * (k % 2)), -(3.0 + 3.0 * ((k + 1) % 2)) * rise)
			_spray.draw_colored_polygon(PackedVector2Array([base - Vector2(1.4, 0.0), tip, base + Vector2(1.4, 0.0)]), FOAM)
		for side: float in [-1.0, 1.0]:
			_bead(centre + Vector2(side * 10.0 * b, -4.0 * 7.0 * b * (1.0 - b)), 1.3, 1.0 - b)


## A drop of spray: a cream bead ringed in ink, `alpha` see-through, on `canvas` (the
## falling-water layer unless given).
func _bead(at: Vector2, r: float, alpha: float, canvas: CanvasItem = null) -> void:
	if alpha <= 0.0:
		return
	var on := canvas if canvas != null else _spray
	on.draw_circle(at, r + 0.9, Color(INK, alpha))
	on.draw_circle(at, r, Color(FOAM, alpha))


## A falling drop of water: a blue bead ringed in ink with a cream glint.
func _water_bead(at: Vector2, r: float) -> void:
	_spray.draw_circle(at, r + 0.9, INK)
	_spray.draw_circle(at, r, PRUSSIAN_LIGHT)
	_spray.draw_circle(at - Vector2(r, r) * 0.3, r * 0.4, FOAM)


## A flat ellipse's outline points around `centre`, `r` across; `wobble` (a share of r)
## ripples its edge in slow waves at `phase` (cycles), offset by `offset`.
func _ellipse(centre: Vector2, r: float, wobble := 0.0, phase := 0.0, offset := 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for k in 40:
		var angle := TAU * k / 40.0
		var rr := r
		if wobble > 0.0:
			rr *= 1.0 + wobble * (sin(3.0 * angle + TAU * phase + offset * 5.0) * 0.6 + sin(5.0 * angle - TAU * phase * 0.7 + offset * 9.0) * 0.4)
		points.append(centre + Vector2(cos(angle) * rr, sin(angle) * rr * FLATTEN))
	return points
