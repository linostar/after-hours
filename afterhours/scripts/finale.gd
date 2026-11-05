class_name Finale
extends Node2D
## The wordless ending (Game.Flow.FINALE), about 26 seconds in three comic beats, all drawn:
## 1. Morning in the museum (Louvre walls, RoomDecor; sunbeams on the parquet): the watchman
##    and the rookie walk the gallery and stop under each of the six hanging fakes in turn; a
##    "?" pops over them and a fidget (the pocket watch, a yawn, a stretch) passes it, until the
##    Mona Lisa's fake wobbles and slips crooked on its nail and they double-take: at it, at
##    each other, back at it, "!" and a hop.
## 2. An iris to the hideout (HideoutDecor): all six stolen originals hang gilded and alive
##    through their styles; the mime strolls in, admires them, turns to the camera, tips its
##    beret and bows as confetti bursts.
## 3. Icon credits inside a great gilt frame (the jam's theme, great works of art): a
##    clapperboard-and-megaphone medallion for the human director, a brush-and-spark one for
##    Claude, the AI that built the game, a heart between, then the six paintings as
##    thumbnails, their artists told by their art alone.
## Then the screen change to Game.finale_return (the hub after the escape that finished every
## wing, the hideout after its replay). A tap, ui_accept on the focused skip button, E or Space
## skips straight there. Under Reduce Motion the cuts fade, the wobble, the hops and the
## confetti are stilled and the spark holds still.

## The beats' timing (seconds).
const WALK_TIME := 0.7
const STOP_TIME := 1.3
const REACT_AT := 0.4
const ICON_POP := 0.2
const WIPE_TIME := 0.35
const SLIP_TIME := 0.6
const LOOK_TIME := 0.4
const HOP_TIME := 0.3
const DISCOVERY_HOLD := 1.4
const STROLL_TIME := 1.6
const ADMIRE_TIME := 1.6
const TIP_TIME := 1.2
const BOW_TIME := 1.4
const BOW_HOLD := 0.8
const MARK_POP := 0.35
const THUMB_GAP := 0.25
const CREDITS_HOLD := 2.2
## The whole ending, unskipped (the tests wait this long, plus the screen change).
const LENGTH := 6.0 * WALK_TIME + 5.0 * STOP_TIME + REACT_AT + SLIP_TIME + 2.0 * LOOK_TIME + HOP_TIME + DISCOVERY_HOLD \
		+ 4.0 * WIPE_TIME + STROLL_TIME + ADMIRE_TIME + TIP_TIME + BOW_TIME + BOW_HOLD + 3.0 * MARK_POP + 6.0 * THUMB_GAP + CREDITS_HOLD

