class_name ButtonFeel
extends Node
## Game's button hook (a child of Game; not an autoload of its own): every button that
## enters the tree, whatever screen it is on, dips when pressed (touch, click or key) and
## shows keyboard focus as FOCUS_RING, a round gilt glow round its gilt-ringed icon (not the
## engine's white box). Audio's own node_added hook gives it its sound.

## A pressed button dips to this scale and springs back over PRESS_TIME.
const PRESS_SCALE := 0.9
const FOCUS_RING := preload("res://art/focus_ring.tres")
const PRESS_TIME := 0.14


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button != null:
		button.button_down.connect(_press.bind(button))
		button.add_theme_stylebox_override(&"focus", FOCUS_RING)


func _press(button: BaseButton) -> void:
	button.pivot_offset = button.size / 2.0
	# A press that pauses the tree (the pause button) still springs back.
	var tween := button.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(button, "scale", Vector2.ONE * PRESS_SCALE, PRESS_TIME / 2.0)
	tween.tween_property(button, "scale", Vector2.ONE, PRESS_TIME / 2.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
