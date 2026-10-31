class_name Room
extends Node2D
## A gallery room, seen 3/4 top-down. scenes/room_base.tscn holds what every room shares;
## each room scene inherits it and adds its walls, navmesh, partitions (the mime walks
## around them, guards cannot see through them), guards (the Guard children of Actors),
## frames, portraits, doors and, optionally, the Easel and the Masterpiece. The mime starts
## at the Entrance marker. A tap on the floor walks the mime there. A tap on the glowing
## easel (Easel.rect) walks it to Easel.spot, where the forgery canvas opens over the
## still-running room; a painted fake puts the glow out (tapping the easel again repaints
## it). With a fake, a tap on the masterpiece (painting_rect) walks the mime to swap_spot
## below it, where standing still for SWAP_TIME swaps the fake for the original (tapping
## elsewhere cancels the swap); a tap there without one is a tap on the floor. A tap on a
## straight small frame (a TiltFrame under Frames) walks the mime under it and tilts it: a
## noise the nearest guard in earshot hears (Guard.hear) and walks over to. A tap on a tall
## portrait (a HidingPortrait under Portraits) walks the mime there and it steps in, out of
## every guard's sight (a guard who sees it step in chases it there and pulls it out); the
## next tap steps it out and goes on as that tap. The keyboard (KeyboardInput) walks the
## mime directly (cancelling any of the above, stepping out of a portrait) and E acts as a
## tap on the nearest thing within INTERACT_REACH it can use (easel, masterpiece, straight
## frame, portrait; E while hidden steps out). Carrying the original, the exit (the Door
## under Doors whose to_room is Door.EXIT) glows, and the fake hangs in the original's
## place: every guard watches it (fake_view_point, the floor at its foot) and inspects it
## once per pass, a "?" over the painting while one does; a fake found out
## (Forgery.is_noticed; inspections count across the guards) turns the "?" into "!" for
## good, and the guard who found it out searches around it. Reaching the exit ends the
## wing: the stars (Stars, against par_time) show in the results overlay. A guard that
## chases the mime down (Guard) shakes it and tosses it back to the entrance (TOSS_SHAKE,
## then TOSS_FLIGHT along an arc TOSS_HEIGHT high), closing the canvas if it was painting
## (its finished strokes are kept); taps are ignored meanwhile, then every guard starts its
## route again (a mime carrying the fake or the original keeps it: only the guards reset).
## The timer (elapsed) keeps running through it all, but not while a screen change fades
## (the player cannot act then); ever_seen records whether any guard ever spotted the mime.

## Where the mime stands to swap the masterpiece (below it), and where a guard looks to
## inspect the hung fake: the floor at the painting's foot (sight rays to the painting
## itself would hit the back wall).
const SWAP_Y := 235.0
const FAKE_VIEW_Y := 180.0
const QUERY_ICON := preload("res://art/svg/icon_query.svg")
const ALARM_ICON := preload("res://art/svg/icon_alarm.svg")
## How close to the swap spot (or the easel's, a frame's or a portrait's) counts as
## standing there.
const SWAP_REACH := 8.0
const SWAP_TIME := 1.5
## How close (to where it would stand) the mime must be for E to use something.
const INTERACT_REACH := 70.0
const TOSS_SHAKE := 0.45
const TOSS_FLIGHT := 0.8
const TOSS_HEIGHT := 120.0
## The mime's wobble while the guard shakes it (radians either way).
const SHAKE_ANGLE := 0.3

## The par time for the third star, in seconds.
@export var par_time := 45.0

## Seconds since the room started (the wing timer: a toss does not stop it).
var elapsed := 0.0
var ever_seen := false
var catches := 0
var tossing := false
## Whether the mime is heading to (or standing at) the swap spot to swap.
var swap_intent := false
## Whether the mime is heading to the easel to paint.
var paint_intent := false
## The frame the mime is heading to tilt, if any.
var tilt_target: TiltFrame
## The portrait the mime is heading to hide in, and the one it hides in.
var hide_target: HidingPortrait
var hidden_in: HidingPortrait
## The quality (Forgery) of the fake the mime carries, or of the one hung by the swap.
var fake_quality := 0.0
## Whether the swap has hung the fake, how many inspections it has had, and whether one
## found it out.
var fake_hung := false
var inspections := 0
var found_out := false
var finished := false
var stars: Array[bool] = []
## The layout, read from the room's nodes: where the mime starts (Entrance), the forgery
## kit and the masterpiece (null in a room without them), and the doors (Doors), the exit
## among them (null in a room without one).
var entrance := Vector2.ZERO
var easel: Easel
var masterpiece: FramedPainting
var doors: Array[Door] = []
var exit_door: Door