## The gallery: where the six fakes hang (centres, Content.WINGS order) and their frames
## (portrait for the two portraits).
const GALLERY_XS: Array[float] = [110.0, 258.0, 406.0, 554.0, 702.0, 850.0]
const GALLERY_Y := 74.0
const LANDSCAPE := Vector2(124, 88)
const PORTRAIT := Vector2(78, 100)
## The Mona Lisa fake's slip on its nail: its final tilt and drop, and the wobble before.
const SLIP_ANGLE := 0.32
const SLIP_DROP := 7.0
const WOBBLES: Array[float] = [0.07, -0.05, 0.03]
## The guards: the watchman's line across the floor, the rookie a step behind him, where
## they come in from, and their hop of surprise.
const PATROL_Y := 262.0
const ROOKIE_BEHIND := Vector2(-58, 36)
const ENTER_X := -90.0
const HOP := 16.0
## Over a guard's head: the "?" and the "!" (as Guard's intent icons).
const ICON_ABOVE := Vector2(0, -152)
const ICON_SCALE := 0.6
const QUERY := preload("res://art/svg/icon_query.svg")
const ALARM := preload("res://art/svg/icon_alarm.svg")
## Each passed fake's fidgets: [watchman, rookie].
const PASSES: Array[Array] = [
	[CharacterRig.Fidget.WATCH, CharacterRig.Fidget.YAWN],
	[CharacterRig.Fidget.YAWN, CharacterRig.Fidget.STRETCH],
	[CharacterRig.Fidget.STRETCH, CharacterRig.Fidget.WATCH],
	[CharacterRig.Fidget.WATCH, CharacterRig.Fidget.YAWN],
	[CharacterRig.Fidget.YAWN, CharacterRig.Fidget.STRETCH],
]
## The morning: the wall's colour under the decor, the parquet, the sunbeams.
const WALL := Color(0.36, 0.3, 0.22)
const FLOOR_TILE := preload("res://art/svg/floor_parquet.svg")
const SUN := Color(1.0, 0.94, 0.75, 0.09)
## The velvet rope's foot line and colour, and the bench's seat line.
const ROPE_Y := 205.0
const ROPE := Color(0.6, 0.1, 0.14)
const BENCH_Y := 430.0
## The hideout: the mime's way in and its spot on the rug.
const MIME_FROM := Vector2(1010, 384)
const MIME_AT := Vector2(480, 384)
const PLANKS := preload("res://art/svg/floor_planks.svg")
const BURST_AT := Vector2(480, 230)
## The credits: the great frame, its velvet, the two medallions, the heart, the thumbnails.
const FRAME := Rect2(110, 30, 740, 480)
const MOULDING := 18.0
const GILT := Color(0.79, 0.64, 0.29)
const GILT_DARK := Color(0.5, 0.38, 0.16)
const GILT_LIGHT := Color(0.95, 0.83, 0.5)
const VELVET := Color(0.2, 0.07, 0.1)
const INK := Color(0.08, 0.06, 0.1)
const CHALK := Color(0.95, 0.93, 0.88)
const CLAUDE := Color(0.85, 0.47, 0.34)
const MEDAL_RADIUS := 70.0
const DIRECTOR_AT := Vector2(330, 185)
const CLAUDE_AT := Vector2(630, 185)
const HEART_AT := Vector2(480, 190)
const THUMB_Y := 395.0
const THUMB_GAP_X := 106.0
const THUMB := Vector2(90, 70)
## The spark by Claude's brush twinkles (held still under Reduce Motion).
const SPARK_HZ := 0.8

## The watchman and the rookie, and the mime (CharacterRig each).
var watchman: CharacterRig
var rookie: CharacterRig
var mime: CharacterRig
## The six fakes in the gallery and the six originals in the hideout (Content.WINGS order).
var fakes: Array[FramedPainting] = []
var originals: Array[FramedPainting] = []
## The credits' thumbnails.
var thumbs: Array[FramedPainting] = []
## The beat playing: 0 the museum, 1 the hideout, 2 the credits.
var beat := 0
## Whether it has ended (skipped or played out) and is changing screens.
var finished := false
var _timeline: Tween
var _swing: Node2D
var _icons: Dictionary[CharacterRig, Sprite2D] = {}
var _last_x: Dictionary[CharacterRig, float] = {}
var _marks: Array[Node2D] = []
var _clock := 0.0

@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState
@onready var _museum: Node2D = $Museum
@onready var _hideout: Node2D = $Hideout
@onready var _credits: Node2D = $Credits
@onready var _confetti: Confetti = $Confetti
@onready var _cover: ColorRect = $CoverLayer/Cover
@onready var _skip: Button = $SkipButton


func _ready() -> void:
	(_cover.material as ShaderMaterial).set_shader_parameter("fade", _game.setting("reduce_motion"))
	_build_museum()
	_build_hideout()
	_build_credits()
	($FloorInput as FloorInput).tapped.connect(func(_at: Vector2) -> void: skip())
	var keys := $KeyboardInput as KeyboardInput
	keys.interacted.connect(skip)
	keys.pause_pressed.connect(skip)
	_skip.pressed.connect(skip)
	_skip.grab_focus()
	_play()
	_game.arrive(GameState.Flow.FINALE)
	print("[Finale] Plays for %.1f s, then back to %s" % [LENGTH, GameState.Flow.keys()[_game.finale_return]])


## Ends the ending now (a tap, ui_accept, E or Space): the screen change to finale_return.
## Ignored while the screen change into the finale still runs (Game.goto would ignore it).
func skip() -> void:
	if finished or _game.is_transitioning():
		return
	print("[Finale] Skipped in beat %d" % beat)
	_finish()


