class_name WingRun
extends RefCounted
## One play of a wing, kept by Game (Game.run) while the mime goes from room to room: which
## room it is in and which it came from, the wing timer, whether it was ever seen, the
## catches, the fake it carries (and its quality), whether it carries the original, and, per
## room, the hung fake's state there. Guards are not kept: a room's guards start afresh
## each time the mime comes in.

## came_from when the mime has just come into the museum.
const START := -1

var wing: WingData
var room := 0
var came_from := START
var elapsed := 0.0
var ever_seen := false
var catches := 0
var fake_quality := 0.0
var has_fake := false
var carrying := false
## Per room index: {"fake_hung": bool, "inspections": int, "found_out": bool}.
var hung: Dictionary[int, Dictionary] = {}
## Per room index: how many times the mime has come in (the ghost mime replays the bot's
## stay of the same number).
var visits: Dictionary[int, int] = {}
## A replay of the bot's run (the hideout's): the rooms follow the ghost mime, the only thing
## that moves; nothing is recorded.
var replaying := false


func _init(of: WingData) -> void:
	wing = of
