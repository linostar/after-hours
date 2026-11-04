class_name Room
extends Node2D
## A gallery room, seen 3/4 top-down. scenes/room_base.tscn holds what every room shares;
## each room scene inherits it (with its walls, floor and navmesh outline) and adds its
## partitions (StaticBody2D in the nav_obstacles group: the navmesh is baked around them on
## load; guards cannot see through them), guards (the Guard children of Actors),
## frames, portraits, doors and, optionally, the Easel, the Masterpiece and a Gimmick (the
## wing's twist: light, slowing and noisy floor for the guards and the mime; its footsteps
## on noisy floor are noises the nearest guard in earshot hears; a clue a guard notices
## sends it to investigate). The mime starts
## at the Entrance marker. A tap on the floor walks the mime there. A tap on the glowing
## easel (Easel.rect) walks it to Easel.spot, where the forgery canvas opens over the
## still-running room; a painted fake puts the glow out (tapping the easel again repaints
## it). With a fake, a tap on the masterpiece (painting_rect) walks the mime to swap_spot
## below it, where standing still for SWAP_TIME swaps the fake for the original (tapping
## elsewhere cancels the swap); a tap there without one is a tap on the floor. A tap on a
## straight small frame (a TiltFrame under Frames) walks the mime under it and tilts it: a
## noise the nearest guard in earshot hears (Guard.hear) and walks over to. A tap on a tall
## portrait (a HidingPortrait under Portraits) walks the mime there and it steps in, out of
## every guard's sight (a guard who sees it step in chases it there and pulls it out); the
## next tap steps it out and goes on as that tap. The keyboard (KeyboardInput) walks the
## mime directly (cancelling any of the above, stepping out of a portrait) and E acts as a
## tap on the nearest thing within INTERACT_REACH it can use (easel, masterpiece, straight
## frame, portrait; E while hidden steps out). Carrying the original, the exit (the Door
## under Doors whose to_room is Door.EXIT) glows, and the fake hangs in the original's
## place: every guard watches it (fake_view_point, the floor at its foot) and inspects it
## once per pass, a "?" over the painting while one does; a fake found out
## (Forgery.is_noticed; inspections count across the guards) turns the "?" into "!" for
## good, and the guard who found it out searches around it. Reaching the exit ends the
## wing: the stars (Stars, against par_time) are recorded (Game.record_escape) and, after
## the escape beat (the mime tips its beret and slips out, the door shuts; a tap skips it),
## show in the results overlay. A guard that
## chases the mime down (Guard) shakes it and tosses it back to the entrance (TOSS_SHAKE,
## then TOSS_FLIGHT along an arc TOSS_HEIGHT high), closing the canvas if it was painting
## (its finished strokes are kept); taps are ignored meanwhile, then every guard starts its
## route again (a mime carrying the fake or the original keeps it: only the guards reset).
## The timer (elapsed) keeps running through it all, but not while a screen change fades
## (the player cannot act then); ever_seen records whether any guard ever spotted the mime.
## A room is one of its wing's rooms (Game.run, a WingRun; a room loaded on its own makes a
## one-room run of itself): it takes the wing's painting, ghost strokes and par time, and the
## run's timer, sightings, catches, fake and original. A tap on a door to another room
## (a Door whose to_room is a room index) walks the mime through it: the room hands its
## state back to the run (with the hung fake's state there, which it finds again on a later
## visit) and Game.enter_room changes to that room, where the mime comes in at the door
## leading back (Door.arrival_point; the toss lands there too). The PauseButton (top left)
## or Space pauses the room under the pause menu (PauseMenu).