func _finish() -> void:
	finished = true
	_timeline.kill()
	_game.goto(_game.finale_return)


func _process(delta: float) -> void:
	_clock += delta
	for rig: CharacterRig in [watchman, rookie, mime]:
		var moved := rig.position.x - _last_x[rig]
		_last_x[rig] = rig.position.x
		if absf(moved) > 0.01:
			rig.face(Vector2(signf(moved), 0.0))
		rig.walk(absf(moved), delta, false)
	for rig: CharacterRig in _icons:
		_icons[rig].position = rig.position + ICON_ABOVE
	if beat == 2:
		_marks[1].queue_redraw()


## The whole ending as one timeline.
func _play() -> void:
	_timeline = create_tween()
	var still := _game.setting("reduce_motion")
	# The museum: a stop under each fake.
	for i in fakes.size():
		var x := GALLERY_XS[i]
		_timeline.tween_property(watchman, "position:x", x, WALK_TIME)
		_timeline.parallel().tween_property(rookie, "position:x", x + ROOKIE_BEHIND.x, WALK_TIME)
		_timeline.tween_callback(_look_up)
		_timeline.tween_callback(_pop_icons.bind(QUERY))
		_timeline.tween_interval(REACT_AT)
		if i < PASSES.size():
			_timeline.tween_callback(_pass.bind(i))
			_timeline.tween_interval(STOP_TIME - REACT_AT)
	# The Mona Lisa's fake slips and the guards double-take.
	_timeline.tween_callback(_slip.bind(still))
	_timeline.tween_interval(SLIP_TIME)
	_timeline.tween_callback(_look_at_each_other)
	_timeline.tween_interval(LOOK_TIME)
	_timeline.tween_callback(_look_up)
	_timeline.tween_interval(LOOK_TIME)
	_timeline.tween_callback(_discover.bind(still))
	_timeline.tween_interval(HOP_TIME + DISCOVERY_HOLD)
	_wipe_to(1)
	# The hideout: the mime admires the six originals, tips its beret and bows.
	_timeline.tween_property(mime, "position:x", MIME_AT.x, STROLL_TIME)
	_timeline.tween_callback(_face.bind(mime, Vector2.UP))
	_timeline.tween_interval(ADMIRE_TIME)
	_timeline.tween_callback(_face.bind(mime, Vector2.DOWN))
	_timeline.tween_callback(mime.start_fidget.bind(CharacterRig.Fidget.TIP, TIP_TIME))
	_timeline.tween_callback(Audio.play_for.bind(self, &"escape"))
	_timeline.tween_interval(TIP_TIME)
	_timeline.tween_callback(_bow.bind(still))
	_timeline.tween_interval(BOW_TIME + BOW_HOLD)
	_wipe_to(2)
	# The credits: the two makers, then the six paintings.
	for k in _marks.size():
		_timeline.tween_callback(_pop.bind(_marks[k], 1.0, k))
		_timeline.tween_interval(MARK_POP)
	for i in thumbs.size():
		_timeline.tween_callback(_pop.bind(thumbs[i], 1.0, i + _marks.size()))
		_timeline.tween_interval(THUMB_GAP)
	_timeline.tween_interval(CREDITS_HOLD)
	_timeline.tween_callback(_end)


func _end() -> void:
	print("[Finale] Played to its end")
	_finish()


## A cut to beat `to` behind the iris (a fade under Reduce Motion).
func _wipe_to(to: int) -> void:
	_timeline.tween_property(_cover, "color:a", 1.0, WIPE_TIME)
	_timeline.tween_callback(_show_beat.bind(to))
	_timeline.tween_property(_cover, "color:a", 0.0, WIPE_TIME)


func _show_beat(to: int) -> void:
	beat = to
	_museum.visible = to == 0
	_hideout.visible = to == 1
	_credits.visible = to == 2
	_confetti.age = -1.0
	_confetti.queue_redraw()
	for icon: Sprite2D in _icons.values():
		icon.hide()
	print("[Finale] Beat %d" % to)


