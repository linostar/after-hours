class_name StrokePad
extends Control
## The forgery canvas's touch surface: one finger paints one stroke (press, drags,
## release), whatever its index; other fingers are ignored while it paints. Positions
## are pad-local, in canvas units.

signal stroke_started(at: Vector2)
signal stroke_moved(at: Vector2)
signal stroke_ended(at: Vector2)

## The painting finger's index, or -1 while none paints.
var _finger := -1


## Forgets a stroke in progress (the canvas closed under the finger).
func reset() -> void:
	_finger = -1


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch != null:
		accept_event()
		if touch.pressed and _finger == -1:
			_finger = touch.index
			stroke_started.emit(touch.position)
		elif not touch.pressed and touch.index == _finger:
			_finger = -1
			stroke_ended.emit(touch.position)
		return
	var drag := event as InputEventScreenDrag
	if drag != null and drag.index == _finger:
		accept_event()
		stroke_moved.emit(drag.position)