## Where the mime stands to swap the masterpiece (below it), and where a guard looks to
## inspect the hung fake: the floor at the painting's foot (sight rays to the painting
## itself would hit the back wall).
const SWAP_Y := 235.0
const FAKE_VIEW_Y := 180.0
const QUERY_ICON := preload("res://art/svg/icon_query.svg")
const GHOST_SCENE := preload("res://scenes/ghost_mime.tscn")
const ALARM_ICON := preload("res://art/svg/icon_alarm.svg")
## How close to the swap spot (or the easel's, a frame's or a portrait's) counts as
## standing there.
const SWAP_REACH := 8.0
const SWAP_TIME := 1.5
## How close (to where it would stand) the mime must be for E to use something.
const INTERACT_REACH := 70.0
const TOSS_SHAKE := 0.45
const TOSS_FLIGHT := 0.8
const TOSS_HEIGHT := 120.0
## The mime's wobble while the guard shakes it (radians either way).
const SHAKE_ANGLE := 0.3
## A catch shakes the screen this far (base units) for TOSS_SHAKE; a swap punches the
## camera in by SWAP_PUNCH for PUNCH_TIME (neither under Reduce Motion: Game.shake, punch).
const CAUGHT_SHAKE := 7.0
const SWAP_PUNCH := 0.04
const PUNCH_TIME := 0.3
## The escape beat: the beret tip, the slip through the doorway, the pause after the door
## shuts before the results.
const ESCAPE_TIP := 0.6
const ESCAPE_SLIP := 0.45
const ESCAPE_HOLD := 0.3
## The museum after dark: a CanvasModulate tints the whole room moonlit blue. What gives
## light (the guards' cones and eyes, the easel's glow, the gimmicks' lamps, windows and
## pools: GLOW, an unshaded material) and what the player reads or taps (the pause button,
## the fake's icon, tap ripples) is drawn at full brightness, against the dark. The
## picture lights (RoomLights) pick out what the player uses, drawn at LIT_SHARE of full
## brightness (lit_boost: the paintings, frames and portraits, the masterpiece, the doors,
## the easel, the carried painting); the characters draw through RIG_NIGHT (as bright, with
## a moonlit rim), so all of them read in the darkest corner.
const NIGHT := Color(0.26, 0.29, 0.52)
const LIT_SHARE := 0.88
const GLOW := preload("res://art/glow.tres")
const RIG_NIGHT := preload("res://shaders/rig_night.gdshader")
## The lights' washes sit over the wall and floor, under the paintings and everything on
## the floor (their lamps draw over the frames).
const LIGHTS_Z := -5

## The par time for the third star, in seconds.
@export var par_time := 45.0

## Seconds since the room started (the wing timer: a toss does not stop it).
var elapsed := 0.0
var ever_seen := false
var catches := 0
var tossing := false
## Whether the mime is heading to (or standing at) the swap spot to swap.
var swap_intent := false
## Whether the mime is heading to the easel to paint.
var paint_intent := false
## The frame the mime is heading to tilt, if any.
var tilt_target: TiltFrame
## The portrait the mime is heading to hide in, and the one it hides in.
var hide_target: HidingPortrait
var hidden_in: HidingPortrait
## The quality (Forgery) of the fake the mime carries, or of the one hung by the swap.
var fake_quality := 0.0
## Whether the swap has hung the fake, how many inspections it has had, and whether one
## found it out.
var fake_hung := false
var inspections := 0
var found_out := false
var finished := false
## Whether the escape beat plays (finished, the results not shown yet).
var escaping := false
var stars: Array[bool] = []
## The bests the escape beat (Save.improvement), for the results' rosettes.
var beaten := {}
## The wing play this room belongs to.
var run: WingRun
## Whether the mime is going through a door to another room (the room stops).
var leaving := false
## The layout, read from the room's nodes: where the mime starts (Entrance), the forgery
## kit and the masterpiece (null in a room without them), and the doors (Doors), the exit
## among them (null in a room without one).
var entrance := Vector2.ZERO
var easel: Easel
var masterpiece: FramedPainting
var doors: Array[Door] = []
var exit_door: Door
var gimmick: Gimmick
## The ghost mime replaying the bot's route through this visit (GhostMime), while the wing
## was never escaped from; null otherwise.
var ghost: GhostMime
## In a replay (WingRun.replaying), the room the bot went to after this stay (-1: the end).
var _replay_next := -1
var _escape_beat: Tween
## The characters' night material (RIG_NIGHT), shared by every rig in the room.
var _rig_night: ShaderMaterial
## The tweens the escape beat started (the slip, the fade, the door's swing).
var _escape_parts: Array[Tween] = []
## Seconds until the mime's next footstep on noisy floor can make a noise.
var _step_noise_wait := 0.0

