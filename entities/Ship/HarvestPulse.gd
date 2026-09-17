extends Node2D
class_name HarvestPulse

## Faint rings that pulse outward from the ship while the harvest beam is held.
## Owned by the ship's HarvestingState; rings already in flight finish after `emitting` stops.

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
	else:
		_spawn_timer = 0.0

	if _rings.is_empty():
		return
	for i in _rings.size():
		_rings[i] += delta
	_rings = _rings.filter(func(age: float): return age < LIFETIME)
	queue_redraw()

func _draw() -> void:
	for age in _rings:
		var t := age / LIFETIME
		var radius := lerpf(START_RADIUS, END_RADIUS, 1.0 - pow(1.0 - t, 2.0))
		var color := Colors.PRIMARY
		color.a = MAX_ALPHA * (1.0 - t)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, color, WIDTH, true)
