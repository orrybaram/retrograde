extends Node2D
class_name CutAlarm

## What an open wound on SR-7 does while the Section is missing (docs/OPENING.md §2): the
## severed lines along the cut spit sparks, and a red emergency lamp beside it pulses slowly.
## Nothing says the station is broken - this does. Drawn, not particles, so it rides the
## station exactly, and on its own randomness, never the shared RNG.
##
## The owner (Mount, ArrayNudge) hands it the cut as `segments` - [from, to, inward] in
## this node's space, inward pointing into the gap - and where the `lamps` sit, then turns
## it off for good once the piece is home.

## The lamp: a slow pulse, PERIOD s from dark to bright and back, never fully out.
const PERIOD := 2.8
const LAMP_MIN := 0.15
const LAMP_SIZE := 4.0
const HALO_RADIUS := 26.0
## Sparks: a burst every BURST_GAP_MIN..MAX s, of BURST_MIN..MAX sparks, flying out of
## the cut at SPARK_SPEED px/s and burning out over SPARK_LIFE s.
const BURST_GAP_MIN := 0.6
const BURST_GAP_MAX := 2.4
const BURST_MIN := 4
const BURST_MAX := 12
const SPARK_SPEED_MIN := 40.0
const SPARK_SPEED_MAX := 160.0
const SPARK_LIFE_MIN := 0.25
const SPARK_LIFE_MAX := 0.7
## How wide a spray leaves the cut, either side of straight in.
const SPRAY := deg_to_rad(70.0)

var segments: Array = []
var lamps := PackedVector2Array()
var active := true:
	set(on):
		active = on
		set_process(on)
		if not on:
			_sparks.clear()
		queue_redraw()

var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _next_burst := 0.0
## Each spark: [position, velocity, life left, life]
var _sparks: Array = []

func _ready() -> void:
	_rng.randomize()
	# Out of step with the other alarms, so the station doesn't flash like one sign
	_clock = _rng.randf() * PERIOD
	_next_burst = _rng.randf_range(0.0, BURST_GAP_MAX)
	set_process(active)

## How bright the lamp is at `t` s into its pulse, LAMP_MIN..1.
static func lamp_level(t: float) -> float:
	var wave := 0.5 - 0.5 * cos(t * TAU / PERIOD)
	return lerpf(LAMP_MIN, 1.0, wave * wave)

func _process(delta: float) -> void:
	_clock += delta
	_next_burst -= delta
	if _next_burst <= 0.0:
		_burst()
		_next_burst = _rng.randf_range(BURST_GAP_MIN, BURST_GAP_MAX)
	for i in range(_sparks.size() - 1, -1, -1):
		var s: Array = _sparks[i]
		s[2] -= delta
		if s[2] <= 0.0:
			_sparks.remove_at(i)
			continue
		s[0] += s[1] * delta
		s[1] *= 1.0 - 2.5 * delta  # they slow as they burn out
	queue_redraw()

func _burst() -> void:
	if segments.is_empty():
		return
	var seg: Array = segments[_rng.randi() % segments.size()]
	var at: Vector2 = seg[0].lerp(seg[1], _rng.randf())
	var inward: Vector2 = seg[2]
	for i in _rng.randi_range(BURST_MIN, BURST_MAX):
		var dir := inward.rotated(_rng.randf_range(-SPRAY, SPRAY))
		var life := _rng.randf_range(SPARK_LIFE_MIN, SPARK_LIFE_MAX)
		_sparks.append([at, dir * _rng.randf_range(SPARK_SPEED_MIN, SPARK_SPEED_MAX), life, life])

func _draw() -> void:
	if not active:
		return
	var level := lamp_level(_clock)
	for at in lamps:
		draw_circle(at, HALO_RADIUS, Color(Colors.DANGER, 0.05 * level))
		draw_circle(at, HALO_RADIUS * 0.5, Color(Colors.DANGER, 0.1 * level))
		var r := Rect2(at - Vector2.ONE * LAMP_SIZE * 0.5, Vector2.ONE * LAMP_SIZE)
		draw_rect(r, Colors.HULL_DARK.lerp(Colors.DANGER, 0.25 + 0.6 * level))
	for s: Array in _sparks:
		var k: float = s[2] / s[3]
		var color := Colors.CREAM.lerp(Colors.ORANGE, 1.0 - k)
		color.a = k
		draw_line(s[0], s[0] - s[1] * 0.06, color, 1.5)
		draw_rect(Rect2(s[0] - Vector2.ONE, Vector2.ONE * 2.0), color)
