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


## Full suspicion: the guard gives chase (GuardBrain).
static func is_full(suspicion: float) -> bool:
	return suspicion >= 1.0
