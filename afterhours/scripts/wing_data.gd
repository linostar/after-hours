class_name WingData
extends Resource
## One wing of the museum (data/wings/wing_NN.tres): its masterpiece, its rooms in order
## (room 0 is where the mime comes in; doors name rooms by index), the par time for the
## third star and the forgery's ghost strokes. Content.validate checks it.

## The wing's masterpiece (a Paintings id; the enum lists Paintings.IDS). Empty by default,
## which Content.validate rejects, so every wing file names its painting.
@export_enum("pearl_earring", "great_wave", "grande_jatte", "starry_night", "earthly_delights", "mona_lisa") var painting := ""
## Room scenes (res:// paths), room 0 first.
@export var rooms: Array[String] = []
## Seconds, for the third star.
@export var par_time := 120.0
## Seconds, for the SPEED challenge (Challenges.speed_target); 0 means half of par_time.
@export var speed_target := 0.0
## The forgery's ghost strokes, in canvas units (ForgeryCanvas.ghosts).
@export var ghosts: Array[PackedVector2Array] = []
## What the bot does with a route's tap (a route's *_actions, one per tap): a plain TAP; a
## DASH (the same spot tapped twice within Room.DOUBLE_TAP); BALL or ROPE (the power picked
## on the PowerBar, then the tap its target); BOX (the box picked; the tap's point is unused).
enum BotAction { TAP, DASH, BALL, ROPE, BOX }

## The playtest bot's taps (tools/bot.gd; base units), in order, and the seconds it waits
## before each (found by bot.gd --record, which also sets par_time).
@export var bot_route: PackedVector2Array = PackedVector2Array()
@export var bot_waits: PackedFloat32Array = PackedFloat32Array()
## What the bot does with each bot_route tap (BotAction; empty: every one a plain TAP).
@export var bot_actions: PackedInt32Array = PackedInt32Array()
## The route's trick taps (indices into bot_route: a tilt that lures, a hide, a step into a
## puddle or a searchlight...): bot.gd proves each one needed (without it the mime is seen or
## caught whatever it waits) and that every room but those in trick_free has one.
@export var bot_tricks: PackedInt32Array = PackedInt32Array()
@export var trick_free: PackedInt32Array = PackedInt32Array()
## A second route that picks up the wing's hidden sketch and still escapes (never shown by
## the ghost mime), and its waits (bot.gd --record).
@export var sketch_route: PackedVector2Array = PackedVector2Array()
@export var sketch_waits: PackedFloat32Array = PackedFloat32Array()
@export var sketch_actions: PackedInt32Array = PackedInt32Array()
## A dashing route that proves the SPEED challenge reachable: it escapes uncaught (being seen
## is allowed) within Challenges.speed_target; its waits (bot.gd --record, which sets
## speed_target to its time rounded up to PAR_ROUND when that is over half par).
@export var speed_route: PackedVector2Array = PackedVector2Array()
@export var speed_waits: PackedFloat32Array = PackedFloat32Array()
@export var speed_actions: PackedInt32Array = PackedInt32Array()
