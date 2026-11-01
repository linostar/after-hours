class_name PauseMenu
extends Control
## The pause overlay, wordless: open() pauses the tree (the room stops; this runs on) and
## shows resume, settings (the SettingsMenu over it) and home (back to the hub, the wing
## abandoned; the menu hides so nothing resumes the room during the fade) on a panel over the
## world (Game.world_offset). Resume, or Space (read here: raw input lives in scripts/ui),
## unpauses. While the menu shows, Space is taken here: it does nothing while the settings are
## open (it would press their focused toggle) or under the rotate overlay (that pause holds).

@onready var _resume: Button = $Panel/ResumeButton
@onready var _settings_button: Button = $Panel/SettingsButton
@onready var _settings: SettingsMenu = $SettingsMenu
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	_resume.pressed.connect(resume)
	_settings_button.pressed.connect(_settings.open)
	_settings.closed.connect(_settings_button.grab_focus)
	($Panel/HomeButton as Button).pressed.connect(_home)
	_game.screen_fit_changed.connect(_fit)
	_fit()
	hide()


func open() -> void:
	if visible:
		return
	get_tree().paused = true
	show()
	_resume.grab_focus()
	print("[Pause] Paused")


func resume() -> void:
	if not visible or _game.is_rotate_overlay_shown():
		return
	_settings.hide()
	hide()
	get_tree().paused = false
	print("[Pause] Resumed")


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if visible and key != null and key.physical_keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if key.pressed and not key.echo and not _settings.visible:
			resume()


## Leaves the wing for the hub; the tree stays paused until the hub replaces the room.
func _home() -> void:
	print("[Pause] Home")
	_settings.hide()
	hide()
	_game.goto(GameState.Flow.HUB)


func _fit() -> void:
	($Panel as Control).position = _game.world_offset()
