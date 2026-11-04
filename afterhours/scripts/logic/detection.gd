class_name Detection
extends RefCounted
## How guards see the mime: a vision cone (range and half angle around the facing), and a
## suspicion level from 0 to 1 that fills while the mime is seen (faster up close) and
## drains while not. Full suspicion starts a chase. Walls are the caller's business: the guard
## only passes `seen` when a ray to the mime is clear.

## Suspicion per second while seen at the cone's far edge, and the extra per second at
## the guard's feet (the rate rises linearly as the mime comes closer).
const FILL_FAR := 0.8
const FILL_NEAR := 2.2
## Suspicion lost per second while the mime is not seen.
const DRAIN := 0.35
## From this suspicion (the eye half full) the mime counts as seen, costing the unseen star:
## a glimpse below it is forgiven (decided after the step 9 playtest).
const SEEN_AT := 0.5


## Whether `target` lies inside the cone at `origin` facing `facing` (any length), with
## reach `cone_range` and half angle `half_angle` (radians). The origin itself counts.
static func in_cone(origin: Vector2, facing: Vector2, target: Vector2, cone_range: float, half_angle: float) -> bool:
	var to_target := target - origin
	var distance := to_target.length()
	if distance > cone_range:
		return false
	if distance == 0.0:
		return true
	return absf(facing.angle_to(to_target)) <= half_angle


## Suspicion after `delta` seconds: rises while `seen` at `distance` within `cone_range`
## (FILL_FAR at the edge up to FILL_FAR + FILL_NEAR at distance 0, times `light`: how lit
## the mime is, Gimmick.light_at), drains by DRAIN otherwise or in shade (light 0); always
## within 0..1.
static func suspicion_after(current: float, seen: bool, distance: float, cone_range: float, delta: float, light := 1.0) -> float:
	if not seen or light <= 0.0:
		return maxf(current - DRAIN * delta, 0.0)
	var closeness := 1.0 - clampf(distance / cone_range, 0.0, 1.0)
	return minf(current + (FILL_FAR + FILL_NEAR * closeness) * light * delta, 1.0)


## Within this distance, in the cone, a guard cannot miss the mime: it counts as seen at once
## (close_seen). A mime running past a guard under his nose, or round him to a door he faces, is
## seen; a glimpse's grace is for the cone's far reach. Shade (light 0) still hides it.
const CLOSE_RANGE := 70.0


## A guard bumps into a mime this close whichever way he faces (Guard.touches): it is seen
## (and within CLOSE_RANGE, at once), unless it keeps still in shade. No slipping round a guard's
## back as he turns.
const TOUCH_RANGE := 30.0


## `current` suspicion raised to at least SEEN_AT when the mime is `seen` within CLOSE_RANGE
## (`distance`) and not in shade (`light` above 0); otherwise `current` unchanged.
static func close_seen(current: float, seen: bool, distance: float, light := 1.0) -> float:
	if seen and light > 0.0 and distance <= CLOSE_RANGE:
		return maxf(current, SEEN_AT)
	return current


## Whether `suspicion` has risen far enough for the mime to count as seen (SEEN_AT).
static func is_seen(suspicion: float) -> bool:
	return suspicion >= SEEN_AT


## Full suspicion: the guard gives chase (GuardBrain).
static func is_full(suspicion: float) -> bool:
	return suspicion >= 1.0
