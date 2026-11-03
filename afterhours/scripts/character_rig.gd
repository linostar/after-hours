class_name CharacterRig
extends Node2D
## A character's drawing (the mime, the guards, the ghost mime), its origin at the feet: a
## body per view (front walking down, back walking up, side walking right, mirrored for
## left) with an arm and a leg each side pivoting at shoulder and hip, over a floor shadow.
## face() picks the view from a heading (view_for, with hysteresis so a diagonal does not
## flicker); walk() advances the walk cycle by the distance moved, swinging the limbs (side
## view) or lifting the feet in turn (front and back), bobbing the body and emitting stepped
## at every footfall (setting off from rest, then each step_length); with no distance the
## limbs settle to rest.

## Emitted at each footfall while walking.
signal stepped

enum View { FRONT, BACK, RIGHT, LEFT }

## A heading must lean this many times more toward the other axis before the view changes.
const HYSTERESIS := 1.3
## How fast the stride grows when walking starts and fades when it stops (per second).
const SETTLE_RATE := 10.0
## The side view's far arm and leg are shaded this much.
const FAR_SHADE := Color(0.7, 0.7, 0.76)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
## The shadow ellipse's height over its width.
const SHADOW_FLATTEN := 0.27

@export var body_front: Texture2D
@export var body_back: Texture2D
@export var body_side: Texture2D
@export var arm: Texture2D
@export var leg: Texture2D
## The bodies' canvas pixel that sits at the character's feet.
@export var feet_at := Vector2(24, 92)
## The hips and shoulders from the feet in the front view (x either side); the side view
## stands both legs SIDE_SPREAD apart at x 0 and both arms at x 0.
@export var hip := Vector2(5.5, -30)
@export var shoulder := Vector2(15.5, -56)
@export var side_spread := 3.0
## Base units walked per step (two steps a cycle).
@export var step_length := 50.0
## At full stride: the legs' and arms' swing (radians, side view), how far a foot lifts
## (front and back views) and how high the body bobs.
@export var leg_swing := 0.5
@export var arm_swing := 0.4
@export var lift := 5.0
@export var bob := 2.0
@export var shadow_radius := 15.0

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
## [left, right] in the front view; [far, near] in the side view.
var _legs: Array[Sprite2D] = []
var _arms: Array[Sprite2D] = []


## The view for `heading`, staying `current` for a zero heading and across the hysteresis
## band between the horizontal and the vertical views.
static func view_for(heading: Vector2, current: View) -> View:
	if heading.is_zero_approx():
		return current
	var across := absf(heading.x)
	var along := absf(heading.y)
	var horizontal: bool
	if current == View.RIGHT or current == View.LEFT:
		horizontal = along <= across * HYSTERESIS
	else:
		horizontal = across > along * HYSTERESIS
	if horizontal:
		return View.RIGHT if heading.x > 0.0 else View.LEFT
	return View.BACK if heading.y < 0.0 else View.FRONT


func _ready() -> void:
	for i in 2:
		_legs.append(_limb("Leg%d" % i, leg))
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.centered = false
	_body.offset = -feet_at
	add_child(_body)
	for i in 2:
		_arms.append(_limb("Arm%d" % i, arm))
	_apply()


func _limb(limb_name: String, texture: Texture2D) -> Sprite2D:
	var limb := Sprite2D.new()
	limb.name = limb_name
	limb.texture = texture
	limb.centered = false
	limb.offset = Vector2(-texture.get_width() / 2.0, 0.0)
	add_child(limb)
	return limb


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
	if is_side():
		_body.texture = body_side
		for i in 2:
			var near := i == 1
			_legs[i].position = Vector2(side_spread * (1.0 if near else -1.0) / 2.0, hip.y)
			_arms[i].position = Vector2(0.0, shoulder.y)
			_legs[i].self_modulate = Color.WHITE if near else FAR_SHADE
			_arms[i].self_modulate = Color.WHITE if near else FAR_SHADE
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
			_legs[i].self_modulate = Color.WHITE
			_arms[i].self_modulate = Color.WHITE
			_legs[i].rotation = 0.0
		# Legs, body, arms.
		move_child(_legs[0], 0)
		move_child(_legs[1], 1)
		move_child(_body, 2)
		move_child(_arms[0], 3)
		move_child(_arms[1], 4)
	_pose()


func _mirror() -> void:
	scale = Vector2(-squash.x if view == View.LEFT else squash.x, squash.y)


func _pose() -> void:
	var swing := sin(phase * TAU) * stride
	_body.position.y = -absf(swing) * bob
	if is_side():
		_legs[1].rotation = swing * leg_swing
		_legs[0].rotation = -swing * leg_swing
		_arms[1].rotation = -swing * arm_swing
		_arms[0].rotation = swing * arm_swing
		for each in _legs:
			each.position.y = hip.y
	else:
		_legs[0].position.y = hip.y - maxf(swing, 0.0) * lift
		_legs[1].position.y = hip.y - maxf(-swing, 0.0) * lift
		_arms[0].rotation = swing * arm_swing * 0.4
		_arms[1].rotation = swing * arm_swing * 0.4


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, SHADOW_FLATTEN))
	draw_circle(Vector2.ZERO, shadow_radius, SHADOW)
