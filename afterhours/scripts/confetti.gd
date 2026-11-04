class_name Confetti
extends Control
## A burst of paint-dab confetti over the results (a three-star run): DABS dabs in the six
## paintings' colours fly up from `from`, tumble and fall for LIFE seconds, fading at the
## end. The burst is seeded (SEED), so it is the same every time. Under Reduce Motion the dabs
## lie still where the burst would scatter them and only fade.

const DABS := 64
const LIFE := 2.4
const FADE := 0.6
const GRAVITY := 520.0
const SPEED := Vector2(150.0, 420.0)
const SEED := 1889
## How fast a dab tumbles (turns per second, below 2 Hz).
const SPIN_HZ := 1.4
const SIZE := Vector2(9.0, 5.0)
## A colour from each painting: earring blue and ochre, wave Prussian and foam, Seurat green
## and orange, night yellow and blue, Eden pink and green, sfumato umber and gold.
const COLOURS: Array[Color] = [
	Color(0.27, 0.42, 0.72), Color(0.86, 0.68, 0.3), Color(0.12, 0.25, 0.45), Color(0.93, 0.92, 0.85),
	Color(0.3, 0.55, 0.28), Color(0.92, 0.55, 0.22), Color(0.98, 0.84, 0.3), Color(0.2, 0.32, 0.65),
	Color(0.93, 0.62, 0.66), Color(0.45, 0.62, 0.3), Color(0.45, 0.3, 0.17), Color(0.85, 0.7, 0.35),
]

## Seconds since the burst (negative: none playing).
var age := -1.0
## Where the dabs fly from (control-local).
var from := Vector2.ZERO
## Whether the dabs lie still (Reduce Motion).
var still := false
var _velocities: Array[Vector2] = []
var _phases: Array[float] = []


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in DABS:
		var angle := rng.randf_range(-PI * 0.85, -PI * 0.15)
		_velocities.append(Vector2.from_angle(angle) * rng.randf_range(SPEED.x, SPEED.y))
		_phases.append(rng.randf())


## Starts the burst from `at` (control-local); `motionless` lays it still (Reduce Motion).
func burst(at: Vector2, motionless := false) -> void:
	from = at
	still = motionless
	age = 0.0
	queue_redraw()


func playing() -> bool:
	return age >= 0.0 and age < LIFE


func _process(delta: float) -> void:
	if age < 0.0:
		return
	age += delta
	if age >= LIFE:
		age = -1.0
	queue_redraw()


## Where dab `i` is at `t` seconds into the burst, and its turn.
func _dab(i: int, t: float) -> Array:
	if still:
		# Where the burst would scatter it after half a second, lying flat.
		t = 0.5
		return [from + _velocities[i] * t + Vector2(0.0, GRAVITY * t * t / 2.0), TAU * _phases[i]]
	return [from + _velocities[i] * t + Vector2(0.0, GRAVITY * t * t / 2.0), TAU * (_phases[i] + SPIN_HZ * t)]


func _draw() -> void:
	if not playing():
		return
	var alpha := clampf((LIFE - age) / FADE, 0.0, 1.0)
	for i in DABS:
		var placed := _dab(i, age)
		var colour := COLOURS[i % COLOURS.size()]
		colour.a = alpha
		draw_set_transform(placed[0], placed[1], Vector2(1.0, 0.6 + 0.4 * absf(cos(placed[1]))))
		draw_circle(Vector2.ZERO, SIZE.x / 2.0, colour)
		draw_circle(Vector2(SIZE.x * 0.3, 0.0), SIZE.y / 2.0, colour.lightened(0.2))
	draw_set_transform(Vector2.ZERO)
