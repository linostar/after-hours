class_name Powers
extends RefCounted
## The mime's pantomime powers: the invisible ball (thrown at a floor spot within
## BALL_RANGE, a noise there), the invisible rope (pulls a straight TiltFrame within
## ROPE_RANGE from afar) and the invisible box (hides the mime where it stands, like a
## portrait, for at most BOX_TIME). Each unlocks with a wing (UNLOCK_WING, its place in
## Content.WINGS) and is usable once per room visit. A wing outside the play order (a room
## loaded on its own, a test fixture) has every power, so a room is playable with all three.

enum Power { BALL, ROPE, BOX }

## The index in Content.WINGS of the wing that unlocks each power, in Power order.
const UNLOCK_WING: Array[int] = [1, 2, 3]
## How far (base units, from the mime's feet) the ball flies and the rope reaches (to the
## frame's spot on the floor below it).
const BALL_RANGE := 260.0
const ROPE_RANGE := 320.0
## The longest the mime stays in the box before it steps out by itself (seconds).
const BOX_TIME := 6.0


## The powers the wing at `wing_path` has, in Power order: those unlocked at or before its
## place in Content.WINGS; every power for a wing outside it (or none: "").
static func unlocked(wing_path: String) -> Array[Power]:
	var place := Content.WINGS.find(wing_path)
	var powers: Array[Power] = []
	for power: Power in Power.values():
		if place < 0 or UNLOCK_WING[power] <= place:
			powers.append(power)
	return powers


## The power the wing at `wing_path` unlocks (it is first used there), or -1.
static func unlocked_by(wing_path: String) -> int:
	var place := Content.WINGS.find(wing_path)
	return UNLOCK_WING.find(place) if place >= 0 else -1