@onready var mime: Mime = $Actors/Mime
## The room's guards (the Guard children of Actors), and the first of them.
var guards: Array[Guard] = []
var guard: Guard
@onready var _floor: FloorInput = $FloorInput
@onready var _keys: KeyboardInput = $KeyboardInput
@onready var _canvas: ForgeryCanvas = $EaselLayer/ForgeryCanvas
@onready var _fake_icon: Sprite2D = $FakeIcon
## The par clock and the objective strip (RoomHud).
@onready var hud: RoomHud = $Hud
## The view from inside a portrait: the room through that painting's style, in its frame.
@onready var _style_view: Control = $StyleLayer/StyleView
var _frames: Array[TiltFrame] = []
var _portraits: Array[HidingPortrait] = []
@onready var _results: Results = $ResultsLayer/Results
@onready var pause_menu: PauseMenu = $PauseLayer/PauseMenu
@onready var _game := get_node(GameState.AUTOLOAD_PATH) as GameState


func _ready() -> void:
	# The navmesh: the floor outline less every partition (the nav_obstacles group), baked
	# now so each room scene only places its partitions.
	($Navigation as NavigationRegion2D).bake_navigation_polygon(false)
	var night := CanvasModulate.new()
	night.name = "Night"
	night.color = NIGHT
	add_child(night)
	($PauseButton as CanvasItem).material = GLOW
	_fake_icon.material = GLOW
	hud.material = GLOW
	entrance = ($Entrance as Node2D).position
	easel = get_node_or_null("Actors/Easel") as Easel
	gimmick = get_node_or_null("Gimmick") as Gimmick
	mime.gimmick = gimmick
	if gimmick != null:
		gimmick.mime = mime
	masterpiece = get_node_or_null("Masterpiece") as FramedPainting
	run = _game.run
	var on_its_own := run == null or run.room >= run.wing.rooms.size() or run.wing.rooms[run.room] != scene_file_path
	if on_its_own:
		run = WingRun.new(_own_wing())
		_game.run = run
	for child in $Doors.get_children():
		if not child is Door:
			_game.report_error("Room '%s': Doors child '%s' is a %s, not a Door" % [scene_file_path, child.name, child.get_class()])
		elif (child.to_room >= run.wing.rooms.size() or child.to_room < Door.EXIT) and on_its_own:
			# Loaded outside its wing, the room cannot know the room a door leads to.
			print("[Room] %s on its own: door %s to room %d leads nowhere" % [scene_file_path, child.name, child.to_room])
		elif child.to_room >= run.wing.rooms.size() or child.to_room < Door.EXIT:
			_game.report_error("Room '%s': door '%s' leads to room %d, but the wing has %d room(s)" % [scene_file_path, child.name, child.to_room, run.wing.rooms.size()])
		else:
			doors.append(child)
			child.painting = run.wing.painting
			if child.to_room == Door.EXIT and exit_door == null:
				exit_door = child
	if run.came_from != WingRun.START:
		var back := _door_to(run.came_from)
		if back != null:
			entrance = back.arrival_point()
		else:
			_game.report_error("Room '%s': no door leads back to room %d, where the mime came from" % [scene_file_path, run.came_from])
	_take_run()
	hud.room = self
	mime.place_at(entrance)
	if masterpiece != null:
		masterpiece.painting = run.wing.painting
		_fake_icon.position = masterpiece.position
	mime.painting = run.wing.painting
	_canvas.painting = run.wing.painting
	_canvas.ghosts = run.wing.ghosts
	for child in $Actors.get_children():
		if child is Guard:
			guards.append(child)
	guard = guards[0] if not guards.is_empty() else null
	for i in guards.size():
		# The guards take the voices in turn, so two in a room sound apart.
		guards[i].voice = Audio.GUARD_VOICES[i % Audio.GUARD_VOICES.size()]
	for each in guards:
		each.target = mime
		each.gimmick = gimmick
		each.reset()
		each.spotted.connect(_on_spotted)
		each.caught.connect(_on_caught)
		each.inspected.connect(_on_inspected.bind(each))
	_floor.tapped.connect(_on_floor_tapped)
	_keys.interacted.connect(_on_interacted)
	_keys.pause_pressed.connect(pause)
	($PauseButton as Button).pressed.connect(pause)
	for child in $Frames.get_children():
		if child is TiltFrame:
			_frames.append(child)
		else:
			_game.report_error("Room '%s': Frames child '%s' is a %s, not a TiltFrame" % [scene_file_path, child.name, child.get_class()])
	for each in guards:
		each.frames = _frames
	for child in $Portraits.get_children():
		if child is HidingPortrait:
			_portraits.append(child)
		else:
			_game.report_error("Room '%s': Portraits child '%s' is a %s, not a HidingPortrait" % [scene_file_path, child.name, child.get_class()])
	_light_the_room()
	_canvas.watchers = guards
	_canvas.painted.connect(_on_painted)
	if fake_hung:
		for each in guards:
			each.fake_point = fake_view_point()
			each.watches_fake = not found_out
		_fake_icon.texture = ALARM_ICON if found_out else QUERY_ICON
		_fake_icon.visible = found_out
	var visit: int = run.visits.get(run.room, 0)
	run.visits[run.room] = visit + 1
	_add_ghost(visit)
	if run.replaying:
		# Only the ghost moves: the mime is away and the guards stand still.
		mime.visible = false
		for each in guards:
			each.active = false
	if DebugOverlay.wanted():
		add_debug_overlay()
	_game.arrive(GameState.Flow.ROOM)
	# The layout, for the web smoke test's taps.
	if masterpiece != null:
		print("[Room] Masterpiece at %s" % painting_rect())
	if easel != null:
		print("[Room] Easel at %s" % easel.rect())
	for door in doors:
		print("[Room] Door to %d at %s" % [door.to_room, door.position])