func _look_up() -> void:
	_face(watchman, Vector2.UP)
	_face(rookie, Vector2.UP)


func _look_at_each_other() -> void:
	_face(watchman, Vector2.LEFT)
	_face(rookie, Vector2.RIGHT)
	for icon: Sprite2D in _icons.values():
		icon.hide()


## Turns `rig` to `heading`, its last move counted (the tween's final step lands after
## _process, which would turn it back the way it walked).
func _face(rig: CharacterRig, heading: Vector2) -> void:
	_last_x[rig] = rig.position.x
	rig.face(heading)


func _pop_icons(texture: Texture2D) -> void:
	for icon: Sprite2D in _icons.values():
		icon.texture = texture
		icon.show()
		_pop(icon, ICON_SCALE, -1)
	Audio.play_for(self, &"guard_suspect" if texture == QUERY else &"guard_alert")


## Fake `i` passes: the "?" goes and each guard fidgets.
func _pass(i: int) -> void:
	for icon: Sprite2D in _icons.values():
		icon.hide()
	var fidgets: Array = PASSES[i]
	watchman.start_fidget(fidgets[0], STOP_TIME - REACT_AT + WALK_TIME * 0.5)
	rookie.start_fidget(fidgets[1], STOP_TIME - REACT_AT + WALK_TIME * 0.5)


