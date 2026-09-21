extends Node2D
class_name SonarPulse

## Sonar resonance: a ring that goes out from the ship when `action` is let go. A tap sends
## an ordinary ring; holding charges it, and the longer the hold the further the one ring
## reaches - with no ceiling, and with nothing but a faint glow at the hull to say so. That
## is left for the player to find. Always on offer - in flight, over a scrap, on the
## ground - so it is the one thing the ship can always do; the states that can't (docked,
## stranded, gone, carrying) say so through ShipState.allows_sonar(), and Ship drives
## `charging` from that every physics tick, firing on release and cancelling a charge the
## key was taken away from. Harvesting is what happens when a ring finds a scrap or a seam;
## puzzles that listen for a ping hook `pulsed` (or EventBus.sonar_pulsed). Rings already
## in flight finish on their own.
##
## Things that answer a Sweep join the `sonar_listeners` group with `sonar_point()` (where
## the ring has to reach, global) and `on_sonar_touched()`, which is called the moment a
## ring's edge actually gets there - not when it leaves the ship. Scrap listens but does not
## answer: a ring only lights it up out of the debris, with one cream echo (ScrapNode.reveal).

signal pulsed(origin: Vector2)  ## A ring left the ship, from `origin` (global).

## An ordinary (tapped) ring: how long it lives and how far it reaches.
const LIFETIME := 1.0
const START_RADIUS := 6.0
const END_RADIUS := 280.0
## Every this many seconds held adds another ordinary ring's reach. Uncapped.
const CHARGE_TIME := 1.5
const MAX_ALPHA := 0.22
const WIDTH := 1.0
## The glow at the hull while charging: its radius, and how bright it gets.
const CHARGE_GLOW_RADIUS := 14.0
const CHARGE_GLOW_ALPHA := 0.3

## Set by Ship every physics tick: `action` held somewhere a ping is allowed.
var charging := false:
	set(value):
		charging = value
		if not charging:
			_held = 0.0  # fire() reads it first; anything else is a cancel
var _held := 0.0
## Live rings: {age, lifetime, radius}.
var _rings: Array[Dictionary] = []

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	if charging:
		_held += delta
		queue_redraw()
	if _rings.is_empty():
		return
	for ring in _rings:
		ring.age += delta
	_rings = _rings.filter(func(ring: Dictionary): return ring.age < ring.lifetime)
	queue_redraw()

## How long `action` has been held on this charge, in seconds.
func held() -> float:
	return _held

## Let the charge go as one ring, as strong as it got.
func fire() -> void:
	var strength := strength_for(_held)
	charging = false
	_rings.append({"age": 0.0, "lifetime": LIFETIME * strength, "radius": END_RADIUS * strength})
	pulsed.emit(global_position)
	EventBus.sonar_pulsed.emit(global_position)
	_reach_listeners(global_position, strength)
	queue_redraw()

## Drop the charge without a ring: the key was taken for something else.
func cancel() -> void:
	charging = false
	queue_redraw()

## How many ordinary rings' worth of reach a hold of `held` seconds buys. A tap is 1.
static func strength_for(held_seconds: float) -> float:
	return 1.0 + maxf(held_seconds, 0.0) / CHARGE_TIME

## Tell every listener within reach when this ring's edge arrives at it. The timers hold
## instance ids, not nodes, so a listener freed meanwhile is simply skipped.
func _reach_listeners(origin: Vector2, strength: float) -> void:
	for node in get_tree().get_nodes_in_group("sonar_listeners"):
		if not node.has_method("sonar_point") or not node.has_method("on_sonar_touched"):
			continue
		var delay := time_to_reach(origin.distance_to(node.sonar_point()), strength)
		if delay < 0.0:
			continue
		var id := node.get_instance_id()
		get_tree().create_timer(delay, false).timeout.connect(func() -> void:
			var listener := instance_from_id(id)
			if listener and is_instance_valid(listener):
				listener.on_sonar_touched())

## Seconds after leaving the ship that a ring of `strength` reaches `distance`; -1 if it
## never does.
static func time_to_reach(distance: float, strength := 1.0) -> float:
	var f := (distance - START_RADIUS) / (END_RADIUS * strength - START_RADIUS)
	if f > 1.0:
		return -1.0
	if f <= 0.0:
		return 0.0
	return (1.0 - sqrt(1.0 - f)) * LIFETIME * strength

## How many rings are in the air right now.
func ring_count() -> int:
	return _rings.size()

## The reach of the widest ring in the air (0 if none).
func widest_ring() -> float:
	var widest := 0.0
	for ring in _rings:
		widest = maxf(widest, ring.radius)
	return widest

func _draw() -> void:
	if charging:
		var glow := Colors.PRIMARY
		glow.a = CHARGE_GLOW_ALPHA * (1.0 - 1.0 / strength_for(_held))
		draw_arc(Vector2.ZERO, CHARGE_GLOW_RADIUS, 0.0, TAU, 24, glow, WIDTH, true)
	for ring in _rings:
		var t: float = ring.age / ring.lifetime
		var radius := lerpf(START_RADIUS, ring.radius, 1.0 - pow(1.0 - t, 2.0))
		var color := Colors.PRIMARY
		color.a = MAX_ALPHA * (1.0 - t)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, clampi(int(radius / 4.0), 48, 512), color, WIDTH, true)