## The modulate that lifts a node out of the night to LIT_SHARE of its full brightness (the
## CanvasModulate multiplies it back down).
static func lit_boost() -> Color:
	return Color(LIT_SHARE / NIGHT.r, LIT_SHARE / NIGHT.g, LIT_SHARE / NIGHT.b)


## Lights the room after dark: the picture lights over every painting, the boost on what the
## player uses, the night material on every character's rig.
func _light_the_room() -> void:
	var boost := lit_boost()
	var lights := RoomLights.new()
	lights.name = "Lights"
	lights.z_index = LIGHTS_Z
	add_child(lights)
	var paintings: Array[Rect2] = []
	for frame in _frames:
		paintings.append(frame.rect())
		frame.modulate = boost
	for portrait in _portraits:
		paintings.append(portrait.rect())
		portrait.modulate = boost
	if masterpiece != null:
		paintings.append(painting_rect())
		masterpiece.modulate = boost
	lights.paintings = paintings
	for door in doors:
		door.modulate = boost
	if easel != null:
		easel.modulate = boost
	mime.carried_light = boost
	_rig_night = ShaderMaterial.new()
	_rig_night.shader = RIG_NIGHT
	mime.rig.material = _rig_night
	for each in guards:
		each.rig.material = _rig_night


## This room as a one-room wing (when it is loaded on its own): its own painting, ghost
## strokes and par time.
func _own_wing() -> WingData:
	var wing := WingData.new()
	wing.painting = masterpiece.painting if masterpiece != null else _canvas.painting
	wing.rooms = [scene_file_path]
	wing.par_time = par_time
	wing.ghosts = _canvas.ghosts
	return wing


## The ghost mime for the mime's `visit`-th stay here (from 0), while the run's wing (a
## wing file: a room loaded on its own has none) was never escaped from, or in a replay.
## A replay that is missing or broken is reported; one without that visit adds no ghost.
func _add_ghost(visit: int) -> void:
	var wing_path := run.wing.resource_path
	if wing_path.is_empty() or (Save.finished(_game.save, Content.wing_id(wing_path)) and not run.replaying):
		return
	var problems: Array[String] = []
	var replay := GhostMime.load_replay(GhostMime.path_for(wing_path), problems)
	for problem in problems:
		_game.report_error("Room '%s': %s" % [scene_file_path, problem])
	if replay.is_empty():
		return
	var samples := GhostMime.visit_samples(replay["trail"], run.room, visit)
	if samples.is_empty():
		print("[Room] No ghost mime: the bot came into room %d fewer than %d time(s)" % [run.room, visit + 1])
		return
	_replay_next = GhostMime.room_after(replay["trail"], run.room, visit)
	ghost = GHOST_SCENE.instantiate() as GhostMime
	ghost.samples = samples
	ghost.period = replay["period"]
	$Actors.add_child(ghost)
	ghost.rig.material = _rig_night
	print("[Room] Ghost mime replays visit %d of room %d (%d samples)" % [visit + 1, run.room, samples.size()])


## The run's state, into this room (and the mime).
func _take_run() -> void:
	par_time = run.wing.par_time
	elapsed = run.elapsed
	ever_seen = run.ever_seen
	catches = run.catches
	fake_quality = run.fake_quality
	mime.has_fake = run.has_fake
	mime.carrying = run.carrying
	var memory: Dictionary = run.hung.get(run.room, {})
	fake_hung = memory.get("fake_hung", false)
	inspections = memory.get("inspections", 0)
	found_out = memory.get("found_out", false)
	if easel != null and (mime.has_fake or mime.carrying):
		easel.glowing = false
	if exit_door != null and mime.carrying:
		exit_door.glowing = true


