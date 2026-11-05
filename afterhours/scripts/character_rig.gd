class_name CharacterRig
extends Node2D
## A character's drawing (the mime, the guards, the ghost mime), its origin at the feet: a
## body per view (front walking down, back walking up, side walking right, mirrored for
## left) with a jointed arm and leg each side, over a floor shadow. Each limb is an upper
## part (upper arm, thigh) pivoting at shoulder or hip with its lower part (forearm and
## hand, shin and shoe) as a child at the elbow or knee. face() picks the view from a
## heading (view_for: a diagonal is side on, with hysteresis so it does not flicker); walk() advances the
## walk cycle by the distance moved, swinging the limbs (side view) or lifting the feet in
## turn (front and back), bending knees and elbows with the cycle, bobbing the body and
## emitting stepped at every footfall (setting off from rest, then each step_length); with
## no distance the limbs settle straight. The SVG parts are imported at ART_SCALE and drawn
## back at 1 / ART_SCALE, so they stay crisp on a screen larger than the base viewport.
## At rest it lives, on its own clock advanced by walk() (so runs repeat): the body breathes
## (BREATH_HZ, stilled under Reduce Motion), the eyes blink (BLINK_HZ, lids drawn over the
## face's eyes_front / eyes_side), a rig with gag_after does the mime's invisible wall once it
## has stood idle that long (gagging; it stops the moment it walks or is busy), and
## start_fidget plays a guard's waypoint fidget (Fidget) over a given time. The face wears a
## Mood (calm, alarmed or smug; guard_mood and mime_mood pick it from the state), drawn with
## the lids over the front and side faces; wear() dresses the rig in a look (a guard's).

## Emitted at each footfall while walking.
signal stepped
## Emitted when the invisible-wall gag starts.
signal gag_started

enum View { FRONT, BACK, RIGHT, LEFT }
## A gesture played over a time: a guard's fidget at a waypoint (STRETCH, WATCH, YAWN),
## dusting off its hands after a catch (DUST), the mime tipping its beret (TIP, the escape)
## and bowing (BOW, a three-star result).
enum Fidget { NONE, STRETCH, WATCH, YAWN, DUST, TIP, BOW }
## The face's expression (none from behind): calm brows and a smile; alarmed, brows up and
## knitted, mouth open and a drop of sweat; smug, one brow up, eyes half shut and a smirk.
enum Mood { CALM, ALARMED, SMUG }

## A front or back view turns to the side once the heading's across exceeds this share of
## its along (about 35 degrees off vertical), so a diagonal walks side on; a side view turns
## back only under SIDE_LEAVE (about 24 degrees), the band between keeping it from flickering.
const SIDE_ENTER := 0.7
const SIDE_LEAVE := 0.45
## How fast the stride grows when walking starts and fades when it stops (per second).
const SETTLE_RATE := 10.0
## The side view's far arm and leg are shaded this much.
const FAR_SHADE := Color(0.7, 0.7, 0.76)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
## The shadow ellipse's height over its width.
const SHADOW_FLATTEN := 0.27
## The rig parts' SVG import scale (svg/scale in their .import files).
const ART_SCALE := 2.0
## How far below its top edge a forearm's elbow sits (SVG units): its rounded cap.
const JOINT_CAP := 3.0
## How far below its top edge a shin's knee sits (SVG units): the centre of its knee
## circle, the thigh's width across. The thigh ends in a half circle round the same point,
## unoutlined, and the shin is drawn behind it, so the leg bends as one at the knee.
const KNEE_CAP := 5.6
## Breathing at rest: the body (above the hips) stretches by up to BREATH_DEPTH of its height.
const BREATH_HZ := 0.3
const BREATH_DEPTH := 0.012
## Blinks: the lids close for BLINK_TIME once every 1 / BLINK_HZ seconds.
const BLINK_HZ := 0.28
const BLINK_TIME := 0.12
## The closed lid's crease.
const LID_LINE := Color(0.08, 0.06, 0.12)
## The gag's hands pat along the invisible wall (stilled under Reduce Motion).
const PAT_HZ := 0.8
const PAT_SWING := 0.12
## How fast a gesture (the gag) blends in and out (weight per second).
const GESTURE_RATE := 5.0
## Dusting off the hands: they brush past each other at DUST_HZ (stilled under Reduce Motion).
const DUST_HZ := 1.6
const DUST_SWING := 0.3
## A yawn stretches the body this much more at its height; a bow dips it this much.
const YAWN_STRETCH := 0.04
const BOW_DIP := 0.14
## Suspicion from which a face turns alarmed: the guard's eye half full, where it has
## spotted the mime (Detection.SEEN_AT).
const ALARM_AT := Detection.SEEN_AT
## The alarmed face's drop of sweat.
const SWEAT := Color(0.66, 0.86, 1.0)
const SWEAT_LINE := Color(0.2, 0.32, 0.5)

