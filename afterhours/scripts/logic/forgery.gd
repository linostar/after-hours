class_name Forgery
extends RefCounted
## How good a painted fake is. The player traces a painting's ghost strokes one by one
## (a ghost of one point is a dab, tapped; longer ghosts are dragged); each traced stroke
## scores accuracy (how close it runs to its ghost, both ways: ghost left unpainted and
## paint off the ghost count) and smoothness (how steadily it turns: a swirl turns a lot
## but evenly, a shaky hand does not); a dragged stroke also has to cover its ghost's
## length (a tap or a half trace scores in proportion). The fake's quality (0..1) is the mean over its
## strokes and maps to a Grade, which sets how many guard inspections it survives.

enum Grade { SLOPPY, GOOD, PERFECT }

## Resampling step along a stroke, in canvas units (also filters touch jitter below it).
const STEP := 8.0
## Mean distance from the ghost at which accuracy reaches 0.
const TOLERANCE := 40.0
## Mean change of turn per step (radians) at which smoothness reaches 0.
const JITTER_TOLERANCE := 0.6
## Accuracy's share of a stroke's quality (smoothness has the rest).
const ACCURACY_WEIGHT := 0.75
## The lowest quality of each grade above Sloppy.
const PERFECT_QUALITY := 0.85
const GOOD_QUALITY := 0.55
## Assist mode's quality: always Good, never Perfect.
const ASSIST_QUALITY := 0.7


## The quality (0..1) of `traced` against `ghost`; nothing traced scores 0.
static func stroke_quality(ghost: PackedVector2Array, traced: PackedVector2Array) -> float:
	if ghost.is_empty() or traced.is_empty():
		return 0.0
	var path := resample(traced)
	var distance := (_mean_distance(resample(ghost), traced) + _mean_distance(path, ghost)) / 2.0
	var accuracy := 1.0 - clampf(distance / TOLERANCE, 0.0, 1.0)
	var smoothness := 1.0 - clampf(_jitter(path) / JITTER_TOLERANCE, 0.0, 1.0)
	var stroke := ACCURACY_WEIGHT * accuracy + (1.0 - ACCURACY_WEIGHT) * smoothness
	if ghost.size() == 1:
		return stroke
	return stroke * minf(_length(traced) / _length(ghost), 1.0)


static func _length(stroke: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(1, stroke.size()):
		total += stroke[i - 1].distance_to(stroke[i])
	return total


## The fake's quality: the mean stroke quality, `traced[i]` against `ghosts[i]` (a ghost
## without a traced stroke scores 0).
static func quality(ghosts: Array[PackedVector2Array], traced: Array[PackedVector2Array]) -> float:
	if ghosts.is_empty():
		return 0.0
	var total := 0.0
	for i in ghosts.size():
		total += stroke_quality(ghosts[i], traced[i] if i < traced.size() else PackedVector2Array())
	return total / ghosts.size()


static func grade(fake_quality: float) -> Grade:
	if fake_quality >= PERFECT_QUALITY:
		return Grade.PERFECT
	if fake_quality >= GOOD_QUALITY:
		return Grade.GOOD
	return Grade.SLOPPY


## Whether a guard's `inspection`-th look (1 for the first) finds the fake out: a Sloppy
## fake at once, a Good one from the second look, a Perfect one never.
static func is_noticed(fake_grade: Grade, inspection: int) -> bool:
	match fake_grade:
		Grade.SLOPPY:
			return true
		Grade.GOOD:
			return inspection > 1
	return false


## `stroke` as points STEP apart along its length (its first and last points kept).
static func resample(stroke: PackedVector2Array) -> PackedVector2Array:
	var points := PackedVector2Array()
	if stroke.is_empty():
		return points
	points.append(stroke[0])
	var carried := 0.0
	for i in range(1, stroke.size()):
		var from := stroke[i - 1]
		var length := from.distance_to(stroke[i])
		var along := STEP - carried
		while along <= length:
			points.append(from.lerp(stroke[i], along / length))
			along += STEP
		carried = length - (along - STEP)
	if not points[points.size() - 1].is_equal_approx(stroke[stroke.size() - 1]):
		points.append(stroke[stroke.size() - 1])
	return points


## The mean distance from each of `points` to the polyline `line` (a single point if it
## has one).
static func _mean_distance(points: PackedVector2Array, line: PackedVector2Array) -> float:
	var total := 0.0
	for point in points:
		var nearest := point.distance_to(line[0])
		for i in range(1, line.size()):
			nearest = minf(nearest, point.distance_to(Geometry2D.get_closest_point_to_segment(point, line[i - 1], line[i])))
		total += nearest
	return total / points.size()


## The mean change of turn between consecutive steps of `path` (0 for a straight line or
## an even arc; under 4 points, too short to wobble, also 0).
static func _jitter(path: PackedVector2Array) -> float:
	if path.size() < 4:
		return 0.0
	var turns := PackedFloat32Array()
	for i in range(2, path.size()):
		turns.append(angle_difference((path[i - 1] - path[i - 2]).angle(), (path[i] - path[i - 1]).angle()))
	var total := 0.0
	for i in range(1, turns.size()):
		total += absf(angle_difference(turns[i - 1], turns[i]))
	return total / (turns.size() - 1)
