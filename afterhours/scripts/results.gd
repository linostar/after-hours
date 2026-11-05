class_name Results
extends Control
## The end-of-wing overlay, wordless: three stars over their legend icons (swap, unseen,
## par clock), each popping in STAR_GAP after the last, gold when earned and dark when
## missed; then replay (the wing again, from its start) and home (the hub) icon buttons.
## The mime stands at the panel's side; after the last star a three-star run bursts into
## paint-dab confetti (Confetti) while the mime bows, and a rosette pops in by the stars for
## a new best star count and on the clock for a new best time (Save.improvement); the wing's
## sketch, picked up on this play, pops in by the buttons. Last the wing's four challenge
## badges (Challenges) pop in along the panel's foot, a completed one bright with
## the `challenge` sound, the others dim; one completed for the first time also pins a small
## rosette at its corner (`challenge_new`).
## The panel sits over the room (Game.world_offset). While shown it takes every touch, so
## the room below gets none.

const STAR_GAP := 0.35
const POP_TIME := 0.25
const STAR_EARNED := preload("res://art/svg/star.svg")
const STAR_MISSED := preload("res://art/svg/star_empty.svg")
const ROSETTE := preload("res://art/svg/rosette.svg")
## The bow after a three-star run, and where the confetti bursts from (panel-local).
const BOW_TIME := 1.2
const BURST_AT := Vector2(480, 120)
## The challenge badges' row along the panel's foot, under the buttons (panel-local): the first
## badge's top left, a badge's side and the step to the next; a missed badge's dimming; a first
## completion's rosette, from its badge's top left.
const BADGE_FROM := Vector2(382, 404)
const BADGE_SIZE := 40.0
const BADGE_STEP := 52.0
const BADGE_DIM := Color(0.4, 0.4, 0.45, 0.55)
const BADGE_NEW_OFFSET := Vector2(28, -8)
const BADGE_NEW_SIZE := Vector2(18, 23)

@onready var _stars: Array[TextureRect] = [$Panel/Star0, $Panel/Star1, $Panel/Star2]
@onready var _replay: Button = $Panel/ReplayButton
@onready var _home: Button = $Panel/HomeButton
@onready var mime: CharacterRig = $Panel/Mime
@onready var confetti: Confetti = $Panel/Confetti
@onready var stars_best: TextureRect = $Panel/StarsBest
@onready var time_best: TextureRect = $Panel/TimeBest
@onready var sketch: TextureRect = $Panel/Sketch
## The challenge badges and their first-completion rosettes, in Challenge order.
var badges: Array[TextureRect] = []
var badge_rosettes: Array[TextureRect] = []


func _ready() -> void:
	var game := get_node(GameState.AUTOLOAD_PATH) as GameState
	_replay.pressed.connect(game.replay)
	_home.pressed.connect(game.goto.bind(GameState.Flow.HUB))
	for i in Challenges.ICONS.size():
		var at := BADGE_FROM + Vector2(i * BADGE_STEP, 0)
		badges.append(_badge_rect("Challenge%d" % i, Challenges.ICONS[i], Rect2(at, Vector2.ONE * BADGE_SIZE)))
		badge_rosettes.append(_badge_rect("Challenge%dNew" % i, ROSETTE, Rect2(at + BADGE_NEW_OFFSET, BADGE_NEW_SIZE)))
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


## A hidden badge (or rosette) of the challenge row on the panel, popping about its centre.
func _badge_rect(id: String, texture: Texture2D, place: Rect2) -> TextureRect:
	var badge := TextureRect.new()
	badge.name = id
	badge.texture = texture
	badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = place.position
	badge.size = place.size
	badge.pivot_offset = place.size / 2.0
	badge.hide()
	$Panel.add_child(badge)
	return badge


## Shows `stars` (Stars.Star order), popping in one by one, then the celebration of a
## three-star run, the rosettes for what the escape `beaten` (Save.improvement), the
## `found` sketch (a Paintings.SKETCHES texture; null when none was picked up) and the
## `challenges` badges (Challenge order; none shown when empty), those first completed
## (`beaten`'s "challenges") with a rosette.
func present(stars: Array[bool], beaten := {}, found: Texture2D = null, challenges: Array[bool] = []) -> void:
	show()
	stars_best.hide()
	time_best.hide()
	sketch.hide()
	for badge in badges + badge_rosettes:
		badge.hide()
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
	if found != null:
		sketch.texture = found
		pops.tween_callback(_pop_sketch)
		pops.tween_interval(STAR_GAP)
	var fresh: Array = beaten.get("challenges", [])
	for i in mini(challenges.size(), badges.size()):
		pops.tween_callback(_pop_badge.bind(i, challenges[i], i < fresh.size() and fresh[i]))
		pops.tween_interval(STAR_GAP)
	print("[Results] Stars %s (%d of 3), new best: %s, challenges: %s, sketch: %s" % [stars, Stars.count(stars), beaten, challenges, found != null])
	# Where the buttons landed (screen base units), for the web smoke test's taps.
	print("[Results] Home button at %s" % _home.get_global_rect().get_center())


## A three-star run: confetti and the mime's bow.
func _celebrate() -> void:
	confetti.burst(BURST_AT, mime.reduce_motion())
	mime.start_fidget(CharacterRig.Fidget.BOW, BOW_TIME)
	Audio.play_for(self, &"confetti")
	print("[Results] Three stars: confetti and a bow")


func _pop_sketch() -> void:
	sketch.show()
	sketch.scale = Vector2.ZERO
	create_tween().tween_property(sketch, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_for(self, &"sketch_found")


func _pop_rosette(rosette: TextureRect, sound := &"new_best") -> void:
	rosette.show()
	rosette.scale = Vector2.ZERO
	create_tween().tween_property(rosette, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Audio.play_for(self, sound)


## Challenge `index`'s badge pops in, bright when `done` (with its sound), dim otherwise; a
## `first` completion also pins its rosette.
func _pop_badge(index: int, done: bool, first: bool) -> void:
	var badge := badges[index]
	badge.modulate = Color.WHITE if done else BADGE_DIM
	badge.show()
	badge.scale = Vector2.ZERO
	create_tween().tween_property(badge, "scale", Vector2.ONE, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if done:
		Audio.play_for(self, &"challenge", pow(2.0, index * 2.0 / 12.0))
	if first:
		_pop_rosette(badge_rosettes[index], &"challenge_new")
