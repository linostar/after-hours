class_name SettingsMenu
extends Control
## The settings overlay, wordless: one toggle per setting (music, sound, motion, assist;
## Save.SETTINGS), lit when on and crossed out (its Off mark) when off (the motion toggle
## shows the motion effects: crossed out when reduce_motion is on), each change applied
## and saved at once (Game.set_setting); back closes it. It runs while the tree is
## paused (the pause menu opens it) and takes every touch while shown. The panel sits over
## the world (Game.world_offset).

## Emitted when back closes it.
signal closed

## Toggle node name -> its setting.
const TOGGLES: Dictionary[String, String] = {
	"MusicToggle": "music",
	"SoundToggle": "sound",
	"MotionToggle": "reduce_motion",
	"AssistToggle": "assist",
}
## Toggles that show their setting's opposite.
const INVERTED: Array[String] = ["MotionToggle"]

@onready var _back: Button = $Panel/BackButton
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	for node_name in TOGGLES:
		var toggle := get_node("Panel/" + node_name) as Button
		toggle.toggled.connect(_on_toggled.bind(toggle, TOGGLES[node_name]))
	_back.pressed.connect(close)
	_game.screen_fit_changed.connect(_fit)
	_fit()
	hide()


## Shows the overlay with each toggle as its setting is, the first one focused.
func open() -> void:
	for node_name in TOGGLES:
		var toggle := get_node("Panel/" + node_name) as Button
		toggle.set_pressed_no_signal(_game.setting(TOGGLES[node_name]) != (node_name in INVERTED))
		_sync(toggle)
	show()
	(get_node("Panel/MusicToggle") as Button).grab_focus()
	print("[Settings] Open")


func close() -> void:
	hide()
	print("[Settings] Closed")
	closed.emit()


func _on_toggled(on: bool, toggle: Button, key: String) -> void:
	_game.set_setting(key, on != (str(toggle.name) in INVERTED))
	_sync(toggle)


## The Off mark shows on a toggle that is off.
func _sync(toggle: Button) -> void:
	(toggle.get_node("Off") as CanvasItem).visible = not toggle.button_pressed


func _fit() -> void:
	($Panel as Control).position = _game.world_offset()
