class_name Results
extends Control
## The end-of-wing overlay, wordless: three stars over their legend icons (swap, unseen,
## par clock), each popping in STAR_GAP after the last, gold when earned and dark when
## missed; then replay (the wing again, from its start) and home (the title) icon buttons.
## The panel sits over the room (Game.world_offset). While shown it takes every touch, so
## the room below gets none.

const STAR_GAP := 0.35
const POP_TIME := 0.25
const STAR_EARNED := preload("res://art/svg/star.svg")
const STAR_MISSED := preload("res://art/svg/star_empty.svg")

@onready var _stars: Array[TextureRect] = [$Panel/Star0, $Panel/Star1, $Panel/Star2]
@onready var _replay: Button = $Panel/ReplayButton
@onready var _home: Button = $Panel/HomeButton


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_replay.pressed.connect(game.replay)
	_home.pressed.connect(game.goto.bind(GameState.Flow.TITLE))
	game.screen_fit_changed.connect(_fit.bind(game))
	_fit(game)
	hide()


## The dim covers the screen; the panel (on the 960x540 base) sits over the room.
func _fit(game: GameState) -> void:
	($Panel as Control).position = game.world_offset()


## Shows the overlay and pops in `stars` (Stars.Star order).
func present(stars: Array[bool]) -> void:
	show()
	_replay.grab_focus()
	var pops := create_tween()
	for i in _stars.size():
		var star := _stars[i]
		star.texture = STAR_EARNED if stars[i] else STAR_MISSED
		star.scale = Vector2.ZERO
		pops.tween_interval(STAR_GAP)
		pops.tween_property(star, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	print("[Results] Stars %s (%d of 3)" % [stars, Stars.count(stars)])