@onready var mime: Mime = $Actors/Mime
## The room's guards (the Guard children of Actors), and the first of them.
var guards: Array[Guard] = []
var guard: Guard
@onready var _floor: FloorInput = $FloorInput
@onready var _keys: KeyboardInput = $KeyboardInput
@onready var _canvas: ForgeryCanvas = $EaselLayer/ForgeryCanvas
@onready var _fake_icon: Sprite2D = $FakeIcon
## The view from inside a portrait: the room through that painting's style, in its frame.
@onready var _style_view: Control = $StyleLayer/StyleView
var _frames: Array[TiltFrame] = []
var _portraits: Array[HidingPortrait] = []
@onready var _results: Results = $ResultsLayer/Results
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	entrance = ($Entrance as Node2D).position
	easel = get_node_or_null("Actors/Easel") as Easel
	masterpiece = get_node_or_null("Masterpiece") as FramedPainting
	for child in $Doors.get_children():
		if child is Door:
			doors.append(child)
			if child.to_room == Door.EXIT and exit_door == null:
				exit_door = child
		else:
			_game.report_error("Room '%s': Doors child '%s' is a %s, not a Door" % [scene_file_path, child.name, child.get_class()])
	mime.place_at(entrance)
	if masterpiece != null:
		mime.painting = masterpiece.painting
		_canvas.painting = masterpiece.painting
		_fake_icon.position = masterpiece.position
	for child in $Actors.get_children():
		if child is Guard:
			guards.append(child)
	guard = guards[0] if not guards.is_empty() else null
	for each in guards:
		each.target = mime
		each.reset()
		each.spotted.connect(_on_spotted)
		each.caught.connect(_on_caught)
		each.inspected.connect(_on_inspected.bind(each))
	_floor.tapped.connect(_on_floor_tapped)
	_keys.interacted.connect(_on_interacted)
	for child in $Frames.get_children():
		if child is TiltFrame:
			_frames.append(child)
		else:
			_game.report_error("Room '%s': Frames child '%s' is a %s, not a TiltFrame" % [scene_file_path, child.name, child.get_class()])
	for each in guards:
		each.frames = _frames
	for child in $Portraits.get_children():
		if child is HidingPortrait:
			_portraits.append(child)
		else:
			_game.report_error("Room '%s': Portraits child '%s' is a %s, not a HidingPortrait" % [scene_file_path, child.name, child.get_class()])
	_canvas.watchers = guards
	_canvas.painted.connect(_on_painted)
	if DebugOverlay.wanted():
		add_debug_overlay()
	_game.arrive(GameState.Flow.ROOM)
	if masterpiece != null and exit_door != null:
		print("[Room] Masterpiece at %s, exit at %s" % [painting_rect(), exit_door.position])
	if easel != null:
		print("[Room] Easel at %s" % easel.rect())


## Where a tap means the masterpiece (an empty rect in a room without one).
func painting_rect() -> Rect2:
	if masterpiece == null:
		return Rect2()
	return Rect2(masterpiece.position - masterpiece.size / 2.0, masterpiece.size)


func swap_spot() -> Vector2:
	return Vector2(masterpiece.position.x, SWAP_Y) if masterpiece != null else Vector2.INF


func fake_view_point() -> Vector2:
	return Vector2(masterpiece.position.x, FAKE_VIEW_Y) if masterpiece != null else Vector2.INF


## Adds the dev-only guard debug overlay (DebugOverlay) above the room.
func add_debug_overlay() -> DebugOverlay:
	var overlay := DebugOverlay.new()
	overlay.name = "DebugOverlay"
	overlay.z_index = 100
	overlay.guards = guards
	add_child(overlay)
	print("[Room] Debug overlay on")
	return overlay


