extends Control
## The title screen (the main scene): a gilded frame on the gallery wall (where the logo
## will hang) holding the play button, which starts the room.

@onready var _play: Button = $PlayButton


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_play.pressed.connect(game.goto.bind(GameState.Flow.ROOM))
	_play.grab_focus()
	game.arrive(GameState.Flow.TITLE)
	_log_layout.call_deferred()


## Where the play button landed (base units), for the web smoke test's taps.
func _log_layout() -> void:
	print("[Title] Play button at %s" % _play.get_global_rect())