@export var body_front: Texture2D
@export var body_back: Texture2D
@export var body_side: Texture2D
## The limbs, each drawn hanging from its joint: the upper part from shoulder or hip, the
## lower part from elbow or knee (JOINT_CAP or KNEE_CAP below its top).
@export var arm_upper: Texture2D
@export var arm_lower: Texture2D
@export var leg_upper: Texture2D
@export var leg_lower: Texture2D
## The shin and shoe seen from the side (the toe forward), or null to use leg_lower.
@export var leg_lower_side: Texture2D
## The elbow and knee below the shoulder and hip (SVG units down the upper part).
@export var elbow := 13.0
@export var knee := 15.0
## The bodies' canvas pixel that sits at the character's feet.
@export var feet_at := Vector2(24, 92)
## The hips and shoulders from the feet in the front view (x either side); the side view
## stands both legs SIDE_SPREAD apart at x 0 and both arms at x 0.
@export var hip := Vector2(5.5, -30)
@export var shoulder := Vector2(15.5, -56)
@export var side_spread := 3.0
## Base units walked per step (two steps a cycle).
@export var step_length := 50.0
## At full stride (side view): how far the legs reach fore and aft at a footfall (radians
## off vertical) and the arms swing; how high the swinging foot clears the floor (side) or
## the lifted foot rises (front and back); how far the body sinks at each footfall (lowest
## with the legs spread, back up as they pass); how far it leans into the walk (radians) and
## sways over the planted foot (front and back).
@export var leg_swing := 0.5
@export var arm_swing := 0.4
@export var lift := 5.0
@export var bob := 2.0
@export var lean := 0.05
@export var sway := 1.0
@export var shadow_radius := 15.0
## At full stride: how far elbows stay bent while walking, how much more the elbow of the
## arm swinging forward bends, and how far the forearm trails its upper arm's swing (the
## follow-through, as a share of the swing).
@export var elbow_rest := 0.2
@export var elbow_bend := 0.5
@export var elbow_lag := 0.35
## The eyes' centres in the front and side bodies (SVG units; none in the back view), the
## eye's half size, and the lid's colour (the face's skin).
@export var eyes_front: PackedVector2Array
@export var eyes_side: PackedVector2Array
@export var eye_radius := Vector2(1.8, 2.4)
@export var lid_color := Color.WHITE
## The mood's brows (each centred brow_lift above its eye, brow_half wide either side) and
## mouth (centred at mouth_front or mouth_side, mouth_half wide either side in the front
## view, half that in profile), in SVG units.
@export var brow_lift := 3.5
@export var brow_half := 2.4
@export var brow_width := 0.9
@export var brow_color := Color.BLACK
@export var mouth_front := Vector2.ZERO
@export var mouth_side := Vector2.ZERO
@export var mouth_half := 2.4
@export var mouth_color := Color.BLACK
## Seconds standing idle before the invisible-wall gag starts (0: never).
@export var gag_after := 0.0