func _physics_process(delta: float) -> void:
	if finished or _game.is_transitioning():
		return
	elapsed += delta
	var walk := _keys.direction()
	if walk != Vector2.ZERO and _accepts_input():
		if hidden_in != null:
			_step_out()
		_cancel_swap()
		paint_intent = false
		tilt_target = null
		hide_target = null
		mime.nudge(walk, delta)
	if paint_intent and not tossing and not mime.walking and mime.position.distance_to(easel.spot()) <= SWAP_REACH:
		paint_intent = false
		_canvas.open()
	if tilt_target != null and not tossing and not mime.walking and mime.position.distance_to(tilt_target.spot()) <= SWAP_REACH:
		_tilt(tilt_target)
	if hide_target != null and not tossing and not mime.walking and mime.position.distance_to(hide_target.spot()) <= SWAP_REACH:
		_hide_in(hide_target)
	if fake_hung and not found_out:
		_fake_icon.visible = guards.any(func(each: Guard) -> bool: return each.inspecting)
	if swap_intent and not tossing and not mime.walking and mime.position.distance_to(swap_spot()) <= SWAP_REACH:
		mime.swap_progress = minf(mime.swap_progress + delta / SWAP_TIME, 1.0)
		if mime.swap_progress >= 1.0:
			_swap()
	if mime.carrying and not tossing and exit_door != null and mime.position.distance_to(exit_door.position) <= Door.REACH:
		_escape()


func _on_floor_tapped(at: Vector2) -> void:
	if tossing or finished:
		return
	if hidden_in != null:
		if hidden_in.rect().has_point(at):
			return
		_step_out()
	var on_painting := painting_rect().has_point(at) and mime.has_fake
	if on_painting and swap_intent:
		# Already heading there or swapping: a second tap keeps the progress.
		return
	_cancel_swap()
	paint_intent = false
	tilt_target = null
	hide_target = null
	for portrait in _portraits:
		if portrait.rect().has_point(at):
			hide_target = portrait
			mime.walk_to(portrait.spot())
			return
	for frame in _frames:
		if frame.rect().has_point(at) and not frame.tilted:
			tilt_target = frame
			mime.walk_to(frame.spot())
			return
	if easel != null and easel.rect().has_point(at) and not mime.carrying:
		paint_intent = true
		mime.walk_to(easel.spot())
		return
	if on_painting:
		swap_intent = true
		mime.walk_to(swap_spot())
		return
	mime.walk_to(at)


## Whether the player can act in the room now (not tossed, painting or finished).
func _accepts_input() -> bool:
	return not tossing and not finished and not _canvas.visible


## E: steps out of a portrait, or taps the nearest usable thing within INTERACT_REACH of
## where the mime would stand for it.
func _on_interacted() -> void:
	if not _accepts_input():
		return
	if hidden_in != null:
		_step_out()
		return
	var best_tap := Vector2.INF
	var best_distance := INTERACT_REACH
	for usable: Array[Vector2] in _usables():
		var distance := mime.position.distance_to(usable[0])
		if distance <= best_distance:
			best_distance = distance
			best_tap = usable[1]
	if best_tap != Vector2.INF:
		_on_floor_tapped(best_tap)


## What the mime can use now, each as [where it stands, where a tap means it].
func _usables() -> Array[Array]:
	var usables: Array[Array] = []
	if easel != null and not mime.carrying:
		usables.append([easel.spot(), easel.rect().get_center()] as Array[Vector2])
	if masterpiece != null and mime.has_fake:
		usables.append([swap_spot(), painting_rect().get_center()] as Array[Vector2])
	for frame in _frames:
		if not frame.tilted:
			usables.append([frame.spot(), frame.position] as Array[Vector2])
	for portrait in _portraits:
		usables.append([portrait.spot(), portrait.position] as Array[Vector2])
	return usables


func _cancel_swap() -> void:
	if swap_intent and mime.swap_progress > 0.0:
		print("[Room] Swap cancelled at %d%%" % roundi(mime.swap_progress * 100.0))
	swap_intent = false
	mime.swap_progress = 0.0


func _hide_in(portrait: HidingPortrait) -> void:
	hide_target = null
	var seen := false
	for each in guards:
		if each.active and each.can_see(mime.global_position):
			seen = true
			each.saw_hiding()
	if seen:
		ever_seen = true
	hidden_in = portrait
	portrait.occupied = true
	mime.visible = false
	# The view's white rect only shows through a style: without one it would cover the room.
	_style_view.material = Paintings.style(StringName(portrait.painting), true)
	if _style_view.material == null:
		_game.report_error("Room '%s': portrait %s has no style for painting '%s'" % [scene_file_path, portrait.name, portrait.painting])
	else:
		_style_view.show()
	print("[Room] Hid in the portrait at %s at t %.2f (seen going in: %s)" % [portrait.position.round(), elapsed, seen])