## The Mona Lisa's fake wobbles on its nail and slips crooked (straight to crooked when `still`).
func _slip(still: bool) -> void:
	var slip := create_tween()
	if not still:
		for wobble in WOBBLES:
			slip.tween_property(_swing, "rotation", wobble, SLIP_TIME / 6.0).set_trans(Tween.TRANS_SINE)
	slip.tween_property(_swing, "rotation", SLIP_ANGLE, SLIP_TIME / 2.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	slip.parallel().tween_property(_swing, "position:y", _swing.position.y + SLIP_DROP, SLIP_TIME / 2.0).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	for icon: Sprite2D in _icons.values():
		icon.hide()
	Audio.play_for(self, &"tilt")


## They know: "!" over both, the found-fake sting and line, and a hop (none when `still`).
func _discover(still: bool) -> void:
	_pop_icons(ALARM)
	Audio.play_for(self, &"fake_found")
	_game.audio.say(Audio.GUARD_VOICES[0], &"found_fake")
	if still:
		return
	for rig: CharacterRig in [watchman, rookie]:
		var hop := create_tween()
		hop.tween_property(rig, "position:y", rig.position.y - HOP, HOP_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop.tween_property(rig, "position:y", rig.position.y, HOP_TIME / 2.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## The mime's bow to the camera, and the confetti (lying still when `still`).
func _bow(still: bool) -> void:
	mime.start_fidget(CharacterRig.Fidget.BOW, BOW_TIME)
	_confetti.burst(BURST_AT, still)
	Audio.play_for(self, &"confetti")


## Pops `node` in to `to` scale; a credit's pop (`k` 0 and up) rings a rising star.
func _pop(node: Node2D, to: float, k: int) -> void:
	node.show()
	node.scale = Vector2.ZERO
	create_tween().tween_property(node, "scale", Vector2.ONE * to, ICON_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if k >= 0:
		Audio.play_for(self, &"star", pow(2.0, k * 2.0 / 12.0))


func _rig(path: String, at: Vector2, parent: Node2D) -> CharacterRig:
	var rig := (load(path) as PackedScene).instantiate() as CharacterRig
	rig.position = at
	parent.add_child(rig)
	_last_x[rig] = at.x
	return rig


## The gallery at morning: the Louvre's damask wall, the six fakes, parquet and sunbeams, the
## two guards coming in from the left.
func _build_museum() -> void:
	var wall := Polygon2D.new()
	wall.color = WALL
	wall.polygon = PackedVector2Array([Vector2(0, 0), Vector2(960, 0), Vector2(960, 170), Vector2(0, 170)])
	_museum.add_child(wall)
	var floor_tiles := Polygon2D.new()
	floor_tiles.texture = FLOOR_TILE
	floor_tiles.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	floor_tiles.polygon = PackedVector2Array([Vector2(0, 170), Vector2(960, 170), Vector2(960, 540), Vector2(0, 540)])
	_museum.add_child(floor_tiles)
	var decor := RoomDecor.new()
	decor.style = &"mona_lisa"
	var rects: Array[Rect2] = []
	for i in Paintings.IDS.size():
		rects.append(_gallery_rect(i))
	decor.avoid = rects
	_museum.add_child(decor)
	var sun := Node2D.new()
	sun.draw.connect(_draw_floor.bind(sun))
	_museum.add_child(sun)
	for i in Paintings.IDS.size():
		var rect := _gallery_rect(i)
		var fake := FramedPainting.new()
		fake.name = "Fake%d" % (i + 1)
		fake.size = rect.size
		fake.painting = Paintings.IDS[i]
		if i == Paintings.IDS.size() - 1:
			# Hung from a nail at its top, so it can slip.
			_swing = Node2D.new()
			_swing.position = Vector2(rect.get_center().x, rect.position.y)
			fake.position = Vector2(0, rect.size.y / 2.0)
			_swing.add_child(fake)
			_museum.add_child(_swing)
		else:
			fake.position = rect.get_center()
			_museum.add_child(fake)
		fakes.append(fake)
	watchman = _rig("res://scenes/rig_guard.tscn", Vector2(ENTER_X, PATROL_Y), _museum)
	# Nearer the camera, so drawn over the watchman.
	rookie = _rig("res://scenes/rig_guard.tscn", Vector2(ENTER_X, PATROL_Y) + ROOKIE_BEHIND, _museum)
	for rig: CharacterRig in [watchman, rookie]:
		var icon := Sprite2D.new()
		icon.hide()
		icon.z_index = 5
		_museum.add_child(icon)
		_icons[rig] = icon


func _gallery_rect(i: int) -> Rect2:
	var size := PORTRAIT if Paintings.IDS[i] in [&"pearl_earring", &"mona_lisa"] else LANDSCAPE
	return Rect2(Vector2(GALLERY_XS[i], GALLERY_Y) - size / 2.0, size)


## Morning sun slanting in from the left across the floor, a velvet rope on brass
## stanchions keeping visitors off the wall, and a bench in the middle of the gallery.
func _draw_floor(sun: Node2D) -> void:
	for k in 3:
		var x := 140.0 + k * 300.0
		sun.draw_colored_polygon(PackedVector2Array([Vector2(x, 170), Vector2(x + 90, 170), Vector2(x + 250, 540), Vector2(x + 80, 540)]), SUN)
	var posts: Array[float] = []
	for k in 9:
		posts.append(40.0 + k * 110.0)
	for k in posts.size() - 1:
		var sag := PackedVector2Array()
		for j in 9:
			var t := j / 8.0
			sag.append(Vector2(lerpf(posts[k], posts[k + 1], t), ROPE_Y - 26.0 + sin(t * PI) * 10.0))
		sun.draw_polyline(sag, ROPE, 4.0, true)
	for x in posts:
		sun.draw_set_transform(Vector2(x, ROPE_Y), 0.0, Vector2(1.0, 0.35))
		sun.draw_circle(Vector2.ZERO, 9.0, GILT_DARK)
		sun.draw_set_transform(Vector2.ZERO)
		sun.draw_line(Vector2(x, ROPE_Y), Vector2(x, ROPE_Y - 28.0), GILT, 4.0)
		sun.draw_circle(Vector2(x, ROPE_Y - 29.0), 4.0, GILT_LIGHT)
	# The bench: a padded seat on four legs.
	for leg: float in [-70.0, -60.0, 60.0, 70.0]:
		sun.draw_line(Vector2(480.0 + leg, BENCH_Y), Vector2(480.0 + leg, BENCH_Y + 24.0), INK, 4.0)
	sun.draw_rect(Rect2(400, BENCH_Y - 14.0, 160, 16), ROPE)
	sun.draw_rect(Rect2(400, BENCH_Y - 14.0, 160, 16), INK, false, 2.0)
	sun.draw_rect(Rect2(396, BENCH_Y + 2.0, 168, 6), GILT_DARK)


## The hideout with every original stolen: its lair, the six gilded originals and the mime
## at the door.
func _build_hideout() -> void:
	var planks := Polygon2D.new()
	planks.color = Color(0.8, 0.78, 0.8)
	planks.texture = PLANKS
	planks.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	planks.polygon = PackedVector2Array([Vector2(0, 200), Vector2(960, 200), Vector2(960, 540), Vector2(0, 540)])
	_hideout.add_child(planks)
	var decor := HideoutDecor.new()
	decor.stolen.assign(Paintings.IDS.map(func(_id: StringName) -> bool: return true))
	_hideout.add_child(decor)
	for i in Paintings.IDS.size():
		var original := FramedPainting.new()
		original.name = "Original%d" % (i + 1)
		original.size = Hideout.FRAME_SIZE
		original.position = Vector2(Hideout.FIRST_X + i * Hideout.GAP, Hideout.FRAME_Y)
		original.painting = Paintings.IDS[i]
		_hideout.add_child(original)
		originals.append(original)
	mime = _rig("res://scenes/rig_mime.tscn", MIME_FROM, _hideout)


## The credits: the great frame, the makers' medallions (hidden until they pop in) and the
## six thumbnails.
func _build_credits() -> void:
	_credits.draw.connect(_draw_credits)
	for at: Vector2 in [DIRECTOR_AT, CLAUDE_AT]:
		var mark := Node2D.new()
		mark.position = at
		mark.hide()
		mark.draw.connect(_draw_mark.bind(mark, at == CLAUDE_AT))
		_credits.add_child(mark)
		_marks.append(mark)
	var heart := Node2D.new()
	heart.position = HEART_AT
	heart.hide()
	heart.draw.connect(_draw_heart.bind(heart))
	_credits.add_child(heart)
	_marks.append(heart)
	for i in Paintings.IDS.size():
		var thumb := FramedPainting.new()
		thumb.name = "Thumb%d" % (i + 1)
		thumb.size = THUMB
		thumb.painting = Paintings.IDS[i]
		thumb.position = Vector2(480.0 + (i - 2.5) * THUMB_GAP_X, THUMB_Y)
		thumb.hide()
		_credits.add_child(thumb)
		thumbs.append(thumb)


## The great gilt frame (the jam's theme) round a velvet field, a rosette at each corner.
func _draw_credits() -> void:
	_credits.draw_rect(FRAME, GILT)
	_credits.draw_rect(FRAME.grow(-MOULDING), VELVET)
	_credits.draw_rect(FRAME, GILT_DARK, false, 3.0)
	_credits.draw_rect(FRAME.grow(-MOULDING * 0.45), GILT_LIGHT, false, 2.0)
	_credits.draw_rect(FRAME.grow(-MOULDING), INK, false, 3.0)
	for corner: Vector2 in [FRAME.position, Vector2(FRAME.end.x, FRAME.position.y), Vector2(FRAME.position.x, FRAME.end.y), FRAME.end]:
		var at := corner + (FRAME.get_center() - corner).sign() * MOULDING / 2.0
		_credits.draw_circle(at, 14.0, GILT)
		_credits.draw_circle(at, 14.0, GILT_DARK, false, 2.0)
		for k in 8:
			_credits.draw_circle(at + Vector2.from_angle(TAU * k / 8.0) * 9.0, 2.6, GILT_LIGHT)
		_credits.draw_circle(at, 4.0, GILT_DARK)
	# A gilt rule between the makers and the paintings.
	_credits.draw_line(Vector2(240, 300), Vector2(720, 300), GILT_DARK, 2.0)
	_credits.draw_circle(Vector2(480, 300), 4.0, GILT)


## A maker's medallion: the director's clapperboard and megaphone, or (`claude`) Claude's
## brush and spark.
func _draw_mark(mark: Node2D, claude: bool) -> void:
	mark.draw_circle(Vector2.ZERO, MEDAL_RADIUS, Color(0.12, 0.1, 0.16))
	mark.draw_circle(Vector2.ZERO, MEDAL_RADIUS, GILT, false, 5.0)
	mark.draw_circle(Vector2.ZERO, MEDAL_RADIUS - 8.0, GILT_DARK, false, 1.5)
	if claude:
		_draw_brush(mark)
	else:
		_draw_clapper(mark)


func _draw_clapper(mark: Node2D) -> void:
	# The slate, its lines, and the striped clapper raised on its hinge.
	var slate := Rect2(-44, -8, 56, 40)
	mark.draw_rect(slate, INK)
	mark.draw_rect(slate, CHALK, false, 2.0)
	for k in 3:
		mark.draw_line(Vector2(-38, 6 + k * 9), Vector2(6, 6 + k * 9), Color(CHALK, 0.6), 1.5)
	mark.draw_set_transform(Vector2(-44, -10), -0.42)
	mark.draw_rect(Rect2(0, -10, 56, 10), CHALK)
	for k in 4:
		var x := 4.0 + k * 14.0
		mark.draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 7, 0), Vector2(x + 13, -10), Vector2(x + 6, -10)]), INK)
	mark.draw_rect(Rect2(0, -10, 56, 10), INK, false, 1.5)
	mark.draw_set_transform(Vector2.ZERO)
	mark.draw_rect(Rect2(-44, -10, 56, 4), CHALK)
	mark.draw_circle(Vector2(-42, -9), 3.0, GILT)
	# The megaphone, its bell up and to the right.
	var cone := PackedVector2Array([Vector2(16, 8), Vector2(22, 16), Vector2(48, -6), Vector2(36, -26)])
	mark.draw_colored_polygon(cone, CLAUDE.lerp(Color(0.85, 0.2, 0.2), 0.6))
	mark.draw_polyline(PackedVector2Array([cone[0], cone[1], cone[2], cone[3], cone[0]]), INK, 2.0, true)
	mark.draw_line(Vector2(19, 12), Vector2(14, 22), INK, 5.0, true)
	# Two sound arcs from the bell.
	for k in 2:
		mark.draw_arc(Vector2(42, -16), 12.0 + k * 8.0, -1.2, 0.5, 10, Color(CHALK, 0.8 - k * 0.3), 2.0, true)