## This room's state, back into the run.
func _give_run() -> void:
	run.elapsed = elapsed
	run.ever_seen = ever_seen
	run.catches = catches
	run.fake_quality = fake_quality
	run.has_fake = mime.has_fake
	run.carrying = mime.carrying
	run.hung[run.room] = {"fake_hung": fake_hung, "inspections": inspections, "found_out": found_out}


## The door leading to room `index`, or null.
func _door_to(index: int) -> Door:
	for door in doors:
		if door.to_room == index:
			return door
	return null


## Where a tap means the masterpiece (an empty rect in a room without one).
func painting_rect() -> Rect2:
	if masterpiece == null:
		return Rect2()
	return Rect2(masterpiece.position - masterpiece.size / 2.0, masterpiece.size)


func swap_spot() -> Vector2:
	return Vector2(masterpiece.position.x, SWAP_Y) if masterpiece != null else Vector2.INF


func fake_view_point() -> Vector2:
	return Vector2(masterpiece.position.x, FAKE_VIEW_Y) if masterpiece != null else Vector2.INF


## Pauses the room under the pause menu (the PauseButton, or Space); not once it is over.
func pause() -> void:
	if finished or leaving or _game.is_transitioning():
		return
	pause_menu.open()


## Adds the dev-only guard debug overlay (DebugOverlay) above the room.
func add_debug_overlay() -> DebugOverlay:
	var overlay := DebugOverlay.new()
	overlay.name = "DebugOverlay"
	overlay.z_index = 100
	overlay.guards = guards
	add_child(overlay)
	print("[Room] Debug overlay on")
	return overlay


func _physics_process(delta: float) -> void:
	if finished or leaving or _game.is_transitioning():
		return
	if run.replaying:
		_replay(delta)
		return
	elapsed += delta
	if gimmick != null:
		gimmick.tick(delta)
		_step_noise(delta)
		_follow_clues()
	if ghost != null:
		ghost.advance(delta)
	var walk := _keys.direction()
	if walk != Vector2.ZERO and _accepts_input():
		if hidden_in != null:
			_step_out()
		_cancel_swap()
		paint_intent = false
		tilt_target = null
		hide_target = null
		mime.nudge(walk, delta)
	if paint_intent and not tossing and not mime.walking and mime.position.distance_to(easel.spot()) <= SWAP_REACH:
		paint_intent = false
		mime.face_toward(easel.position)
		_canvas.open()
	if tilt_target != null and not tossing and not mime.walking and mime.position.distance_to(tilt_target.spot()) <= SWAP_REACH:
		_tilt(tilt_target)
	if hide_target != null and not tossing and not mime.walking and mime.position.distance_to(hide_target.spot()) <= SWAP_REACH:
		_hide_in(hide_target)
	if fake_hung and not found_out:
		_fake_icon.visible = guards.any(func(each: Guard) -> bool: return each.inspecting)
	if swap_intent and not tossing and not mime.walking and mime.position.distance_to(swap_spot()) <= SWAP_REACH:
		mime.face_toward(masterpiece.position)
		mime.swap_progress = minf(mime.swap_progress + delta / SWAP_TIME, 1.0)
		if mime.swap_progress >= 1.0:
			_swap()
	mime.busy = tossing or hidden_in != null or _canvas.visible or mime.swap_progress > 0.0
	if mime.carrying and not tossing and exit_door != null and mime.position.distance_to(exit_door.position) <= Door.REACH:
		_escape()
		return
	for door in doors:
		if door.to_room != Door.EXIT and not tossing and mime.position.distance_to(door.position) <= Door.REACH:
			_leave(door)
			return


## The hideout's replay: the ghost walks this stay, then the replay goes on to the room the
## bot went to next, or back to the hideout after the escape.
func _replay(delta: float) -> void:
	if ghost != null and not ghost.is_done():
		ghost.advance(delta)
		return
	if _replay_next < 0:
		_end_replay()
	else:
		leaving = true
		print("[Room] Replay goes on to room %d" % _replay_next)
		_game.enter_room(_replay_next)


