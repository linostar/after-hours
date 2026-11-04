class_name WingDoor
extends Node2D
## A wing's door in the hub's back wall, wordless: the wing's painting hangs above an
## archway (its origin is the floor spot in front of it, where the mime goes through within
## Door.REACH), the best stars of the wing (Save) sit between them once it was escaped
## from, and a locked door is chained shut (a tap rattles the chain) with its painting dimmed.
## A wing whose data is broken shows the error badge on its door and never opens.
## unlock() plays the moment a wing opens (the hub, once): the chains slide off and fade, the
## padlock drops to the floor with a bounce, and the painting brightens.

const OPENING := Rect2(-25, -98, 50, 72)
const PICTURE_CENTER := Vector2(0, -150)
const PICTURE_SIZE := Vector2(84, 62)
const STAR_SIZE := 18.0
const STAR_ROW_Y := -114.0
## How far around the door, its painting and its spot a tap still means the door.
const TAP_RECT := Rect2(-58, -190, 116, 214)
const DARK := Color(0.1, 0.07, 0.09)
const ARCH := Color(0.62, 0.52, 0.36)
const CHAIN := Color(0.7, 0.7, 0.74)
const LOCK := Color(0.85, 0.7, 0.3)
const DIM := Color(0.45, 0.45, 0.5)
const RATTLE_ANGLE := 0.12
const RATTLE_TIME := 0.32
## The unlock: the wait before it starts (the wipe opening), how long the chains take to
## fall, how far they slide down, and where the padlock lands (door-local floor).
const UNLOCK_DELAY := 0.7
const UNLOCK_TIME := 0.8
const CHAIN_DROP := 40.0
const LOCK_FLOOR := -10.0
const STAR := preload("res://art/svg/star.svg")
const STAR_EMPTY := preload("res://art/svg/star_empty.svg")
const BADGE := preload("res://art/svg/error_badge.svg")

## The wing's index in Content.WINGS and its painting.
var index := 0
var painting := "pearl_earring"
var open := false
## Whether the wing was escaped from, and its best stars then.
var finished := false
var stars := 0
var broken := false
## Whether the unlock beat plays (open, its chains still falling).
var unlocking := false
## How far into the unlock: 0 chained, 1 gone.
var _fall := 0.0:
	set(value):
		_fall = value
		queue_redraw()
var _picture: FramedPainting
## The chain's swing while it rattles.
var _rattle := 0.0:
	set(value):
		_rattle = value
		queue_redraw()


func _ready() -> void:
	if broken:
		return
	_picture = FramedPainting.new()
	_picture.size = PICTURE_SIZE
	_picture.moulding = 4.0
	_picture.position = PICTURE_CENTER
	_picture.painting = painting
	_picture.modulate = Color.WHITE if open and not unlocking else DIM
	add_child(_picture)


## Where a tap means this door (hub coordinates).
func rect() -> Rect2:
	return Rect2(position + TAP_RECT.position, TAP_RECT.size)


## Plays the unlock beat after UNLOCK_DELAY: chains falling, padlock dropping, the painting
## brightening (the hub sets `unlocking` before the door enters the tree, so it starts chained).
func unlock() -> void:
	unlocking = true
	_fall = 0.0
	var beat := create_tween()
	beat.tween_interval(UNLOCK_DELAY)
	beat.tween_callback(Audio.play_for.bind(self, &"chains_fall"))
	beat.tween_property(self, "_fall", 1.0, UNLOCK_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	beat.parallel().tween_property(_picture, "modulate", Color.WHITE, UNLOCK_TIME)
	beat.tween_callback(func() -> void: unlocking = false; queue_redraw())
	print("[Hub] Wing door %d unlocks" % (index + 1))


## Shakes the chain of a locked door.
func rattle() -> void:
	Audio.play_for(self, &"chain_rattle")
	var swing := create_tween()
	for angle: float in [RATTLE_ANGLE, -RATTLE_ANGLE, RATTLE_ANGLE / 2.0, 0.0]:
		swing.tween_property(self, "_rattle", angle, RATTLE_TIME / 4.0)


func _draw() -> void:
	draw_rect(OPENING.grow(5.0), ARCH)
	draw_circle(Vector2(0, OPENING.position.y), OPENING.size.x / 2.0 + 5.0, ARCH)
	draw_rect(OPENING, DARK)
	draw_circle(Vector2(0, OPENING.position.y), OPENING.size.x / 2.0, DARK)
	if finished:
		for i in 3:
			var at := Vector2((i - 1) * (STAR_SIZE + 4.0) - STAR_SIZE / 2.0, STAR_ROW_Y - STAR_SIZE / 2.0)
			draw_texture_rect(STAR if i < stars else STAR_EMPTY, Rect2(at, Vector2(STAR_SIZE, STAR_SIZE)), false)
	if broken:
		draw_texture_rect(BADGE, Rect2(Vector2(-24, -86), Vector2(48, 48)), false)
	elif not open:
		_draw_chain()
	elif unlocking:
		_draw_falling()


## Two chains crossing the doorway and a padlock where they meet, swinging by _rattle.
func _draw_chain() -> void:
	var middle := OPENING.get_center()
	draw_set_transform(middle, _rattle)
	var half := OPENING.size / 2.0 + Vector2(4, -8)
	for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		var from := -half * direction
		var links := 7
		for i in links:
			var at := from.lerp(half * direction, (i + 0.5) / links)
			draw_arc(at, 5.0, 0.0, TAU, 10, CHAIN, 2.5)
	draw_rect(Rect2(-10, -2, 20, 16), LOCK)
	draw_arc(Vector2(0, -2), 7.0, PI, TAU, 10, LOCK, 3.0)
	draw_circle(Vector2(0, 6), 2.5, DARK)
	draw_set_transform(Vector2.ZERO)


## The unlock under way: the chains slide down and fade as one, the padlock falls ahead of
## them to the floor and bounces once (not under Reduce Motion).
func _draw_falling() -> void:
	var chains := 1.0 - _fall
	if chains > 0.0:
		draw_set_transform(Vector2(0, CHAIN_DROP * _fall), 0.0)
		_draw_chains(chains)
	var middle := OPENING.get_center()
	# The lock lands at 0.6 of the fall and bounces back to the floor by the end.
	var t := clampf(_fall / 0.6, 0.0, 1.0)
	var y := lerpf(middle.y, LOCK_FLOOR, t * t)
	if _fall > 0.6 and not GameState.reduce_motion_for(self):
		y = LOCK_FLOOR - sin((_fall - 0.6) / 0.4 * PI) * 10.0
	draw_set_transform(Vector2(0, y - 6.0), _fall * 0.6)
	draw_rect(Rect2(-10, -2, 20, 16), LOCK)
	draw_arc(Vector2(0, -2), 7.0, PI, TAU, 10, LOCK, 3.0)
	draw_circle(Vector2(0, 6), 2.5, DARK)
	draw_set_transform(Vector2.ZERO)


## The two crossing chains (without the lock) at `alpha`, under the current transform.
func _draw_chains(alpha: float) -> void:
	var half := OPENING.size / 2.0 + Vector2(4, -8)
	var middle := OPENING.get_center()
	var colour := Color(CHAIN, alpha)
	for direction: Vector2 in [Vector2(1, 1), Vector2(1, -1)]:
		var from := middle - half * direction
		var links := 7
		for i in links:
			var at := from.lerp(middle + half * direction, (i + 0.5) / links)
			draw_arc(at, 5.0, 0.0, TAU, 10, colour, 2.5)
