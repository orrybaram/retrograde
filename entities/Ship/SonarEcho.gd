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
## An answer from past the ring's reach (clarity < 1) comes back as a broken ring: its
## circle is cut into this many arcs, and the fainter it is the more of them are missing.
const BROKEN_ARCS := 36
## However far off it came from, such an answer fades within this many ordinary rings' time.
const FAR_ANSWER_LIFETIME := 3.0

var color := Colors.TITAN
var rings := RINGS
## Per-echo overrides of the constants above, for an echo that has to read from further off.
var lifetime := LIFETIME
var end_radius := END_RADIUS
var max_alpha := MAX_ALPHA
var width := WIDTH
## Which of BROKEN_ARCS are drawn; empty draws the whole ring.
var arcs: Array[bool] = []
var _age := 0.0

## Answer a ping of `strength` (SonarPulse.strength_for) from `at` (local to `parent`):
## one ring, fading as slowly as the one that arrived and reaching ANSWER_REACH of it.
## `clarity` under 1 (an answer from past the ring, Freight.answer_clarity) is fainter and
## broken: a stutter of arcs rather than a ring.
static func answer_ping(parent: Node2D, at: Vector2, strength: float, tint := Colors.TITAN, clarity := 1.0) -> SonarEcho:
	var echo := answer(parent, at, tint, 1)
	strength = maxf(strength, 1.0)
	echo.end_radius = SonarPulse.END_RADIUS * strength * ANSWER_REACH
	echo.lifetime = SonarPulse.LIFETIME * strength
	echo.max_alpha = ANSWER_ALPHA
	if clarity < 1.0:
		echo.lifetime = SonarPulse.LIFETIME * minf(strength, FAR_ANSWER_LIFETIME)
		echo.max_alpha = ANSWER_ALPHA * clampf(clarity, 0.0, 1.0)
		echo.arcs = broken_arcs(clarity, echo.get_instance_id())
	return echo

## Which of BROKEN_ARCS a ring of `clarity` keeps: all of them at 1, fewer the fainter it
## is, never none. Its own generator (`seed_value`), never the game's shared one.
static func broken_arcs(clarity: float, seed_value: int) -> Array[bool]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var out: Array[bool] = []
	var kept := false
	for i in BROKEN_ARCS:
		var on := rng.randf() < clarity
		out.append(on)
		kept = kept or on
	if not kept:
		out[0] = true
	return out

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
		if arcs.is_empty():
			draw_arc(Vector2.ZERO, r, 0.0, TAU, clampi(int(r / 4.0), 48, 512), c, width, true)
			continue
		var step := TAU / arcs.size()
		var points := clampi(int(r * step / 4.0), 4, 64)
		for k in arcs.size():
			if arcs[k]:
				draw_arc(Vector2.ZERO, r, k * step, (k + 0.7) * step, points, c, width, true)
