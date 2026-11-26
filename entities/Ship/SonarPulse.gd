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
## The ring is a set of rays (SonarRing) stepped every frame against whatever carries a
## SonarSurface - the station's hull, wrecks, planets, debris - so it is cut, drained and
## shadowed by what is really there. A ring ignores its emitter's own body: a surface it starts
## inside, or the one on whatever the pulse is mounted on (the dish's station).
##
## Things that answer a Sweep join the `sonar_listeners` group with `sonar_point()` (where
## the ring has to reach, global) and `on_sonar_touched(strength)`, which is called the
## moment a ring's edge actually gets there - not when it leaves the ship - with the
## ring's strength, so an answer can match it (SonarEcho.answer_ping). It is only heard
## where the ring still has amplitude there (SonarRing.FIND): something behind a planet or
## the station hears nothing. A listener whose point is inside a solid (a dish or housing
## on the station) hears the ring as it reaches that solid's face. Scrap listens but does not
## answer: a ring only lights it up out of the debris, with one cream echo (ScrapNode.reveal).
##
## A listener with `answer_clarity(distance, ring_reach)` decides for itself whether it
## answers and how clearly (Freight): 0 is silence, even inside the ring. One that answers
## from past the ring's reach hears it as the ring dies - if the ray toward it still carries
## the ring then - and gets `on_sonar_touched(strength, clarity)` with a strength that
## carries its answer back to the ship.
##
## A Commit (Resonance) is a ring that carries Marks. Listeners with `on_procedure(marks)`
## get those instead of `on_sonar_touched` when it reaches them; the rest hear an ordinary ring.

signal pulsed(origin: Vector2)  ## A ring left the ship, from `origin` (global).
signal committed(marks: Array[int])  ## A ring left carrying a Procedure's Marks.

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

## A Sweep: the ship's own search. SR-7's dish sends rings through a pulse of its own with
## this off - they light scrap up like any ring, but nobody was looking (ScrapNode.on_swept).
var sweep := true

## Set by Ship every physics tick: `action` held somewhere a ping is allowed.
var charging := false:
	set(value):
		charging = value
		if not charging:
			_held = 0.0  # fire() reads it first; anything else is a cancel
var _held := 0.0
## Live rings (SonarRing: age, lifetime, radius, color, ...).
var _rings: Array[SonarRing] = []

func _ready() -> void:
	z_index = -1

func _process(delta: float) -> void:
	if charging:
		_held += delta
		queue_redraw()
	if _rings.is_empty():
		return
	var surfaces := active_surfaces(get_tree())
	var heard: Array = []
	for ring in _rings:
		ring.age += delta
		ring.advance(surfaces)
		for entry in ring.hear(surfaces):
			heard.append([ring, entry])
	_rings = _rings.filter(func(ring: SonarRing): return not ring.is_done())
	for pair in heard:
		_deliver(pair[0], pair[1])
	queue_redraw()

## Every SonarSurface taking part, brought up to date with where things are now.
static func active_surfaces(tree: SceneTree) -> Array[SonarSurface]:
	var out: Array[SonarSurface] = []
	if tree == null:
		return out
	for node in tree.get_nodes_in_group(SonarSurface.GROUP):
		var s := node as SonarSurface
		if s and s.is_active():
			s.refresh()
			out.append(s)
	return out

## How long `action` has been held on this charge, in seconds.
func held() -> float:
	return _held

## Let the charge go as one ring, as strong as it got, carrying `marks` if it is a Commit.
func fire(marks: Array[int] = []) -> void:
	var strength := strength_for(_held)
	charging = false
	send(strength, MAX_ALPHA, WIDTH, Colors.PRIMARY, marks)

## Send one ring worth `strength` ordinary rings, drawn at `alpha` and `width` - the ship's
## own ring by default; SR-7's dish sends a far bigger, brighter, Titan-purple one
## (CommDish.ping).
func send(strength: float, alpha := MAX_ALPHA, width := WIDTH, color := Colors.PRIMARY, marks: Array[int] = []) -> void:
	var ring := SonarRing.new(global_position, strength, END_RADIUS * strength, LIFETIME * strength, START_RADIUS)
	ring.alpha = alpha
	ring.width = width
	ring.color = color
	ring.marks = marks
	ring.sweep = sweep
	if is_inside_tree():
		ring.ignore_own_body(active_surfaces(get_tree()), self)
		ring.listen(get_tree().get_nodes_in_group("sonar_listeners"))
	_rings.append(ring)
	pulsed.emit(global_position)
	if not marks.is_empty():
		committed.emit(marks)
	EventBus.sonar_pulsed.emit(global_position)
	queue_redraw()

## Drop the charge without a ring: the key was taken for something else.
func cancel() -> void:
	charging = false
	queue_redraw()

## How many ordinary rings' worth of reach a hold of `held` seconds buys. A tap is 1.
static func strength_for(held_seconds: float) -> float:
	return 1.0 + maxf(held_seconds, 0.0) / CHARGE_TIME

## A ring reached a listener (SonarRing.hear): it hears it now. A listener freed meanwhile
## is simply skipped. A ring carrying Marks hands them to listeners that take a Procedure.
func _deliver(ring: SonarRing, entry: Dictionary) -> void:
	var listener := instance_from_id(entry.id)
	if listener == null or not is_instance_valid(listener):
		return
	var clarity: float = entry.clarity
	if not ring.marks.is_empty() and listener.has_method("on_procedure"):
		listener.on_procedure(ring.marks)
	elif clarity >= 0.0:
		var answer_strength := long_answer_strength(entry.d0, ring.strength) if entry.far else ring.strength
		listener.on_sonar_touched(answer_strength, clarity)
	else:
		listener.on_sonar_touched(ring.strength)
	if ring.sweep and listener.has_method("on_swept"):
		listener.on_swept()

## The strength an answer from `distance` px off, past the reach of a ring of `strength`,
## is sent back with: enough that its ring (SonarEcho.answer_ping) comes back to the ship.
static func long_answer_strength(distance: float, strength := 1.0) -> float:
	return maxf(strength, distance / (END_RADIUS * SonarEcho.ANSWER_REACH))

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
	if _rings.is_empty():
		return
	# Rings stay where they were sent, in the world, whatever the ship does since
	draw_set_transform_matrix(get_global_transform().affine_inverse())
	for ring in _rings:
		ring.draw(self)
	draw_set_transform_matrix(Transform2D.IDENTITY)