var view := View.FRONT
## Whether it is doing the invisible-wall gag now.
var gagging := false
## The fidget it is playing (NONE for none).
var fidget := Fidget.NONE
## The face's expression now (set by its owner from guard_mood or mime_mood).
var mood := Mood.CALM
## The rig's own clock (seconds of walk() calls) and how long it has stood idle.
var clock := 0.0
var rest := 0.0
var _gag := 0.0
var _fidget_time := 0.0
var _fidget_length := 0.0
var _blink_offset := 0.0
var _lids: Node2D
## A squash and stretch on top of the drawing (the mime's shrug), kept apart from the mirror.
var squash := Vector2.ONE:
	set(value):
		squash = value
		_mirror()
## The walk cycle, 0..1 per two steps.
var phase := 0.0
## How far into a stride the limbs are: 0 at rest, 1 walking.
var stride := 0.0

var _body: Sprite2D
## The upper parts, [left, right] in the front view and [far, near] in the side view; each
## holds its lower part (shins, forearms, in the same order).
var _legs: Array[Sprite2D] = []
var _arms: Array[Sprite2D] = []
var _shins: Array[Sprite2D] = []
var _forearms: Array[Sprite2D] = []


## A guard's mood: smug dusting off its hands after a catch (`gesture` DUST), alarmed while
## `alert` (chasing or searching) or with `suspicion` at ALARM_AT or more, else calm.
static func guard_mood(suspicion: float, alert: bool, gesture: Fidget) -> Mood:
	if gesture == Fidget.DUST:
		return Mood.SMUG
	if alert or suspicion >= ALARM_AT:
		return Mood.ALARMED
	return Mood.CALM


## The mime's mood: alarmed while `tossed`, smug tipping its beret or bowing (`gesture` TIP
## or BOW), alarmed while the most suspicious guard's suspicion (`peak`) is at ALARM_AT or
## more, else calm.
static func mime_mood(peak: float, tossed: bool, gesture: Fidget) -> Mood:
	if tossed:
		return Mood.ALARMED
	if gesture == Fidget.TIP or gesture == Fidget.BOW:
		return Mood.SMUG
	if peak >= ALARM_AT:
		return Mood.ALARMED
	return Mood.CALM


## The view for `heading`, staying `current` for a zero heading and across the band
## between SIDE_LEAVE and SIDE_ENTER; a diagonal is side on.
static func view_for(heading: Vector2, current: View) -> View:
	if heading.is_zero_approx():
		return current
	var across := absf(heading.x)
	var along := absf(heading.y)
	var horizontal: bool
	if current == View.RIGHT or current == View.LEFT:
		horizontal = across >= along * SIDE_LEAVE
	else:
		horizontal = across > along * SIDE_ENTER
	if horizontal:
		return View.RIGHT if heading.x > 0.0 else View.LEFT
	return View.BACK if heading.y < 0.0 else View.FRONT


func _ready() -> void:
	for i in 2:
		_legs.append(_limb("Leg%d" % i, leg_upper))
		_shins.append(_lower(_legs[i], "Shin", leg_lower, knee, KNEE_CAP))
		_shins[i].show_behind_parent = true
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	_body.offset = -feet_at * ART_SCALE
	_body.scale = Vector2.ONE / ART_SCALE
	_body.use_parent_material = true
	add_child(_body)
	# The face (mood and lids), over the body's (body-local units are SVG units at ART_SCALE).
	_lids = Node2D.new()
	_lids.name = "Lids"
	_lids.position = -feet_at * ART_SCALE
	_lids.use_parent_material = true
	_lids.draw.connect(_draw_face)
	_body.add_child(_lids)
	# Characters made together blink apart: each starts its blink cycle by its owner's name.
	var owner_name := String(get_parent().name) if get_parent() != null else String(name)
	_blink_offset = float(absi(owner_name.hash()) % 1000) / 1000.0 / BLINK_HZ
	for i in 2:
		_arms.append(_limb("Arm%d" % i, arm_upper))
		_forearms.append(_lower(_arms[i], "Forearm", arm_lower, elbow, JOINT_CAP))
	_apply()


## An upper part hanging from its pivot (the sprite's origin, at the top middle).
func _limb(limb_name: String, texture: Texture2D) -> Sprite2D:
	var limb := Sprite2D.new()
	limb.name = limb_name
	limb.texture = texture
	limb.centered = false
	limb.offset = Vector2(-texture.get_width() / 2.0, 0.0)
	limb.scale = Vector2.ONE / ART_SCALE
	limb.use_parent_material = true
	add_child(limb)
	return limb


