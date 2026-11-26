extends Node2D
class_name TankBreach

## SR-7's left fuel tank, blown out: a ragged hole through its outer face, the hull round it
## scorched and peeled back, and what is left in it still bleeding out as a thin, sputtering
## stream of vapour that drifts off and thins to nothing. It never stops and it is never
## fixed - the tank that feeds the dock is the other one (the FUEL TANK Section).
##
## Drawn in the station's own space (a child of Visuals/FuelTankL, which sits at the
## station's origin). Draws from its own RandomNumberGenerator, never the shared one.

## Where the hole is, and how big: on the tank's outer (left) face, a little above middle.
const HOLE_AT := Vector2(-170.0, 4.0)
const HOLE_RADIUS := 11.0
## The ragged edge: radius multipliers round the hole.
const HOLE_JAG: Array[float] = [1.0, 0.7, 1.15, 0.8, 1.3, 0.65, 1.05, 0.9, 1.25, 0.75, 1.1, 0.85]
## Hull peeled outward round the rim: [angle, length, width] each.
const PETALS: Array[Vector3] = [
	Vector3(2.4, 9.0, 5.0), Vector3(3.1, 12.0, 6.0), Vector3(3.8, 8.0, 4.5), Vector3(-2.2, 6.0, 4.0),
]
const SCORCH_RADIUS := 22.0

## The leak: puffs a second (it sputters between these), how long each lives, how fast it
## drifts, and how big it swells.
const RATE_MIN := 3.0
const RATE_MAX := 14.0
const SPUTTER_PERIOD := 2.3
const LIFE := Vector2(2.2, 4.0)
const SPEED := Vector2(10.0, 26.0)
const SPREAD := 0.5
const SIZE := Vector2(1.0, 5.5)
const ALPHA := 0.3
## Every so often a fleck of frozen fuel catches the Sun.
const GLINT_CHANCE := 0.12

var _rng := RandomNumberGenerator.new()
var _puffs: Array[Dictionary] = []
var _clock := 0.0
var _owed := 0.0
var _hole := PackedVector2Array()

func _ready() -> void:
	_rng.seed = 2231
	for i in HOLE_JAG.size():
		var a := TAU * i / HOLE_JAG.size()
		_hole.append(HOLE_AT + Vector2.from_angle(a) * HOLE_RADIUS * HOLE_JAG[i])

## Puffs a second right now: it comes in gasps, never quite stopping.
static func rate_at(t: float) -> float:
	var k := 0.5 + 0.5 * sin(t * TAU / SPUTTER_PERIOD) * sin(t * TAU / (SPUTTER_PERIOD * 2.7))
	return lerpf(RATE_MIN, RATE_MAX, clampf(k, 0.0, 1.0))

func _process(delta: float) -> void:
	_clock += delta
	_owed += rate_at(_clock) * delta
	while _owed >= 1.0:
		_owed -= 1.0
		_emit()
	for p in _puffs:
		p["age"] += delta
		p["at"] += p["v"] * delta
		p["v"] *= 1.0 - 0.25 * delta  # slowing as it thins
	_puffs = _puffs.filter(func(p: Dictionary) -> bool: return p["age"] < p["life"])
	queue_redraw()

func _emit() -> void:
	var a := PI + _rng.randf_range(-SPREAD, SPREAD)  # out through the outer face
	_puffs.append({
		"at": HOLE_AT + Vector2(-HOLE_RADIUS * 0.5, _rng.randf_range(-4.0, 4.0)),
		"v": Vector2.from_angle(a) * _rng.randf_range(SPEED.x, SPEED.y),
		"age": 0.0,
		"life": _rng.randf_range(LIFE.x, LIFE.y),
		"glint": _rng.randf() < GLINT_CHANCE,
	})

## How many puffs are in the air (for tests).
func puff_count() -> int:
	return _puffs.size()

func _draw() -> void:
	# Scorch: the hull round the hole blackened, fading out
	for i in 3:
		draw_circle(HOLE_AT, SCORCH_RADIUS * (1.0 - i * 0.28), Color(Colors.SPACE_BG, 0.22))
	# Hull peeled outward round the rim
	for p in PETALS:
		var dir := Vector2.from_angle(p.x)
		var root := HOLE_AT + dir * HOLE_RADIUS * 0.8
		var side := dir.orthogonal() * p.z * 0.5
		var tip := root + dir * p.y + side * 0.6
		draw_colored_polygon(PackedVector2Array([root - side, root + side, tip]), Colors.HULL_MID)
		draw_line(root + side, tip, Colors.HULL_LIGHT, 1.0)
	# The hole itself, and the torn lip round it
	draw_colored_polygon(_hole, Colors.SPACE_BG)
	var rim := _hole.duplicate()
	rim.append(_hole[0])
	draw_polyline(rim, Colors.HULL_LIGHT, 1.0)
	# The leak
	for p in _puffs:
		var f: float = p["age"] / p["life"]
		var size := lerpf(SIZE.x, SIZE.y, f)
		if p["glint"]:
			var twinkle := 0.5 + 0.5 * sin(p["age"] * 11.0)
			draw_rect(Rect2(p["at"] - Vector2.ONE * 0.6, Vector2.ONE * 1.2), Color(Colors.CREAM, 0.8 * (1.0 - f) * twinkle))
			continue
		draw_circle(p["at"], size, Color(Colors.CREAM_SOFT, ALPHA * (1.0 - f) * (1.0 - f)))
