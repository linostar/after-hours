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

## Emitted at each footfall while walking.
signal stepped

enum View { FRONT, BACK, RIGHT, LEFT }

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

var view := View.FRONT
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
	add_child(_body)
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
	upper.add_child(lower)
	return lower


## Turns the drawing toward `heading` (view_for).
func face(heading: Vector2) -> void:
	var next := view_for(heading, view)
	if next != view:
		view = next
		_apply()


## Moves the walk cycle on by `distance` (base units walked this frame; 0 standing) over
## `delta` seconds.
func walk(distance: float, delta: float) -> void:
	if distance > 0.0:
		var before := phase
		phase = fmod(phase + distance / (2.0 * step_length), 1.0)
		# The first foot leaving the floor is a footfall too, then one every step.
		if stride == 0.0 or floori(before * 2.0) != floori(phase * 2.0):
			stepped.emit()
		stride = minf(stride + SETTLE_RATE * delta, 1.0)
	else:
		stride = maxf(stride - SETTLE_RATE * delta, 0.0)
	_pose()


func is_side() -> bool:
	return view == View.RIGHT or view == View.LEFT


## Lays the parts out for the view: textures, pivots, draw order and the mirror.
func _apply() -> void:
	_mirror()
	var shin := leg_lower_side if is_side() and leg_lower_side != null else leg_lower
	for each in _shins:
		each.texture = shin
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