## `upper`'s lower part, hanging from the joint `joint` SVG units down it, `cap` SVG units
## below its own top edge.
func _lower(upper: Sprite2D, part_name: String, texture: Texture2D, joint: float, cap: float) -> Sprite2D:
	var lower := Sprite2D.new()
	lower.name = part_name
	lower.texture = texture
	lower.centered = false
	lower.offset = Vector2(-texture.get_width() / 2.0, -cap * ART_SCALE)
	lower.position = Vector2(0.0, joint * ART_SCALE)
	lower.use_parent_material = true
	upper.add_child(lower)
	return lower


## Hangs `item` from the hand of arm `i` (1: the near arm in the side view): it swings and
## turns with that forearm (forearm-local units are SVG units at ART_SCALE).
func hold(item: Node2D, i := 1) -> void:
	var forearm := _forearms[i]
	item.position = Vector2(0.0, forearm.texture.get_height() - JOINT_CAP * ART_SCALE)
	forearm.add_child(item)


## Dresses the rig in `look` (rig property names to values: bodies, face and colours; a
## guard's look, Guard.LOOKS), the joints unchanged.
func wear(look: Dictionary) -> void:
	for key: String in look:
		set(key, look[key])
	if is_node_ready():
		_apply()


## Turns the drawing toward `heading` (view_for).
func face(heading: Vector2) -> void:
	var next := view_for(heading, view)
	if next != view:
		view = next
		_apply()


## Moves the walk cycle on by `distance` (base units walked this frame; 0 standing) over
## `delta` seconds, and the rest life with it; a character not `idle` (busy using
## something) stands without the gag.
func walk(distance: float, delta: float, idle := true) -> void:
	clock += delta
	if distance > 0.0:
		var before := phase
		phase = fmod(phase + distance / (2.0 * step_length), 1.0)
		# The first foot leaving the floor is a footfall too, then one every step.
		if stride == 0.0 or floori(before * 2.0) != floori(phase * 2.0):
			stepped.emit()
		stride = minf(stride + SETTLE_RATE * delta, 1.0)
	else:
		stride = maxf(stride - SETTLE_RATE * delta, 0.0)
	rest = rest + delta if distance <= 0.0 and idle else 0.0
	var gag := gag_after > 0.0 and rest >= gag_after
	if gag and not gagging:
		gag_started.emit()
	gagging = gag
	_gag = move_toward(_gag, 1.0 if gagging else 0.0, GESTURE_RATE * delta)
	if fidget != Fidget.NONE:
		_fidget_time += delta
		if _fidget_time >= _fidget_length:
			fidget = Fidget.NONE
	_pose()
	_lids.queue_redraw()


## Plays `kind` over `length` seconds (a guard's waypoint pause; the guard cuts it short
## when something else takes its attention); NONE or no length ends one.
func start_fidget(kind: Fidget, length: float) -> void:
	fidget = kind if length > 0.0 else Fidget.NONE
	_fidget_time = 0.0
	_fidget_length = length


## Whether the eyes are shut in a blink now (never in the back view: no eyes there).
func blinking() -> bool:
	if view == View.BACK:
		return false
	return fposmod(clock + _blink_offset, 1.0 / BLINK_HZ) < BLINK_TIME


func is_side() -> bool:
	return view == View.RIGHT or view == View.LEFT


