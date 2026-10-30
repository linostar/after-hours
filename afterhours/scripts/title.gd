extends Control
## The title screen (the main scene): a gilded frame on the gallery wall (where the logo
## will hang) holding the play button, which starts the room.

@onready var _play: Button = $PlayButton


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_play.pressed.connect(game.goto.bind(GameState.Flow.ROOM))
	_play.grab_focus(true)
	game.arrive(GameState.Flow.TITLE)
