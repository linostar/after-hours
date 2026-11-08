class_name RoomPowers
extends RefCounted
## The mime's powers in one room (a part of Room, which ticks it and hands it taps; it works
## the room's mime, frames and hiding as the room's own code does). The powers (Powers, those
## its wing has unlocked) sit on the PowerBar, each usable once per visit (refilled on entering
## a room, not by a toss; WingRun.powers_used counts every use): a press (or key 1, 2, 3)
## chooses the ball or the rope, showing its reach round the mime, and the next tap is its
## target (the same button, Escape or a tap on no target cancels it): the ball is thrown at a
## floor spot within Powers.BALL_RANGE (a noise there, heard like a tilt), the rope tilts a
## straight frame within Powers.ROPE_RANGE from afar (its noise and sketch as a tilt); out of
## reach (or a frame already tilted) the mime shrugs and the power stays ready. The box needs
## no target: the mime hides in it where it stands, as in a portrait (a guard who sees it step
## in chases it there), until the next tap, a key walk, E, a catch or Powers.BOX_TIME steps it
## out. On the first entry of a play of the wing that unlocks a power, while it was never
## escaped from, the power pops into the bar.

## The powers this room's wing has unlocked (Powers.unlocked), which are spent this visit (in
## Powers.Power order), and the one chosen and waiting for its target (-1: none).
var unlocked: Array[Powers.Power] = []
var spent: Array[bool] = [false, false, false]
var chosen := -1
## While the mime hides in its invisible box: the box (null otherwise) and its seconds left.
var box: PowerFx
var _box_left := 0.0
## The chosen power's reach, round the mime's feet.
var reach_ring: PowerFx
var _room: Room
var _game: GameState


func _init(of: Room) -> void:
	_room = of
	_game = of.get_node(GameState.AUTOLOAD_PATH) as GameState


## The powers of the room's wing on the bar (none in a replay), all ready: a room is a new
## visit. On the play's first entry (`visit` 0 of the room it starts in) of the wing that
## unlocks a power, while it was never escaped from, that power pops in (PowerBar.pop).
func set_up(visit: int) -> void:
	var run := _room.run
	var bar := _room.power_bar
	var wing_path := run.wing.resource_path
	unlocked = Powers.unlocked(wing_path)
	if run.replaying:
		unlocked.clear()
	bar.material = Room.GLOW
	bar.show_powers(unlocked)
	bar.picked.connect(pick)
	bar.cancelled.connect(cancel)
	reach_ring = PowerFx.spawn(_room, PowerFx.Kind.RING, Room.GLOW)
	reach_ring.hide()
	var new_power := Powers.unlocked_by(wing_path)
	if new_power >= 0 and unlocked.has(new_power) and run.came_from == WingRun.START and visit == 0 and not Save.finished(_game.save, Content.wing_id(wing_path)):
		bar.pop(new_power)
		print("[Room] Unlock beat: the %s power pops into the bar" % Powers.Power.keys()[new_power])


## Each physics tick (from the room): the reach ring follows the mime, and the box steps it
## out once its time is up.
func tick(delta: float) -> void:
	reach_ring.position = _room.mime.position
	if box != null:
		_box_left -= delta
		if _box_left <= 0.0:
			_room._step_out()


## A power's button or key: chooses it (the box is used at once), or, chosen already,
## cancels it; not while the mime cannot act or hides, nor once spent.
func pick(power: int) -> void:
	if not unlocked.has(power) or spent[power] or not _room._accepts_input() or _room.is_hidden():
		return
	if chosen == power:
		cancel()
		return
	if power == Powers.Power.BOX:
		cancel()
		_use_box()
		return
	chosen = power
	_room.power_bar.chosen = power
	reach_ring.radius = Powers.BALL_RANGE if power == Powers.Power.BALL else Powers.ROPE_RANGE
	reach_ring.position = _room.mime.position
	reach_ring.show()
	print("[Room] Chose the %s power" % Powers.Power.keys()[power])


## Drops the chosen power (logged as a cancel unless `used`).
func cancel(used := false) -> void:
	if chosen >= 0 and not used:
		print("[Room] Power cancelled")
	chosen = -1
	_room.power_bar.chosen = -1
	reach_ring.hide()