## Lays the parts out for the view: textures, pivots, draw order and the mirror.
func _apply() -> void:
	_mirror()
	var shin := leg_lower_side if is_side() and leg_lower_side != null else leg_lower
	for each in _shins:
		each.texture = shin
		# The side shin is wider (the toe forward): centre its knee on the joint again.
		each.offset.x = -shin.get_width() / 2.0
	if is_side():
		_body.texture = body_side
		for i in 2:
			var near := i == 1
			_legs[i].position = Vector2(side_spread * (1.0 if near else -1.0) / 2.0, hip.y)
			_arms[i].position = Vector2(0.0, shoulder.y)
			# modulate, not self_modulate: the lower part is shaded with its upper part.
			_legs[i].modulate = Color.WHITE if near else FAR_SHADE
			_arms[i].modulate = Color.WHITE if near else FAR_SHADE
		# Far arm, far leg, body, near leg, near arm.
		move_child(_arms[0], 0)
		move_child(_legs[0], 1)
		move_child(_body, 2)
		move_child(_legs[1], 3)
		move_child(_arms[1], 4)
	else:
		_body.texture = body_front if view == View.FRONT else body_back
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			_legs[i].position = Vector2(hip.x * side, hip.y)
			_arms[i].position = Vector2(shoulder.x * side, shoulder.y)
			_legs[i].modulate = Color.WHITE
			_arms[i].modulate = Color.WHITE
		# Legs, body, arms.
		move_child(_legs[0], 0)
		move_child(_legs[1], 1)
		move_child(_body, 2)
		move_child(_arms[0], 3)
		move_child(_arms[1], 4)
	_pose()


func _mirror() -> void:
	scale = Vector2(-squash.x if view == View.LEFT else squash.x, squash.y)


## Poses the limbs for the phase and stride, a walk cycle with a footfall (contact) at
## phase 0 and 0.5, where stepped is emitted: at 0 leg 1 (the near leg) reaches forward and
## leg 0 back; each foot is planted for half the cycle (sliding back under the hip) and swings
## through for the other half, highest as it passes the planted one. Positive rotation
## swings a hanging part's end back (to -x). Side view: each leg reaches its foot's spot by
## bending at the knee (two-bone reach, the knee forward), the arms counter-swing with the
## forearms trailing, and the body sinks at contact and leans into the walk. Front and back:
## the lifted leg steps toward or away from the camera, its thigh and shin foreshortened so
## the foot rises under the knee, the arms alternate against the legs (the forward hand
## rising) and the body sways over the planted foot. At rest (stride 0) every joint is
## straight.
func _pose() -> void:
	var p := phase * TAU
	# Body sink: lowest at each contact (legs spread), back to standing height as they pass.
	var drop := bob * stride * (1.0 + cos(2.0 * p)) / 2.0
	if is_side():
		_pose_side(p, drop)
	else:
		_pose_front(p, drop)
	_breathe()
	for i in 2:
		_gesture(i)


## Stretches the body above the hips as it breathes at rest (and further in a yawn), the
## hips kept where they are and the shoulders (the arms) carried with it.
func _breathe() -> void:
	var breath := 0.0 if reduce_motion() else BREATH_DEPTH * (1.0 - stride) * sin(TAU * BREATH_HZ * clock)
	if fidget == Fidget.YAWN:
		breath += YAWN_STRETCH * _fidget_weight()
	elif fidget == Fidget.BOW:
		breath -= BOW_DIP * _fidget_weight()
	_body.scale = Vector2(1.0, 1.0 + breath) / ART_SCALE
	# Scaled about the feet: moving it down by the hips' rise keeps the hips still.
	_body.position.y += -hip.y * breath
	for arm in _arms:
		arm.position.y += breath * (shoulder.y - hip.y)


## How far into its fidget the guard is: rising from 0 and back over its length.
func _fidget_weight() -> float:
	if fidget == Fidget.NONE or _fidget_length <= 0.0:
		return 0.0
	return sin(PI * clampf(_fidget_time / _fidget_length, 0.0, 1.0))


