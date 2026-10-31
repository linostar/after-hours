class_name ForgeryCanvas
extends Control
## The easel overlay where the mime paints the fake, wordless: the painting shows faintly
## on the canvas, and its ghost strokes (Forgery) come one at a time, a glowing path with a
## pulsing start dot to drag along, or a ring to tap for a dab. The paint stays as it is
## traced. After the last stroke the grade icon pops in, holds, and the canvas closes
## with painted(quality). The museum keeps running meanwhile: the watching guard's
## suspicion eye shows beside the canvas, and the put-down-brush button (or a catch,
## through close) leaves with the finished strokes kept; open resumes them, or starts a
## fresh canvas once a fake is done. With Assist mode on (Game.assist) the assist button
## shows and takes the focus: one press (or ui_accept) paints every stroke at exactly
## Forgery.ASSIST_QUALITY, Good and never Perfect. While shown it takes every touch.

## Emitted when the last stroke is graded and the canvas has closed.
signal painted(quality: float)

const GHOST_COLOR := Color(1.0, 0.98, 0.9, 0.4)
const GHOST_WIDTH := 16.0
const START_COLOR := Color(0.95, 0.85, 0.4)
const START_RADIUS := 9.0
## The start dot's pulse rate: under the 2 Hz flash limit (CLAUDE.md).
const PULSE_HZ := 1.5
const DAB_RING_RADIUS := 13.0
const PAINT_COLOR := Color(0.62, 0.71, 0.91)
const PAINT_WIDTH := 7.0
const DAB_RADIUS := 7.0
## A drag adds a point once it moves this far (canvas units).
const MIN_STEP := 2.0
const GRADE_POP := 0.3
const GRADE_HOLD := 0.9
## The watching guard's eye (drawn on the Eye node, beside the canvas) is twice its size.
const EYE_SCALE := 2.0
const GRADE_ICONS: Dictionary[Forgery.Grade, Texture2D] = {
	Forgery.Grade.SLOPPY: preload("res://art/svg/grade_sloppy.svg"),
	Forgery.Grade.GOOD: preload("res://art/svg/grade_good.svg"),
	Forgery.Grade.PERFECT: preload("res://art/svg/grade_perfect.svg"),
}

## The painting's ghost strokes in canvas units (pad-local), traced in order.
@export var ghosts: Array[PackedVector2Array] = []
## The painting being forged (a Paintings id; set by the room): it shows faintly on the
## canvas, cut to fill it, through its style.
var painting := "starry_night":
	set(value):
		painting = value
		if is_node_ready():
			_sync_reference()
## The guard whose suspicion the eye shows (set by the room).
var watcher: Guard
## The strokes traced so far, one per finished ghost.
var traced: Array[PackedVector2Array] = []
var _current := PackedVector2Array()
var _painting := false
var _pulse := 0.0
## The grade's pop-and-hold, and the quality it delivers when it ends.
var _pop: Tween
var _pop_quality := 0.0

@onready var _pad: StrokePad = $Pad
@onready var _reference: TextureRect = $Reference
@onready var _ink: Node2D = $Ink
@onready var _eye: Node2D = $Eye
@onready var _grade: TextureRect = $Grade
@onready var _close: Button = $CloseButton
@onready var _assist: Button = $AssistButton
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	_pad.stroke_started.connect(_on_stroke_started)
	_pad.stroke_moved.connect(_on_stroke_moved)
	_pad.stroke_ended.connect(_on_stroke_ended)
	_close.pressed.connect(close)
	_assist.pressed.connect(_paint_assisted)
	_ink.draw.connect(_draw_ink)
	_eye.draw.connect(_draw_eye)
	_sync_reference()
	hide()


func _sync_reference() -> void:
	_reference.texture = Paintings.SCANS.get(StringName(painting))
	_reference.material = Paintings.style(StringName(painting))


## Shows the canvas: resumes the strokes traced so far, or starts afresh once all are done.
## No ghosts to trace is reported (log and error badge) and the canvas stays shut.
func open() -> void:
	if ghosts.is_empty():
		_game.report_error("Forgery canvas '%s' has no ghost strokes to trace" % get_path())
		return
	if is_finished():
		traced.clear()
	_pad.reset()
	_current.clear()
	_painting = false
	_grade.hide()
	_assist.visible = _game.assist
	show()
	if _game.assist:
		_assist.grab_focus()
	else:
		_close.grab_focus()
	print("[Forgery] Canvas open at stroke %d of %d" % [traced.size() + 1, ghosts.size()])
	_log_ghosts.call_deferred()