## Ends the hideout's replay: back to the hideout.
func _end_replay() -> void:
	leaving = true
	print("[Room] Replay over")
	_game.goto(GameState.Flow.HIDEOUT)


## Footsteps on noisy floor (Gimmick.noise_at) while the mime walks: a noise every
## Gimmick.STEP_NOISE_GAP that the nearest guard within that share of hearing range hears.
func _step_noise(delta: float) -> void:
	_step_noise_wait = maxf(_step_noise_wait - delta, 0.0)
	var loudness := gimmick.noise_at(mime.position)
	if not mime.walking or loudness <= 0.0 or _step_noise_wait > 0.0:
		return
	_step_noise_wait = Gimmick.STEP_NOISE_GAP
	_game.audio.play(gimmick.noise_sound(mime.position))
	var heard := nearest_in_earshot(mime.position, GuardBrain.HEARING_RANGE * loudness)
	if heard != null:
		heard.hear(mime.position)
		print("[Room] A loud footstep at %s at t %.2f, heard by %s" % [mime.position.round(), elapsed, heard.name])


## Each active guard not chasing looks for a clue the gimmick shows it (Gimmick.clue_seen_by)
## and goes to investigate it as if it heard a noise there.
func _follow_clues() -> void:
	for each in guards:
		if not each.active or each.senses.chasing:
			continue
		var clue := gimmick.clue_seen_by(each)
		if clue != Vector2.INF:
			each.hear(clue)
			print("[Room] %s follows a clue to %s at t %.2f" % [each.name, clue.round(), elapsed])


## Goes through `door` to its room: the room stops and hands its state back to the run.
func _leave(door: Door) -> void:
	leaving = true
	if hidden_in != null:
		_step_out()
	_canvas.close()
	for each in guards:
		each.active = false
	mime.place_at(mime.position)
	_give_run()
	print("[Room] Through the door to room %d at t %.2f" % [door.to_room, elapsed])
	_game.audio.play(&"door")
	_game.enter_room(door.to_room)


func _on_floor_tapped(at: Vector2) -> void:
	if escaping:
		_skip_escape()
		return
	if tossing or finished or leaving:
		return
	if run.replaying:
		# A tap during the replay leaves it.
		_end_replay()
		return
	TapRipple.spawn(self, at)
	if hidden_in != null:
		if hidden_in.rect().has_point(at):
			return
		_step_out()
	var on_painting := painting_rect().has_point(at) and mime.has_fake
	if on_painting and swap_intent:
		# Already heading there or swapping: a second tap keeps the progress.
		return
	_cancel_swap()
	paint_intent = false
	tilt_target = null
	hide_target = null
	for portrait in _portraits:
		if portrait.rect().has_point(at):
			hide_target = portrait
			mime.walk_to(portrait.spot())
			return
	for frame in _frames:
		if frame.rect().has_point(at) and not frame.tilted:
			tilt_target = frame
			mime.walk_to(frame.spot())
			return
	if easel != null and easel.rect().has_point(at) and not mime.carrying:
		paint_intent = true
		mime.walk_to(easel.spot())
		return
	if on_painting:
		swap_intent = true
		mime.walk_to(swap_spot())
		return
	for door in doors:
		if door.rect().has_point(at):
			mime.walk_to(door.position)
			return
	mime.walk_to(at)


## Whether the player can act in the room now (not tossed, painting or finished).
func _accepts_input() -> bool:
	return not tossing and not finished and not leaving and not _canvas.visible and not run.replaying


## E: steps out of a portrait, or taps the nearest usable thing within INTERACT_REACH of
## where the mime would stand for it; with nothing in reach the mime shrugs.
func _on_interacted() -> void:
	if escaping:
		_skip_escape()
		return
	if not _accepts_input():
		return
	if hidden_in != null:
		_step_out()
		return
	var best_tap := Vector2.INF
	var best_distance := INTERACT_REACH
	for usable: Array[Vector2] in _usables():
		var distance := mime.position.distance_to(usable[0])
		if distance <= best_distance:
			best_distance = distance
			best_tap = usable[1]
	if best_tap != Vector2.INF:
		_on_floor_tapped(best_tap)
	else:
		mime.shrug()