func _step_out() -> void:
	print("[Room] Stepped out of the portrait at %s at t %.2f" % [hidden_in.position.round(), elapsed])
	hidden_in.occupied = false
	hidden_in = null
	mime.visible = true
	_style_view.hide()


func _tilt(frame: TiltFrame) -> void:
	tilt_target = null
	frame.tilt()
	var heard := nearest_in_earshot(frame.view_point())
	if heard != null:
		heard.hear(frame.view_point())
	print("[Room] Tilted the frame at %s at t %.2f (heard by: %s)" % [frame.position.round(), elapsed, str(heard.name) if heard != null else "nobody"])


## The active guard nearest `point` within GuardBrain.HEARING_RANGE, or null: a decoy pulls
## only that one.
func nearest_in_earshot(point: Vector2) -> Guard:
	var nearest: Guard
	var nearest_distance := GuardBrain.HEARING_RANGE
	for each in guards:
		var distance := each.global_position.distance_to(point)
		if each.active and distance < nearest_distance:
			nearest = each
			nearest_distance = distance
	return nearest


func _on_painted(quality: float) -> void:
	fake_quality = quality
	mime.has_fake = true
	if easel != null:
		easel.glowing = false
	print("[Room] Fake ready at t %.2f (quality %.2f, %s)" % [elapsed, quality, Forgery.Grade.keys()[Forgery.grade(quality)]])


func _swap() -> void:
	swap_intent = false
	mime.swap_progress = 0.0
	mime.has_fake = false
	mime.carrying = true
	fake_hung = true
	for each in guards:
		each.fake_point = fake_view_point()
		each.watches_fake = true
	_fake_icon.texture = QUERY_ICON
	if exit_door != null:
		exit_door.glowing = true
	print("[Room] Swapped the forgery for the original at t %.2f (fake %s)" % [elapsed, Forgery.Grade.keys()[Forgery.grade(fake_quality)]])


func _on_inspected(by: Guard) -> void:
	inspections += 1
	var fake_grade := Forgery.grade(fake_quality)
	var noticed := Forgery.is_noticed(fake_grade, inspections)
	print("[Room] Inspection %d of the %s fake by %s at t %.2f: %s" % [inspections, Forgery.Grade.keys()[fake_grade], by.name, elapsed, "found out" if noticed else "passed"])
	if not noticed:
		return
	found_out = true
	_fake_icon.texture = ALARM_ICON
	_fake_icon.show()
	for each in guards:
		each.watches_fake = false
	by.search(fake_view_point())


func _escape() -> void:
	finished = true
	for each in guards:
		each.active = false
	mime.place_at(mime.position)
	stars = Stars.earned(ever_seen, elapsed, par_time)
	print("[Room] Escaped with the original at t %.2f (par %.0f, seen %s)" % [elapsed, par_time, ever_seen])
	_results.present(stars)


func _on_spotted() -> void:
	ever_seen = true


func _on_caught() -> void:
	catches += 1
	tossing = true
	_cancel_swap()
	paint_intent = false
	tilt_target = null
	hide_target = null
	if hidden_in != null:
		_step_out()
	_canvas.close()
	var from := mime.position
	mime.place_at(from)
	print("[Room] Caught (%d) at t %.2f: tossing the mime from %s to the entrance" % [catches, elapsed, from.round()])
	var toss := create_tween()
	for angle: float in [SHAKE_ANGLE, -SHAKE_ANGLE, SHAKE_ANGLE, 0.0]:
		toss.tween_property(mime, "rotation", angle, TOSS_SHAKE / 4.0)
	toss.tween_method(_toss_step.bind(from), 0.0, 1.0, TOSS_FLIGHT)
	toss.finished.connect(_end_toss)


## The mime along the toss arc, `t` from 0 (where it was caught) to 1 (the entrance).
func _toss_step(t: float, from: Vector2) -> void:
	mime.position = from.lerp(entrance, t) + Vector2(0.0, -sin(t * PI) * TOSS_HEIGHT)
	mime.rotation = t * TAU


func _end_toss() -> void:
	mime.rotation = 0.0
	mime.place_at(entrance)
	for each in guards:
		each.reset()
		each.watches_fake = fake_hung and not found_out
	tossing = false
	print("[Room] The mime is back at the entrance at t %.2f" % elapsed)
