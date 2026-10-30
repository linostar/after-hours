extends Node
## Violation: game code outside scripts/ui/ reads touches and gestures itself.


func is_shot(event: InputEvent) -> bool:
	return event is InputEventScreenTouch and event.is_pressed()


func is_drag(event: InputEvent) -> bool:
	return event is InputEventScreenDrag


func is_zoom(event: InputEvent) -> bool:
	return event is InputEventMagnifyGesture or event is InputEventPanGesture