## Leaves the canvas, keeping the finished strokes (a stroke half traced is dropped).
## During the grade's pop and hold the finished fake is delivered at once.
func close() -> void:
	if not visible:
		return
	if _pop != null and _pop.is_running():
		_pop.kill()
		_deliver()
		return
	_pad.reset()
	_current.clear()
	_painting = false
	hide()
	print("[Forgery] Canvas closed at stroke %d of %d" % [traced.size() + 1, ghosts.size()])


## The ghost strokes in base units (where the pad landed), for the web smoke test's drags.
func _log_ghosts() -> void:
	var origin := _pad.get_global_rect().position
	var strokes: Array[Array] = []
	for ghost in ghosts:
		var points: Array[Array] = []
		for point in ghost:
			points.append([roundf(origin.x + point.x), roundf(origin.y + point.y)])
		strokes.append(points)
	print("[Forgery] Ghosts in base units %s" % JSON.stringify(strokes))


func is_finished() -> bool:
	return traced.size() >= ghosts.size()


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse = fmod(_pulse + delta * PULSE_HZ, 1.0)
	_ink.queue_redraw()
	_eye.queue_redraw()


func _on_stroke_started(at: Vector2) -> void:
	if is_finished():
		return
	_painting = true
	_current = PackedVector2Array([at])


func _on_stroke_moved(at: Vector2) -> void:
	if _painting and at.distance_to(_current[_current.size() - 1]) >= MIN_STEP:
		_current.append(at)


func _on_stroke_ended(at: Vector2) -> void:
	if not _painting:
		return
	_on_stroke_moved(at)
	_painting = false
	var ghost := ghosts[traced.size()]
	traced.append(_current)
	print("[Forgery] Stroke %d of %d traced (%d points, quality %.2f)" % [traced.size(), ghosts.size(), _current.size(), Forgery.stroke_quality(ghost, _current)])
	_current = PackedVector2Array()
	if is_finished():
		_finish(Forgery.quality(ghosts, traced))


## Assist mode's one press: every ghost painted as traced, graded at ASSIST_QUALITY.
func _paint_assisted() -> void:
	if is_finished():
		return
	_pad.reset()
	_painting = false
	_current.clear()
	traced = ghosts.duplicate()
	print("[Forgery] Assist painted the remaining strokes")
	_finish(Forgery.ASSIST_QUALITY)


## Grades `fake_quality`, pops its icon in, holds it, then closes with painted.
func _finish(fake_quality: float) -> void:
	var fake_grade := Forgery.grade(fake_quality)
	print("[Forgery] Fake painted: quality %.2f, %s" % [fake_quality, Forgery.Grade.keys()[fake_grade]])
	_grade.texture = GRADE_ICONS[fake_grade]
	_grade.scale = Vector2.ZERO
	_grade.show()
	_assist.hide()
	_pop_quality = fake_quality
	_pop = create_tween()
	_pop.tween_property(_grade, "scale", Vector2.ONE, GRADE_POP).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pop.tween_interval(GRADE_HOLD)
	_pop.tween_callback(_deliver)


func _deliver() -> void:
	hide()
	print("[Forgery] Canvas closed with the fake")
	painted.emit(_pop_quality)


func _draw_eye() -> void:
	if watcher != null and watcher.suspicion > 0.0:
		Guard.draw_eye(_eye, Vector2.ZERO, watcher.suspicion, EYE_SCALE)


## The ink layer (pad-local): the traced paint, the stroke being traced, and the next ghost.
func _draw_ink() -> void:
	for stroke in traced:
		_draw_paint(stroke)
	if not _current.is_empty():
		_draw_paint(_current)
	if is_finished():
		return
	var ghost := ghosts[traced.size()]
	var pulse_radius := START_RADIUS * (1.0 + 0.35 * sin(_pulse * TAU))
	if ghost.size() == 1:
		_ink.draw_arc(ghost[0], DAB_RING_RADIUS, 0.0, TAU, 32, GHOST_COLOR, 4.0, true)
		_ink.draw_circle(ghost[0], pulse_radius * 0.5, START_COLOR)
		return
	_ink.draw_polyline(ghost, GHOST_COLOR, GHOST_WIDTH, true)
	_ink.draw_circle(ghost[0], pulse_radius, START_COLOR)


func _draw_paint(stroke: PackedVector2Array) -> void:
	if stroke.size() == 1:
		_ink.draw_circle(stroke[0], DAB_RADIUS, PAINT_COLOR)
		return
	_ink.draw_polyline(stroke, PAINT_COLOR, PAINT_WIDTH, true)