## Blends arm `i` from its walk pose toward the gag's or the fidget's pose. Front and back,
## `out` turns a rotation outward (positive swings a hanging end to -x, outward for the
## left arm); side on, negative rotation reaches forward (the mirror handles facing left).
func _gesture(i: int) -> void:
	var out := 1.0 if i == 0 else -1.0
	var side := is_side()
	var target := Vector2.ZERO
	var weight := 0.0
	if _gag > 0.0:
		# The invisible wall: palms flat on it at chest height, patting along it in turn.
		var pat := 0.0 if reduce_motion() else PAT_SWING * sin(TAU * PAT_HZ * clock + PI * i)
		target = Vector2(-1.45 + pat, -0.9) if side else Vector2(out * (0.45 + pat), out * 2.55)
		weight = _gag
	elif fidget == Fidget.DUST:
		# Both hands meet in front and brush past each other in turn.
		var brush := 0.0 if reduce_motion() else DUST_SWING * sin(TAU * DUST_HZ * clock + PI * i)
		target = Vector2(-0.55 + brush, -1.5) if side else Vector2(-out * 0.3, -out * (1.95 + brush))
		weight = minf(_fidget_weight() * 3.0, 1.0)
	elif fidget == Fidget.BOW:
		# One hand across the waist, the other swept out wide.
		if i == 1:
			target = Vector2(-0.4, -1.6) if side else Vector2(-out * 0.3, -out * 1.7)
		else:
			target = Vector2(0.9, 0.2) if side else Vector2(out * 1.1, out * 0.3)
		weight = _fidget_weight()
	elif fidget == Fidget.TIP and i == 1:
		# The near hand up to the beret's brim and back down.
		target = Vector2(-2.6, -0.8) if side else Vector2(out * 2.4, -out * 1.3)
		weight = _fidget_weight()
	elif fidget == Fidget.STRETCH:
		target = Vector2(-2.9, -0.2) if side else Vector2(out * 2.75, out * 0.25)
		weight = _fidget_weight()
	elif (fidget == Fidget.WATCH or fidget == Fidget.YAWN) and i == 1:
		# One hand: up to the chest for the pocket watch, to the mouth for the yawn.
		var yawn := fidget == Fidget.YAWN
		if side:
			target = Vector2(-0.7, -2.2) if yawn else Vector2(-0.35, -1.7)
		else:
			target = Vector2(-out * 0.7, -out * 2.75) if yawn else Vector2(-out * 0.35, -out * 2.0)
		weight = _fidget_weight()
	if weight <= 0.0:
		return
	_arms[i].rotation = lerpf(_arms[i].rotation, target.x, weight)
	_forearms[i].rotation = lerpf(_forearms[i].rotation, target.y, weight)
	_arms[i].scale = _arms[i].scale.lerp(Vector2.ONE / ART_SCALE, weight)
	_forearms[i].scale = _forearms[i].scale.lerp(Vector2.ONE, weight)


func _pose_side(p: float, drop: float) -> void:
	var tilt := lean * stride
	_body.rotation = tilt
	_body.position = Vector2(0.0, drop)
	var leg := -hip.y
	var reach := leg * sin(leg_swing) * stride
	for i in 2:
		var near := i == 1
		var at := Vector2(side_spread * (1.0 if near else -1.0) / 2.0, hip.y).rotated(tilt) + Vector2(0.0, drop)
		_legs[i].position = at
		_legs[i].scale = Vector2.ONE / ART_SCALE
		_shins[i].scale = Vector2.ONE
		# Leg 1 lands at phase 0, leg 0 half a cycle later.
		var u := fposmod(phase + (0.0 if near else 0.5), 1.0)
		var foot: Vector2
		if u < 0.5:
			foot = Vector2(reach * (1.0 - 4.0 * u), 0.0)
		else:
			var s := (u - 0.5) * 2.0
			foot = Vector2(reach * (2.0 * s * s * (3.0 - 2.0 * s) - 1.0), -lift * stride * sin(PI * pow(s, 0.8)))
		_reach(_legs[i], _shins[i], foot + Vector2(at.x, 0.0) - at)
		# The near arm swings against the near leg: back as it reaches forward.
		var arm := (1.0 if near else -1.0) * arm_swing * stride
		_arms[i].position = Vector2(0.0, shoulder.y).rotated(tilt) + Vector2(0.0, drop)
		_arms[i].rotation = arm * cos(p)
		_arms[i].scale = Vector2.ONE / ART_SCALE
		_forearms[i].scale = Vector2.ONE
		var forward := maxf(-cos(p) * (1.0 if near else -1.0), 0.0)
		var trail := arm * (cos(p - 0.9) - cos(p)) * elbow_lag
		_forearms[i].rotation = minf(trail - stride * elbow_rest - forward * stride * elbow_bend, 0.0)