## What the mime can use now, each as [where it stands, where a tap means it].
func _usables() -> Array[Array]:
	var usables: Array[Array] = []
	if easel != null and not mime.carrying:
		usables.append([easel.spot(), easel.rect().get_center()] as Array[Vector2])
	if masterpiece != null and mime.has_fake:
		usables.append([swap_spot(), painting_rect().get_center()] as Array[Vector2])
	for frame in _frames:
		if not frame.tilted:
			usables.append([frame.spot(), frame.position] as Array[Vector2])
	for portrait in _portraits:
		usables.append([portrait.spot(), portrait.position] as Array[Vector2])
	for door in doors:
		if door.to_room != Door.EXIT or mime.carrying:
			usables.append([door.position, door.position] as Array[Vector2])
	return usables


func _cancel_swap() -> void:
	if swap_intent and mime.swap_progress > 0.0:
		print("[Room] Swap cancelled at %d%%" % roundi(mime.swap_progress * 100.0))
	swap_intent = false
	mime.swap_progress = 0.0


func _hide_in(portrait: HidingPortrait) -> void:
	hide_target = null
	mime.face_toward(portrait.position)
	var seen := false
	for each in guards:
		if each.active and each.can_see(mime.global_position):
			seen = true
			each.saw_hiding()
	if seen:
		ever_seen = true
	hidden_in = portrait
	portrait.occupied = true
	mime.visible = false
	# The view's white rect only shows through a style: without one it would cover the room.
	_style_view.material = Paintings.style(StringName(portrait.painting), true)
	if _style_view.material == null:
		_game.report_error("Room '%s': portrait %s has no style for painting '%s'" % [scene_file_path, portrait.name, portrait.painting])
	else:
		_style_view.show()
	print("[Room] Hid in the portrait at %s at t %.2f (seen going in: %s)" % [portrait.position.round(), elapsed, seen])
	_game.audio.play(&"hide")


func _step_out() -> void:
	print("[Room] Stepped out of the portrait at %s at t %.2f" % [hidden_in.position.round(), elapsed])
	_game.audio.play(&"unhide")
	hidden_in.occupied = false
	hidden_in = null
	mime.visible = true
	_style_view.hide()


func _tilt(frame: TiltFrame) -> void:
	tilt_target = null
	mime.face_toward(frame.position)
	frame.tilt()
	_game.audio.play(&"tilt")
	var heard := nearest_in_earshot(frame.view_point())
	if heard != null:
		heard.hear(frame.view_point())
	print("[Room] Tilted the frame at %s at t %.2f (heard by: %s)" % [frame.position.round(), elapsed, str(heard.name) if heard != null else "nobody"])


## The active guard nearest `point` within `reach` (GuardBrain.HEARING_RANGE unless a quieter
## noise carries less), or null: a noise pulls only that one.
func nearest_in_earshot(point: Vector2, reach := GuardBrain.HEARING_RANGE) -> Guard:
	var nearest: Guard
	var nearest_distance := reach
	for each in guards:
		var distance := each.global_position.distance_to(point)
		if each.active and distance < nearest_distance:
			nearest = each
			nearest_distance = distance
	return nearest


func _on_painted(quality: float) -> void:
	fake_quality = quality
	mime.has_fake = true
	if easel != null:
		easel.glowing = false
	print("[Room] Fake ready at t %.2f (quality %.2f, %s)" % [elapsed, quality, Forgery.Grade.keys()[Forgery.grade(quality)]])


func _swap() -> void:
	swap_intent = false
	mime.swap_progress = 0.0
	mime.has_fake = false
	mime.carrying = true
	fake_hung = true
	for each in guards:
		each.fake_point = fake_view_point()
		each.watches_fake = true
	_fake_icon.texture = QUERY_ICON
	if exit_door != null:
		exit_door.glowing = true
	print("[Room] Swapped the forgery for the original at t %.2f (fake %s)" % [elapsed, Forgery.Grade.keys()[Forgery.grade(fake_quality)]])
	_game.audio.play(&"swap")
	_game.punch(SWAP_PUNCH, PUNCH_TIME)


func _on_inspected(by: Guard) -> void:
	inspections += 1
	var fake_grade := Forgery.grade(fake_quality)
	var noticed := Forgery.is_noticed(fake_grade, inspections)
	print("[Room] Inspection %d of the %s fake by %s at t %.2f: %s" % [inspections, Forgery.Grade.keys()[fake_grade], by.name, elapsed, "found out" if noticed else "passed"])
	if not noticed:
		return
	found_out = true
	_game.audio.play(&"fake_found")
	by.say(&"found_fake")
	_fake_icon.texture = ALARM_ICON
	_fake_icon.show()
	for each in guards:
		each.watches_fake = false
	by.search(fake_view_point())


