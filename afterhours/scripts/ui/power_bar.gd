class_name PowerBar
extends HBoxContainer
## The room's power bar, bottom right (in the world, so inside the safe area; clear of every
## wing's paintings, doors, HUD and recorded bot taps, which a test checks): one icon button
## per unlocked power (Powers.Power order: ball, rope, box; locked ones hidden), each with
## its key label (1, 2, 3: drawn art), dim and disabled once spent this visit, haloed while
## chosen. A press or its key picks a power (picked); Escape, while one is chosen, cancels it
## (cancelled). Raw input is read here only (scripts/ui). pop() is the unlock beat: the new
## power's button springs in after POP_DELAY with a glint and its sound.

## A power's button or key was pressed (a Powers.Power).
signal picked(power: int)
## Escape was pressed while a power was chosen.
signal cancelled

const KEYS: Array[Key] = [KEY_1, KEY_2, KEY_3]
const HALO := Color(0.95, 0.85, 0.4, 0.45)
const HALO_RIM := Color(0.95, 0.85, 0.4, 0.9)
const SPENT := Color(1.0, 1.0, 1.0, 0.3)
const GLINT := Color(1.0, 0.97, 0.85)
const POP_DELAY := 0.6
const POP_TIME := 0.5
const GLINT_TIME := 0.7

## The power chosen (-1: none), haloed.
var chosen := -1:
	set(value):
		chosen = value
		queue_redraw()
## The unlock beat's glint: the power it is on (-1: none) and its progress (0 to 1).
var _glint_on := -1
var _glint := 0.0

@onready var buttons: Array[Button] = [$Ball, $Rope, $Box]


func _ready() -> void:
	for i in buttons.size():
		buttons[i].pressed.connect(func() -> void: picked.emit(i))
		# The glint draws over the button's icon (its draw signal follows its own drawing).
		buttons[i].draw.connect(_draw_glint.bind(i))
	# Drawn with the bar's material (the room's GLOW: full brightness in the night).
	for node in find_children("*", "CanvasItem", true, false):
		(node as CanvasItem).use_parent_material = true


## Shows the buttons of `powers` only (the rest are locked: hidden), all ready; the bar
## hides with none.
func show_powers(powers: Array[Powers.Power]) -> void:
	for i in buttons.size():
		buttons[i].visible = powers.has(i)
		set_spent(i, false)
	visible = not powers.is_empty()


## Shows `power` as spent (dim, disabled) or ready.
func set_spent(power: int, spent: bool) -> void:
	buttons[power].disabled = spent
	buttons[power].modulate = SPENT if spent else Color.WHITE


## The unlock beat: `power`'s button springs in from nothing (fades in under Reduce Motion)
## after POP_DELAY, with a glint across it and the power_unlock sound.
func pop(power: int) -> void:
	var button := buttons[power]
	var calm := GameState.reduce_motion_for(self)
	if calm:
		button.self_modulate.a = 0.0
	else:
		button.scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_interval(POP_DELAY)
	tween.tween_callback(func() -> void:
		button.pivot_offset = button.size / 2.0
		Audio.play_for(self, &"power_unlock"))
	if calm:
		tween.tween_property(button, "self_modulate:a", 1.0, POP_TIME)
	else:
		tween.tween_property(button, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_glint_on = power
	tween.tween_method(_set_glint, 0.0, 1.0, GLINT_TIME)
	tween.tween_callback(func() -> void: _glint_on = -1)


func _set_glint(progress: float) -> void:
	_glint = progress
	if _glint_on >= 0:
		buttons[_glint_on].queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo or not is_visible_in_tree():
		return
	var power := KEYS.find(key.physical_keycode)
	if power >= 0 and buttons[power].visible:
		get_viewport().set_input_as_handled()
		picked.emit(power)
	elif key.physical_keycode == KEY_ESCAPE and chosen >= 0:
		get_viewport().set_input_as_handled()
		cancelled.emit()


func _draw() -> void:
	if chosen >= 0 and buttons[chosen].visible:
		var centre := buttons[chosen].get_rect().get_center()
		var reach := buttons[chosen].size.x * 0.62
		draw_circle(centre, reach, HALO)
		draw_arc(centre, reach, 0.0, TAU, 40, HALO_RIM, 2.5, true)


## The unlock beat's glint on button `i`: a four-point sparkle sweeping across it (still,
## fading, under Reduce Motion).
func _draw_glint(i: int) -> void:
	if _glint_on != i:
		return
	var button := buttons[i]
	var calm := GameState.reduce_motion_for(self)
	var at := button.size / 2.0 if calm else button.size * _glint
	var sparkle := 22.0 * sin(PI * _glint)
	var color := Color(GLINT, 0.9 * sin(PI * _glint))
	button.draw_line(at - Vector2(sparkle, 0.0), at + Vector2(sparkle, 0.0), color, 2.5, true)
	button.draw_line(at - Vector2(0.0, sparkle), at + Vector2(0.0, sparkle), color, 2.5, true)
	button.draw_circle(at, sparkle * 0.25, color)