## The chosen power's target tap at `at`: the ball thrown there, the rope on the straight
## frame there; out of reach (or a tilted frame) a shrug, the power still ready; a rope tap
## on no frame just cancels it.
func aim(at: Vector2) -> void:
	var power := chosen
	var mime := _room.mime
	cancel(true)
	if power == Powers.Power.BALL:
		if mime.position.distance_to(at) > Powers.BALL_RANGE:
			mime.shrug()
			return
		_throw_ball(at)
		return
	for frame in _room._frames:
		if frame.rect().has_point(at):
			if frame.tilted or mime.position.distance_to(frame.spot()) > Powers.ROPE_RANGE:
				mime.shrug()
			else:
				_pull_rope(frame)
			return
	print("[Room] Power cancelled: the rope tapped on no frame")


## Steps the mime out of its box (Room._step_out, while it hides in one).
func leave_box() -> void:
	print("[Room] Stepped out of the box at %s at t %.2f" % [_room.mime.position.round(), _room.elapsed])
	_game.audio.play(&"unhide")
	box.queue_free()
	box = null
	_room.mime.visible = true


## Spends `power` for this visit (counted in the run).
func _spend(power: Powers.Power) -> void:
	spent[power] = true
	_room.power_bar.set_spent(power, true)
	_room.run.powers_used += 1


## The mime stops what it was about to do and stands where it is (to use a power).
func _stand_still() -> void:
	_room._drop_pending()
	_room.mime.place_at(_room.mime.position)


## Throws the invisible ball at `at`: where it lands, the nearest active guard in earshot
## hears it as he would a tilted frame.
func _throw_ball(at: Vector2) -> void:
	var mime := _room.mime
	_spend(Powers.Power.BALL)
	_stand_still()
	mime.face_toward(at)
	mime.rig.start_fidget(CharacterRig.Fidget.THROW, PowerFx.THROW_TIME)
	_game.audio.play(&"ball_throw")
	var ball := PowerFx.spawn(_room, PowerFx.Kind.BALL, Room.GLOW)
	ball.from = mime.position + PowerFx.HAND
	ball.to = at
	ball.landed.connect(_on_ball_landed.bind(at))
	print("[Room] Threw the ball from %s to %s at t %.2f" % [mime.position.round(), at.round(), _room.elapsed])


func _on_ball_landed(at: Vector2) -> void:
	if _room.finished or _room.leaving:
		return
	_game.audio.play(&"ball_land")
	var heard := _room.nearest_in_earshot(at)
	if heard != null:
		heard.hear(at)
	print("[Room] The ball landed at %s at t %.2f (heard by: %s)" % [at.round(), _room.elapsed, str(heard.name) if heard != null else "nobody"])


## Pulls `frame` crooked with the invisible rope: a tilt from afar (its noise and sketch).
func _pull_rope(frame: TiltFrame) -> void:
	var mime := _room.mime
	_spend(Powers.Power.ROPE)
	_stand_still()
	mime.face_toward(frame.position)
	mime.rig.start_fidget(CharacterRig.Fidget.PULL, PowerFx.PULL_TIME)
	_game.audio.play(&"rope_pull")
	var rope := PowerFx.spawn(_room, PowerFx.Kind.ROPE, Room.GLOW)
	rope.from = mime.position + PowerFx.HAND
	rope.to = frame.position + Vector2(0.0, TiltFrame.SIZE.y / 2.0)
	print("[Room] Pulled the frame at %s with the rope from %s" % [frame.position.round(), mime.position.round()])
	_room._tilt(frame)


## The mime mimes the invisible box where it stands and hides in it (seen stepping in, it is
## chased there as in a portrait) for at most Powers.BOX_TIME.
func _use_box() -> void:
	var mime := _room.mime
	_spend(Powers.Power.BOX)
	_stand_still()
	var seen := _room._seen_stepping_in()
	# Among the actors, y-sorted with the guards walking past it.
	box = PowerFx.spawn(_room.get_node("Actors"), PowerFx.Kind.BOX, Room.GLOW)
	box.z_index = 0
	box.position = mime.position
	_box_left = Powers.BOX_TIME
	mime.visible = false
	_game.audio.play(&"box_up")
	print("[Room] Hid in the box at %s at t %.2f (seen going in: %s)" % [mime.position.round(), _room.elapsed, seen])
