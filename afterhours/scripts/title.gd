extends Control
## The title screen (the main scene): the museum at night (TitleScene: stars, the moon's halo,
## its columned front, the mime sneaking past), the logo (drawn art, the jam's allowed
## exception to No Text) swaying gently on its nail, still under Reduce Motion, above the
## museum's door, a gilded frame holding the play button, which opens the hub (the lobby).
## Every button's focus ring is Game's gilt glow (ButtonFeel.FOCUS_RING). Run with
## `-- --wing N` (N from 1) to start wing N at once (development, locked or not; an N out
## of range, or a wing whose data is broken, is reported).

## Starts a wing at once (development).
const WING_FLAG := "--wing"
## The logo's sway: degrees either way, and swings per second (slow, far under 2 Hz).
const SWAY_DEGREES := 1.5
const SWAY_HZ := 0.2

var _sway := 0.0

@onready var _play: Button = $PlayButton
@onready var _logo: TextureRect = $Logo
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	_play.pressed.connect(_game.goto.bind(GameState.Flow.HUB))
	# Focused for Enter / Space, but hidden: the ring shows only once the keys move focus (on
	# the title it sat over the museum door's play frame and looked heavy).
	_play.grab_focus(true)
	_game.arrive(GameState.Flow.TITLE)
	_log_layout.call_deferred()
	var args := OS.get_cmdline_user_args()
	var at := args.find(WING_FLAG)
	if at >= 0:
		var number := int(args[at + 1]) if at + 1 < args.size() else 0
		if number >= 1 and number <= Content.WINGS.size():
			_game.play_wing_file.call_deferred(Content.WINGS[number - 1])
		else:
			_game.report_error("%s needs a wing number from 1 to %d (got '%s')" % [WING_FLAG, Content.WINGS.size(), " ".join(args.slice(at + 1, at + 2))])


func _process(delta: float) -> void:
	if _game.setting("reduce_motion"):
		_logo.rotation = 0.0
		return
	_sway = fmod(_sway + delta * SWAY_HZ, 1.0)
	_logo.rotation = deg_to_rad(SWAY_DEGREES) * sin(_sway * TAU)


## Where the play button landed (base units), for the web smoke test's taps.
func _log_layout() -> void:
	print("[Title] Play button at %s" % _play.get_global_rect())