func _draw_brush(mark: Node2D) -> void:
	# A swoosh of paint, the brush laid across it, and a spark at its tip.
	var swoosh := PackedVector2Array()
	for k in 13:
		var t := k / 12.0
		swoosh.append(Vector2(lerpf(-46, 30, t), 26.0 - sin(t * PI) * 20.0))
	mark.draw_polyline(swoosh, CLAUDE, 9.0, true)
	mark.draw_line(Vector2(-34, 40), Vector2(4, 2), Color(0.55, 0.34, 0.18), 7.0, true)
	mark.draw_line(Vector2(4, 2), Vector2(13, -7), Color(0.75, 0.75, 0.8), 9.0, true)
	mark.draw_colored_polygon(PackedVector2Array([Vector2(8, -11), Vector2(17, -2), Vector2(30, -26)]), CLAUDE)
	mark.draw_polyline(PackedVector2Array([Vector2(8, -11), Vector2(30, -26), Vector2(17, -2)]), INK, 1.5, true)
	var twinkle := 1.0 if GameState.reduce_motion_for(mark) else 0.85 + 0.15 * sin(TAU * SPARK_HZ * _clock)
	_spark(mark, Vector2(32, -36), 17.0 * twinkle, GILT_LIGHT)
	_spark(mark, Vector2(-26, -26), 8.0, Color(GILT_LIGHT, 0.8))


func _spark(mark: Node2D, at: Vector2, radius: float, colour: Color) -> void:
	var points := PackedVector2Array()
	for k in 8:
		points.append(at + Vector2.from_angle(TAU * k / 8.0 - PI / 2.0) * (radius if k % 2 == 0 else radius * 0.28))
	mark.draw_colored_polygon(points, colour)


## The heart between the two makers.
func _draw_heart(heart: Node2D) -> void:
	var points := PackedVector2Array()
	for k in 32:
		var t := TAU * k / 32.0
		points.append(Vector2(16.0 * pow(sin(t), 3.0), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * 1.2)
	heart.draw_colored_polygon(points, Color(0.82, 0.2, 0.25))
	points.append(points[0])
	heart.draw_polyline(points, GILT, 2.0, true)
