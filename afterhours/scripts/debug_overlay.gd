class_name DebugOverlay
extends Node2D
## Dev-only guard debugging, wordless: for each guard its navmesh path, where it last saw
## the mime (while it chases or searches), the noise it is investigating and the point it searches, and its intent
## scores (GuardBrain) as bars beside it, each bar labelled by its intent's icon (patrol by
## a dot), the winner's bar highlighted. The room adds it in debug builds run with
## `-- --debug-overlay` (wanted).

const FLAG := "--debug-overlay"
## The bars' top-left beside the guard (guard-relative), their size and spacing.
const BAR_ORIGIN := Vector2(30, -150)
const BAR_SIZE := Vector2(44, 7)
const BAR_GAP := 11.0
const ICON_SIZE := 10.0
const PATH_COLOR := Color(0.55, 0.85, 1.0, 0.8)
const LAST_SEEN_COLOR := Color(0.95, 0.3, 0.25, 0.9)
const NOISE_COLOR := Color(0.95, 0.85, 0.4, 0.9)
const SEARCH_COLOR := Color(1.0, 0.6, 0.2, 0.9)
const BAR_BACK := Color(0.1, 0.08, 0.13, 0.7)
const BAR_FILL := Color(0.8, 0.8, 0.85)
const BAR_WINNER := Color(0.95, 0.85, 0.4)
const MARK_RADIUS := 10.0

var guards: Array[Guard] = []


## Whether this run asked for the overlay (a debug build with FLAG among the user args).
static func wanted() -> bool:
	return OS.is_debug_build() and FLAG in OS.get_cmdline_user_args()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	for guard in guards:
		var path := guard.nav_path()
		if path.size() > 1:
			draw_polyline(path, PATH_COLOR, 2.0, true)
		if guard.senses.chasing or guard.senses.search_left > 0.0:
			draw_arc(guard.last_seen, MARK_RADIUS, 0.0, TAU, 24, LAST_SEEN_COLOR, 2.0, true)
		if guard.senses.noise_heard:
			draw_arc(guard.noise_point, MARK_RADIUS, 0.0, TAU, 24, NOISE_COLOR, 2.0, true)
		if guard.senses.search_left > 0.0:
			draw_arc(guard.search_point, MARK_RADIUS * 1.5, 0.0, TAU, 24, SEARCH_COLOR, 2.0, true)
		_draw_scores(guard)


func _draw_scores(guard: Guard) -> void:
	var row := 0
	for intent: GuardBrain.Intent in GuardBrain.Intent.values():
		var top := guard.position + BAR_ORIGIN + Vector2(0.0, row * BAR_GAP)
		var label := Rect2(top + Vector2(-ICON_SIZE - 3.0, (BAR_SIZE.y - ICON_SIZE) / 2.0), Vector2(ICON_SIZE, ICON_SIZE))
		if Guard.INTENT_ICONS.has(intent):
			draw_texture_rect(Guard.INTENT_ICONS[intent], label, false)
		else:
			draw_circle(label.get_center(), ICON_SIZE / 3.0, BAR_FILL)
		draw_rect(Rect2(top, BAR_SIZE), BAR_BACK)
		var score: float = guard.scores.get(intent, 0.0)
		draw_rect(Rect2(top, Vector2(BAR_SIZE.x * score, BAR_SIZE.y)), BAR_WINNER if intent == guard.intent else BAR_FILL)
		row += 1