func _escape() -> void:
	finished = true
	for each in guards:
		each.active = false
	mime.place_at(mime.position)
	mime.busy = true
	stars = Stars.earned(ever_seen, elapsed, par_time)
	print("[Room] Escaped with the original at t %.2f (par %.0f, seen %s)" % [elapsed, par_time, ever_seen])
	_game.audio.play(&"escape")
	beaten = _game.record_escape(stars, elapsed)
	_play_escape_beat()


## The escape's curtain call before the results: the mime turns to the room and tips its
## beret (ESCAPE_TIP), slips into the exit's doorway fading out (ESCAPE_SLIP), the door
## swings shut, and after ESCAPE_HOLD the results show. A tap (or E) skips to them.
func _play_escape_beat() -> void:
	escaping = true
	mime.face(Vector2.DOWN)
	mime.rig.start_fidget(CharacterRig.Fidget.TIP, ESCAPE_TIP)
	var doorway := exit_door.position + exit_door.opening.get_center()
	_escape_beat = create_tween()
	_escape_beat.tween_interval(ESCAPE_TIP)
	_escape_beat.tween_callback(func() -> void: _escape_parts.append_array([mime.glide(doorway, ESCAPE_SLIP), mime.fade_out(ESCAPE_SLIP)]))
	_escape_beat.tween_interval(ESCAPE_SLIP)
	_escape_beat.tween_callback(func() -> void: _escape_parts.append(exit_door.swing_shut()))
	_escape_beat.tween_interval(Door.SHUT_TIME + ESCAPE_HOLD)
	_escape_beat.tween_callback(_end_escape)
	print("[Room] Escape beat")


## How long the escape beat runs before the results show.
static func escape_beat_time() -> float:
	return ESCAPE_TIP + ESCAPE_SLIP + Door.SHUT_TIME + ESCAPE_HOLD


## Skips the rest of the escape beat (its slip, fade and swing too): the mime gone, the door
## shut (its thud, unless it already sounded), the results now.
func _skip_escape() -> void:
	_escape_beat.kill()
	for part in _escape_parts:
		part.kill()
	mime.rig.modulate.a = 0.0
	if exit_door.shut < 1.0:
		_game.audio.play(&"door")
	exit_door.shut = 1.0
	exit_door.glowing = false
	print("[Room] Escape beat skipped")
	_end_escape()


func _end_escape() -> void:
	if not escaping:
		return
	escaping = false
	_results.present(stars, beaten)


func _on_spotted() -> void:
	ever_seen = true


func _on_caught() -> void:
	catches += 1
	tossing = true
	_cancel_swap()
	paint_intent = false
	tilt_target = null
	hide_target = null
	if hidden_in != null:
		_step_out()
	_canvas.close()
	var from := mime.position
	mime.place_at(from)
	print("[Room] Caught (%d) at t %.2f: tossing the mime from %s to the entrance" % [catches, elapsed, from.round()])
	_game.audio.play(&"caught")
	_game.shake(CAUGHT_SHAKE, TOSS_SHAKE)
	var toss := create_tween()
	for angle: float in [SHAKE_ANGLE, -SHAKE_ANGLE, SHAKE_ANGLE, 0.0]:
		toss.tween_property(mime, "rotation", angle, TOSS_SHAKE / 4.0)
	toss.tween_callback(_game.audio.play.bind(&"toss"))
	toss.tween_method(_toss_step.bind(from), 0.0, 1.0, TOSS_FLIGHT)
	toss.finished.connect(_end_toss)


## The mime along the toss arc, `t` from 0 (where it was caught) to 1 (the entrance).
func _toss_step(t: float, from: Vector2) -> void:
	mime.position = from.lerp(entrance, t) + Vector2(0.0, -sin(t * PI) * TOSS_HEIGHT)
	mime.rotation = t * TAU


func _end_toss() -> void:
	mime.rotation = 0.0
	mime.place_at(entrance)
	for each in guards:
		each.reset()
		each.watches_fake = fake_hung and not found_out
	tossing = false
	if gimmick != null:
		gimmick.forget()
	if ghost != null:
		ghost.restart()
	mime.splat()
	_game.audio.play(&"splat")
	print("[Room] The mime is back at the entrance at t %.2f" % elapsed)