## Bends `thigh` and `shin` so the foot reaches `to` (from the hip), the knee forward; a foot
## out of reach is reached for with the leg straight.
func _reach(thigh: Sprite2D, shin: Sprite2D, to: Vector2) -> void:
	var upper := knee
	var lower := -hip.y - knee
	var d := to.length()
	var aim := atan2(-to.x, to.y)
	if d >= upper + lower or d < 0.001:
		thigh.rotation = aim
		shin.rotation = 0.0
		return
	var at_hip := acos(clampf((upper * upper + d * d - lower * lower) / (2.0 * upper * d), -1.0, 1.0))
	var at_foot := acos(clampf((lower * lower + d * d - upper * upper) / (2.0 * lower * d), -1.0, 1.0))
	thigh.rotation = aim - at_hip
	shin.rotation = at_hip + at_foot


func _pose_front(p: float, drop: float) -> void:
	var shift := Vector2(sway * stride * sin(p), drop)
	_body.rotation = 0.0
	_body.position = shift
	var upper := knee
	var lower := -hip.y - knee
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		# Leg 0 swings through while phase is in 0..0.5, leg 1 in 0.5..1.
		var s := sin(p) * -side
		var lifted := s * s if s > 0.0 else 0.0
		lifted *= stride
		_legs[i].position = Vector2(hip.x * side, hip.y) + shift
		# Lifting the foot `lift`: the thigh coming toward (or going from) the camera
		# foreshortens three quarters of it, the shin the rest; the knee stays over the foot.
		var thigh_short := 1.0 - lifted * lift * 0.75 / upper
		_legs[i].scale = Vector2(1.0, thigh_short) / ART_SCALE
		_shins[i].scale = Vector2(1.0, (1.0 - lifted * lift * 0.25 / lower) / thigh_short)
		_legs[i].rotation = side * 0.08 * lifted
		_shins[i].rotation = -side * 0.12 * lifted
		# The arm opposite the lifted leg comes forward: its hand rises toward the camera.
		var forward := -cos(p) * side * stride
		_arms[i].position = Vector2(shoulder.x * side, shoulder.y) + shift
		_arms[i].rotation = -side * 0.05 * stride
		_arms[i].scale = Vector2(1.0, 1.0 - 0.12 * absf(forward)) / ART_SCALE
		var raised := maxf(forward, 0.0)
		_forearms[i].scale = Vector2(1.0, 1.0 - raised * arm_swing)
		_forearms[i].rotation = side * (stride * elbow_rest + raised * elbow_bend * 0.5)


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SHADOW_FLATTEN))
	draw_circle(Vector2.ZERO, shadow_radius, SHADOW)


## The face over the front and side views (none from behind), in SVG units: the mood's
## brows and mouth (and the alarmed face's drop of sweat), then the lids, closed in a blink
## (the skin colour with a crease across) or, smug, half shut.
func _draw_face() -> void:
	if view == View.BACK:
		return
	var side := is_side()
	var eyes := eyes_side if side else eyes_front
	_lids.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * ART_SCALE)
	var middle := 0.0
	for eye in eyes:
		middle += eye.x / eyes.size()
	for i in eyes.size():
		# +x toward the nose: the far side of the face for the front view's left eye, ahead in profile.
		var inward := 1.0 if side or eyes[i].x < middle else -1.0
		_draw_brow(eyes[i] + Vector2(0.0, -brow_lift), inward, i == eyes.size() - 1)
	_draw_mouth(mouth_side if side else mouth_front, mouth_half * (0.5 if side else 1.0))
	if mood == Mood.ALARMED and not eyes.is_empty():
		var temple := eyes[eyes.size() - 1] + (Vector2(-3.6, -2.4) if side else Vector2(3.8, -2.4))
		var drop := _ellipse(temple, Vector2(0.9, 1.0), -PI / 6.0, PI * 7.0 / 6.0)
		drop.append(temple + Vector2(0.0, -2.2))
		_lids.draw_colored_polygon(drop, SWEAT)
		_lids.draw_polyline(drop + PackedVector2Array([drop[0]]), SWEAT_LINE, 0.35, true)
	var lid := eye_radius * 1.3
	for eye in eyes:
		if blinking():
			_lids.draw_colored_polygon(_ellipse(eye, lid, 0.0, TAU), lid_color)
			_lids.draw_line(eye - Vector2(lid.x, 0.0), eye + Vector2(lid.x, 0.0), LID_LINE, 0.9, true)
		elif mood == Mood.SMUG:
			_lids.draw_colored_polygon(_ellipse(eye, lid, PI, TAU), lid_color)
			_lids.draw_line(eye - Vector2(lid.x, -0.2), eye + Vector2(lid.x, 0.2), LID_LINE, 0.7, true)
	_lids.draw_set_transform(Vector2.ZERO)


