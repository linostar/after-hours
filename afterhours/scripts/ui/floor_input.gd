class_name FloorInput
extends Control
## The room's touch surface. Every pressed touch, whatever its index (a web build's index
## is the browser's Touch.identifier, which iOS Safari makes large and never 0), is a tap
## at its position in canvas base units; releases and drags are ignored.

## A pressed touch at `at` (canvas base units).
signal tapped(at: Vector2)


func _gui_input(event: InputEvent) -> void:
	var touch := event as InputEventScreenTouch
	if touch == null or not touch.pressed:
		return
	accept_event()
	tapped.emit(get_global_transform() * touch.position)
