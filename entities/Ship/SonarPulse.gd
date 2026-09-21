extends Node2D
class_name SonarPulse

## Sonar resonance: faint rings that pulse outward from the ship while `action` is held.
## Always on offer - in flight, over a scrap, on the ground - so it is the one thing the
## ship can always do; the states that can't (docked, stranded, gone) say so through
## ShipState.allows_sonar(), and Ship drives `emitting` from that every physics tick.
## Harvesting is what happens when a ring finds a scrap or a seam; puzzles that listen
## for a ping hook `pulsed` (or EventBus.sonar_pulsed). Rings already in flight finish
## after `emitting` stops.

signal pulsed(origin: Vector2)  ## A new ring left the ship, from `origin` (global).

const INTERVAL := 0.32
const LIFETIME := 1.0
const START_RADIUS := 6.0
const END_RADIUS := 70.0
const MAX_ALPHA := 0.22
const WIDTH := 1.0

var emitting := false
var _rings: Array[float] = []  # age of each live ring, seconds
var _spawn_timer := 0.0

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	if emitting:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_timer = INTERVAL
			_rings.append(0.0)
			pulsed.emit(global_position)
			EventBus.sonar_pulsed.emit(global_position)
	else:
		_spawn_timer = 0.0

	if _rings.is_empty():
		return
	for i in _rings.size():
		_rings[i] += delta
	_rings = _rings.filter(func(age: float): return age < LIFETIME)
	queue_redraw()

## How many rings are in the air right now.
func ring_count() -> int:
	return _rings.size()

func _draw() -> void:
	for age in _rings:
		var t := age / LIFETIME
		var radius := lerpf(START_RADIUS, END_RADIUS, 1.0 - pow(1.0 - t, 2.0))
		var color := Colors.PRIMARY
		color.a = MAX_ALPHA * (1.0 - t)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, WIDTH, true)