## One brow at `at` for the mood, `inward` (+1 or -1) the way to the nose; `lead` is the
## brow the smug face raises (the right one, the only one in profile).
func _draw_brow(at: Vector2, inward: float, lead: bool) -> void:
	# Outer end, middle, inner end (x toward the nose), through which the brow curves.
	var points: Array[Vector2] = [Vector2(-1.0, 0.5), Vector2(0.0, -0.7), Vector2(1.0, 0.3)]
	if mood == Mood.ALARMED:
		points = [Vector2(-1.0, -1.1), Vector2(0.0, -2.1), Vector2(1.0, -2.5)]
	elif mood == Mood.SMUG and lead:
		points = [Vector2(-1.0, -0.6), Vector2(0.0, -2.2), Vector2(1.0, -0.9)]
	elif mood == Mood.SMUG:
		points = [Vector2(-1.0, 0.0), Vector2(0.0, 0.2), Vector2(1.0, 0.9)]
	var scale_x := Vector2(brow_half * inward, 1.0)
	_lids.draw_polyline(_curve(at + points[0] * scale_x, at + points[1] * scale_x, at + points[2] * scale_x), brow_color, brow_width, true)


## The mouth at `at`, `half` wide either side: a smile (calm), an open O (alarmed), a
## lopsided smirk (smug).
func _draw_mouth(at: Vector2, half: float) -> void:
	match mood:
		Mood.ALARMED:
			var open := _ellipse(at + Vector2(0.0, 0.3), Vector2(maxf(half * 0.55, 0.8), 1.4), 0.0, TAU)
			_lids.draw_colored_polygon(open, mouth_color.darkened(0.55))
			_lids.draw_polyline(open + PackedVector2Array([open[0]]), mouth_color, 0.7, true)
		Mood.SMUG:
			_lids.draw_polyline(_curve(at + Vector2(-half, 0.3), at + Vector2(0.2 * half, 0.5), at + Vector2(half, -0.9)), mouth_color, 1.0, true)
		_:
			_lids.draw_polyline(_curve(at + Vector2(-half, -0.3), at + Vector2(0.0, 0.6), at + Vector2(half, -0.3)), mouth_color, 1.0, true)


## A smooth curve from `a` through `mid` to `b` (a quadratic Bezier).
static func _curve(a: Vector2, mid: Vector2, b: Vector2) -> PackedVector2Array:
	var control := 2.0 * mid - (a + b) / 2.0
	var points := PackedVector2Array()
	for i in 7:
		var t := i / 6.0
		points.append(a.lerp(control, t).lerp(control.lerp(b, t), t))
	return points


## The outline of an ellipse at `centre` with `radii`, from angle `from` to `to` (a whole
## turn without its end repeating the start, so it fills as a polygon).
static func _ellipse(centre: Vector2, radii: Vector2, from: float, to: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 12 if is_equal_approx(to - from, TAU) else 13:
		points.append(centre + Vector2.from_angle(lerpf(from, to, i / 12.0)) * radii)
	return points


## Whether Reduce Motion is on (no Game outside the tree: a test's loose rig moves); the
## mime's dizzy stars ask it too.
func reduce_motion() -> bool:
	return GameState.reduce_motion_for(self)
