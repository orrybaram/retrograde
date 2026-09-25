extends Node2D
class_name WakeDrift

## The fine debris the ship wakes among, adrift just outside SR-7 at the start of a new game
## (docs/OPENING.md §3): flakes of hull, a few chips of something brighter, all turning
## slowly and spreading out from where the ship has been hanging. Nothing to harvest and
## nothing to hit - it is set dressing that says *you have been out here a while*, and it
## thins and is gone within a couple of minutes.
##
## Parented to the station so it keeps pace with it, as the ship does. Draws from its own
## RandomNumberGenerator, never the shared one (VFX must not shift gameplay rolls).

const COUNT := 42
const SEED := 347
## How far the cloud reaches from its centre at the start, px, and how fast it spreads.
const RADIUS := 260.0
const DRIFT_MAX := 7.0
const SPIN_MAX := 1.2
## How long it lasts, s, and how much of the end it spends fading.
const LIFETIME := 120.0
const FADE := 40.0
## A flake's size, px.
const SIZE_MIN := 1.2
const SIZE_MAX := 4.5
## One flake in this many catches the Sun.
const GLINT_EVERY := 7

var _flakes: Array[Dictionary] = []
var _age := 0.0

func _ready() -> void:
	z_index = 2  # over the station's hull, under the ship
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for i in COUNT:
		var r := RADIUS * sqrt(rng.randf())
		var at := Vector2.from_angle(rng.randf() * TAU) * r
		var size := rng.randf_range(SIZE_MIN, SIZE_MAX)
		var points := PackedVector2Array()
		var sides := rng.randi_range(3, 4)
		for s in sides:
			var a := TAU * s / sides + rng.randf_range(-0.4, 0.4)
			points.append(Vector2.from_angle(a) * size * rng.randf_range(0.6, 1.0))
		var glint := i % GLINT_EVERY == 0
		_flakes.append({
			"at": at,
			"drift": at.normalized() * rng.randf_range(1.0, DRIFT_MAX) + Vector2.from_angle(rng.randf() * TAU) * 1.5,
			"turn": rng.randf() * TAU,
			"spin": rng.randf_range(-SPIN_MAX, SPIN_MAX),
			"points": points,
			"color": Colors.CREAM_SOFT if glint else (Colors.HULL_LIGHT if i % 2 == 0 else Colors.HULL_MID),
			"glint": glint,
			"phase": rng.randf() * TAU,
		})

func _process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	for f in _flakes:
		f["at"] += f["drift"] * delta
		f["turn"] += f["spin"] * delta
	queue_redraw()

## How much of the cloud is left, 0-1.
func strength() -> float:
	return clampf((LIFETIME - _age) / FADE, 0.0, 1.0)

func _draw() -> void:
	var fade := strength()
	for f in _flakes:
		var c: Color = f["color"]
		var a := 0.85
		if f["glint"]:
			# turning, it catches the Sun now and then
			a = 0.35 + 0.65 * maxf(0.0, sin(f["turn"] * 2.0 + f["phase"]))
		c.a = a * fade
		var xf := Transform2D(f["turn"], f["at"])
		draw_set_transform_matrix(xf)
		draw_colored_polygon(f["points"], c)
	draw_set_transform_matrix(Transform2D.IDENTITY)
