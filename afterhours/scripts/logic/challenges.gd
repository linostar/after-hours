class_name Challenges
extends RefCounted
## A wing's four challenges, judged on escape, each its own badge beside the stars: no mime
## power used, the hung fake PERFECT (Forgery), never caught (being seen is allowed) and out
## under the wing's speed target (WingData.speed_target, half its par time when 0).

enum Challenge { NO_POWERS, PERFECT, NEVER_CAUGHT, SPEED }

## The badges, in Challenge order.
const ICONS: Array[Texture2D] = [
	preload("res://art/svg/challenge_no_powers.svg"),
	preload("res://art/svg/challenge_perfect.svg"),
	preload("res://art/svg/challenge_never_caught.svg"),
	preload("res://art/svg/challenge_speed.svg"),
]


## None completed, in Challenge order.
static func none() -> Array[bool]:
	return [false, false, false, false]


## The seconds `wing` must be escaped within for SPEED: its speed_target, or half its par
## time when that is 0.
static func speed_target(wing: WingData) -> float:
	return wing.speed_target if wing.speed_target > 0.0 else wing.par_time / 2.0


## The challenges of an escape after `time` seconds against `target` (speed_target), having
## used `powers_used` powers, hung a fake of `fake_quality` and been caught `catches` times,
## in Challenge order.
static func earned(powers_used: int, fake_quality: float, catches: int, time: float, target: float) -> Array[bool]:
	return [powers_used == 0, Forgery.grade(fake_quality) == Forgery.Grade.PERFECT, catches == 0, time <= target]
