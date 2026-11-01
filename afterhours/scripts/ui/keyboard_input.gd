class_name KeyboardInput
extends Node
## The room's keyboard (accessibility, CLAUDE.md): the arrows (the built-in ui_* actions)
## or WASD (physical keys) walk the mime, E interacts with whatever is nearest, Space
## pauses (read before the GUI, so a focused button does not take it as ui_accept). Raw
## input is read here only (scripts/ui).

## Emitted when E is pressed (not on key repeat).
signal interacted
## Emitted when Space is pressed (not on key repeat).
signal pause_pressed


## The held walking direction, at most length 1 (arrows and WASD add up).
func direction() -> Vector2:
	var keys := Vector2(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	return (Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") + keys).limit_length(1.0)


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_SPACE and pause_pressed.has_connections():
		get_viewport().set_input_as_handled()
		pause_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_E:
		get_viewport().set_input_as_handled()
		interacted.emit()
