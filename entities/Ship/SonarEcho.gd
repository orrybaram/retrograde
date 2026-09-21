extends Node2D
class_name SonarEcho

## A Sweep answered: small rings sent back out from whatever a ring reached - the Titan's
## own colour, because the things that answer are part of it. Lives as a child of the thing
## answering, so the echo rides with it, and frees itself once its rings have faded.
## Scrap uses it too, as one cream ring: found, not answering (ScrapNode.reveal).

const RINGS := 2
const STAGGER := 0.12  ## seconds between the echo's rings
const LIFETIME := 0.5
const START_RADIUS := 2.0
const END_RADIUS := 26.0
const MAX_ALPHA := 0.7
const WIDTH := 1.0

var color := Colors.TITAN
var rings := RINGS
## Per-echo overrides of the constants above, for an echo that has to read from further off.
var lifetime := LIFETIME
var end_radius := END_RADIUS
var max_alpha := MAX_ALPHA
var width := WIDTH
var _age := 0.0

## Send an echo out from `at` (local to `parent`).
static func answer(parent: Node2D, at: Vector2, tint := Colors.TITAN, count := RINGS) -> SonarEcho:
	var echo := SonarEcho.new()
	echo.color = tint
	echo.rings = count
	echo.position = at
	echo.z_index = 1
	parent.add_child(echo)
	return echo

func _process(delta: float) -> void:
	_age += delta
	if _age > lifetime + STAGGER * (rings - 1):
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	for i in rings:
		var t := (_age - STAGGER * i) / lifetime
		if t <= 0.0 or t >= 1.0:
			continue
		var c := color
		c.a = max_alpha * (1.0 - t)
		draw_arc(Vector2.ZERO, lerpf(START_RADIUS, end_radius, 1.0 - pow(1.0 - t, 2.0)), 0.0, TAU, 48, c, width, true)
