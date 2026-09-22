extends Node2D
class_name SonarEcho

## A Sweep answered: rings sent back out from whatever a ring reached - the Titan's own
## colour, because the things that answer are part of it. An answer scales with the ping
## that woke it (answer_ping): a tap gets a small ring back, a long charge one half as wide
## and as slow to fade, so a big Sweep through a crowd of pieces comes back as a crowd of
## big rings. Lives as a child of the thing answering, so the echo rides with it, and frees
## itself once its rings have faded. Scrap uses it too, as one small cream ring: found, not
## answering (ScrapNode.reveal).

const RINGS := 2
const STAGGER := 0.12  ## seconds between the echo's rings
const LIFETIME := 0.5
const START_RADIUS := 2.0
const END_RADIUS := 26.0
const MAX_ALPHA := 0.7
const WIDTH := 1.0
## An answering ring is drawn a touch brighter than the ship's own, so it reads as coming
## back rather than going out.
const ANSWER_ALPHA := 0.35
## An answer reaches this much of the ping that woke it: it scales with the ping, but
## smaller, so it reads as a reply.
const ANSWER_REACH := 0.5

var color := Colors.TITAN
var rings := RINGS
## Per-echo overrides of the constants above, for an echo that has to read from further off.
var lifetime := LIFETIME
var end_radius := END_RADIUS
var max_alpha := MAX_ALPHA
var width := WIDTH
var _age := 0.0

## Answer a ping of `strength` (SonarPulse.strength_for) from `at` (local to `parent`):
## one ring, fading as slowly as the one that arrived and reaching ANSWER_REACH of it.
static func answer_ping(parent: Node2D, at: Vector2, strength: float, tint := Colors.TITAN) -> SonarEcho:
	var echo := answer(parent, at, tint, 1)
	strength = maxf(strength, 1.0)
	echo.end_radius = SonarPulse.END_RADIUS * strength * ANSWER_REACH
	echo.lifetime = SonarPulse.LIFETIME * strength
	echo.max_alpha = ANSWER_ALPHA
	return echo

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
		var r := lerpf(START_RADIUS, end_radius, 1.0 - pow(1.0 - t, 2.0))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, clampi(int(r / 4.0), 48, 512), c, width, true)
