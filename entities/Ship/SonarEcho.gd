extends Node2D
class_name SonarEcho

## A Sweep answered: small rings sent back out from whatever a ring reached - the Titan's
## own colour, because the things that answer are part of it. Lives as a child of the thing
## answering, so the echo rides with it, and frees itself once its rings have faded.

const RINGS := 2
const STAGGER := 0.12  ## seconds between the echo's rings
const LIFETIME := 0.5
const START_RADIUS := 2.0
const END_RADIUS := 26.0
const MAX_ALPHA := 0.7
const WIDTH := 1.0

var _age := 0.0

## Send an echo out from `at` (local to `parent`).
static func answer(parent: Node2D, at: Vector2) -> SonarEcho:
	var echo := SonarEcho.new()
	echo.position = at
	echo.z_index = 1
	parent.add_child(echo)
	return echo

func _process(delta: float) -> void:
	_age += delta
	if _age > LIFETIME + STAGGER * (RINGS - 1):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for i in RINGS:
		var t := (_age - STAGGER * i) / LIFETIME
		if t <= 0.0 or t >= 1.0:
			continue
		var color := Colors.TITAN
		color.a = MAX_ALPHA * (1.0 - t)
		draw_arc(Vector2.ZERO, lerpf(START_RADIUS, END_RADIUS, 1.0 - pow(1.0 - t, 2.0)), 0.0, TAU, 24, color, WIDTH, true)
