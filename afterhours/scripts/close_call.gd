class_name CloseCall
extends Node2D
## A room's close calls (the room adds one over itself, under the HUD). While the highest
## suspicion of its active guards (Room.peak_suspicion) is at least CLOSE_CALL but not full,
## and no guard chases, a heartbeat beats (faster as suspicion rises: beat_hz, always under
## 2 Hz) and the screen's edges darken with it (strength, the darkening easing in and out at
## FADE_RATE and swelling a little at each beat; a smooth swell, never a flip; off under
## Reduce Motion). Suspicion that peaked at NEAR_MISS or more and drains back to nothing,
## with no guard spotting (Guard.spotted) or catching the mime meanwhile, is a near miss: a
## relief sting and the mime wipes its brow (CharacterRig.Fidget.BROW).

## Suspicion where the heartbeat starts, and the peak a near miss must have reached.
const CLOSE_CALL := 0.25
const NEAR_MISS := 0.4
## The heartbeat's rate at CLOSE_CALL and just short of full suspicion.
const BEAT_SLOW_HZ := 0.9
const BEAT_FAST_HZ := 1.8
## The edges' darkness at full strength (alpha at the very edge), how far in from each edge
## it fades out (a share of the screen's height), how much a beat swells it, and how fast it
## follows the suspicion (strength per second).
const EDGE_ALPHA := 0.8
const EDGE_DEPTH := 0.38
const BEAT_SWELL := 0.18
const FADE_RATE := 2.0
const EDGE_COLOR := Color(0.03, 0.0, 0.06)
## How long the brow wipe takes.
const BROW_TIME := 0.9

var room: Room
## The darkening as drawn (0..1, easing toward strength).
var shown := 0.0
## How far through the current beat it is (0 just beaten, 1 due).
var beat := 1.0
## The highest suspicion of the close call going on (0 with none), and whether a guard
## spotted or caught the mime during it.
var peak := 0.0
var spoiled := false
## Near misses so far (tests).
var near_misses := 0


## The heartbeat's rate at `suspicion` (from the close call's start to just short of full).
static func beat_hz(suspicion: float) -> float:
	return lerpf(BEAT_SLOW_HZ, BEAT_FAST_HZ, clampf(inverse_lerp(CLOSE_CALL, 1.0, suspicion), 0.0, 1.0))


## Whether `suspicion` is a close call (at least CLOSE_CALL, not full).
static func is_close(suspicion: float) -> bool:
	return suspicion >= CLOSE_CALL and not Detection.is_full(suspicion)


## How dark the edges grow at `suspicion`: 0 at CLOSE_CALL rising to 1 toward full; 0 outside
## a close call.
static func strength(suspicion: float) -> float:
	return clampf(inverse_lerp(CLOSE_CALL, 1.0, suspicion), 0.0, 1.0) if is_close(suspicion) else 0.0


func _ready() -> void:
	for each in room.guards:
		each.spotted.connect(_spoil)
		each.caught.connect(_spoil)


func _physics_process(delta: float) -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	if room.finished or room.leaving or room.tossing or room.run.replaying or game.is_transitioning():
		step(0.0, false, delta)
		return
	step(room.peak_suspicion(), room.guards.any(func(each: Guard) -> bool: return each.active and each.senses.chasing), delta)


## Moves the close call on by `delta` seconds at the room's peak suspicion `suspicion`
## (`chasing`: some guard gives chase, which is no close call).
func step(suspicion: float, chasing: bool, delta: float) -> void:
	var close := is_close(suspicion) and not chasing
	if close:
		beat += beat_hz(suspicion) * delta
		if beat >= 1.0:
			beat = fmod(beat, 1.0)
			Audio.play_for(self, &"heartbeat")
	else:
		# The next close call beats at once.
		beat = 1.0
	shown = move_toward(shown, strength(suspicion) if close else 0.0, FADE_RATE * delta)
	if suspicion > 0.0:
		peak = maxf(peak, suspicion)
	elif peak > 0.0:
		if peak >= NEAR_MISS and not spoiled:
			_relief()
		peak = 0.0
		spoiled = false
	queue_redraw()


## A guard spotted or caught the mime: this close call is no near miss.
func _spoil() -> void:
	spoiled = true


func _relief() -> void:
	near_misses += 1
	Audio.play_for(self, &"relief")
	room.mime.rig.start_fidget(CharacterRig.Fidget.BROW, BROW_TIME)
	print("[Room] Near miss (suspicion peaked at %.2f): the mime wipes its brow" % peak)


## The edges' darkness now (alpha at the very edge): none under Reduce Motion.
func edge_alpha() -> float:
	if shown <= 0.0 or GameState.reduce_motion_for(self):
		return 0.0
	# A swell right after each beat, easing away before the next.
	return EDGE_ALPHA * shown * (1.0 - BEAT_SWELL + BEAT_SWELL * exp(-beat * 6.0))


## Four bands, dark at the screen's edges fading to clear inward (the whole visible screen,
## wherever the world sits on it).
func _draw() -> void:
	var alpha := edge_alpha()
	if alpha <= 0.0:
		return
	var view := get_canvas_transform().affine_inverse() * get_viewport_rect()
	var depth := view.size.y * EDGE_DEPTH
	var outer := PackedVector2Array([view.position, Vector2(view.end.x, view.position.y), view.end, Vector2(view.position.x, view.end.y)])
	var inner_rect := view.grow(-depth)
	var inner := PackedVector2Array([inner_rect.position, Vector2(inner_rect.end.x, inner_rect.position.y), inner_rect.end, Vector2(inner_rect.position.x, inner_rect.end.y)])
	var dark := Color(EDGE_COLOR, alpha)
	var clear := Color(EDGE_COLOR, 0.0)
	for i in 4:
		var j := (i + 1) % 4
		draw_polygon(PackedVector2Array([outer[i], outer[j], inner[j], inner[i]]), PackedColorArray([dark, dark, clear, clear]))
