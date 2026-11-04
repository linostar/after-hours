class_name Results
extends Control
## The end-of-wing overlay, wordless: three stars over their legend icons (swap, unseen,
## par clock), each popping in STAR_GAP after the last, gold when earned and dark when
## missed; then replay (the wing again, from its start) and home (the hub) icon buttons.
## The mime stands at the panel's side; after the last star a three-star run bursts into
## paint-dab confetti (Confetti) while the mime bows, and a rosette pops in by the stars for
## a new best star count and on the clock for a new best time (Save.improvement).
## The panel sits over the room (Game.world_offset). While shown it takes every touch, so
## the room below gets none.

const STAR_GAP := 0.35
const POP_TIME := 0.25
const STAR_EARNED := preload("res://art/svg/star.svg")
const STAR_MISSED := preload("res://art/svg/star_empty.svg")
## The bow after a three-star run, and where the confetti bursts from (panel-local).
const BOW_TIME := 1.2
const BURST_AT := Vector2(480, 120)

@onready var _stars: Array[TextureRect] = [$Panel/Star0, $Panel/Star1, $Panel/Star2]
@onready var _replay: Button = $Panel/ReplayButton
@onready var _home: Button = $Panel/HomeButton
@onready var mime: CharacterRig = $Panel/Mime
@onready var confetti: Confetti = $Panel/Confetti
@onready var stars_best: TextureRect = $Panel/StarsBest
@onready var time_best: TextureRect = $Panel/TimeBest


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_replay.pressed.connect(game.replay)
	_home.pressed.connect(game.goto.bind(GameState.Flow.HUB))
	game.screen_fit_changed.connect(_fit.bind(game))
	_fit(game)
	hide()


## The dim covers the screen; the panel (on the 960x540 base) sits over the room.
func _fit(game: GameState) -> void:
	($Panel as Control).position = game.world_offset()


## The mime stands alive at the panel's side (busy: no idle gag over the results).
func _process(delta: float) -> void:
	if visible:
		mime.walk(0.0, delta, false)


## Shows `stars` (Stars.Star order), popping in one by one, then the celebration of a
## three-star run and the rosettes for what the escape `beaten` (Save.improvement).
func present(stars: Array[bool], beaten := {}) -> void:
	show()
	stars_best.hide()
	time_best.hide()
	(get_node(GameState.AUTOLOAD_PATH) as GameState).audio.play_music("results")
	_replay.grab_focus()
	var pops := create_tween()
	for i in _stars.size():
		var star := _stars[i]
		star.texture = STAR_EARNED if stars[i] else STAR_MISSED
		star.scale = Vector2.ZERO
		pops.tween_interval(STAR_GAP)
		pops.tween_callback(Audio.play_for.bind(self, &"star" if stars[i] else &"no_star", pow(2.0, i * 4.0 / 12.0)))
		pops.tween_property(star, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pops.tween_interval(STAR_GAP)
	if Stars.count(stars) == stars.size():
		pops.tween_callback(_celebrate)
	for best: Array in [[stars_best, beaten.get("stars", false)], [time_best, beaten.get("time", false)]]:
		if best[1]:
			pops.tween_callback(_pop_rosette.bind(best[0]))
			pops.tween_interval(STAR_GAP)
	print("[Results] Stars %s (%d of 3), new best: %s" % [stars, Stars.count(stars), beaten])
	# Where the buttons landed (screen base units), for the web smoke test's taps.
	print("[Results] Home button at %s" % _home.get_global_rect().get_center())


## A three-star run: confetti and the mime's bow.
func _celebrate() -> void:
	confetti.burst(BURST_AT, mime.reduce_motion())
	mime.start_fidget(CharacterRig.Fidget.BOW, BOW_TIME)
	Audio.play_for(self, &"confetti")
	print("[Results] Three stars: confetti and a bow")


func _pop_rosette(rosette: TextureRect) -> void:
	rosette.show()
	rosette.scale = Vector2.ZERO
	create_tween().tween_property(rosette, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_for(self, &"new_best")
