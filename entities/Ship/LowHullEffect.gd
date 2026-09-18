extends Node2D
class_name LowHullEffect

## Makes the ship itself signal a failing hull. Added by Ship at runtime, and the
## counterpart to LowFuelEffect: the tank coughs, the hull bleeds.
## - Venting: smoke streams from breaches and hangs in space behind the ship. The
##   breaches are picked once per level, so the damage reads as being in one place.
## - Arcing: shorted wiring spits sparks out of a breach, fast and bright.
## - Beacon: at CRITICAL a red strobe pulses on the hull, the one thing on the ship
##   the player can see from across the screen.
## Runs everywhere except while docked — that is where the repair is bought, and the
## smoke has no business fogging the store — so a wreck limping home still smokes.
## Smoke is drawn in world space so it trails.

enum Level { OK, LOW, CRITICAL }

const LOW_RATIO := 0.35
const CRITICAL_RATIO := 0.15

const SMOKE_RATE := {Level.LOW: 9.0, Level.CRITICAL: 22.0}  # puffs per second
const ARC_GAP := {Level.LOW: Vector2(1.6, 3.4), Level.CRITICAL: Vector2(0.3, 1.1)}  # seconds between arcs
const BREACHES := {Level.LOW: 1, Level.CRITICAL: 3}
## Strobe cycle at CRITICAL, in seconds. Slow enough to read as a warning light.
const BEACON_PERIOD := 0.9
const BEACON_RADIUS := 3.0

var _ship: Ship
var _level := Level.OK
var _breaches: Array[Vector2] = []  # ship-local, re-rolled when the level changes
var _puffs: Array[Dictionary] = []  # {pos, vel, age, life, r0, r1, color, a0}
var _smoke_accum := 0.0
var _next_arc := 0.0
var _beacon := 0.0
## Own RNG: hull VFX must never draw from the shared gameplay stream.
var _rng := RandomNumberGenerator.new()

static func level_for(hull: float, max_hull: float) -> Level:
	if max_hull <= 0.0:
		return Level.OK
	var ratio := hull / max_hull
	if ratio <= 0.0:
		return Level.CRITICAL
	if ratio <= CRITICAL_RATIO:
		return Level.CRITICAL
	if ratio <= LOW_RATIO:
		return Level.LOW
	return Level.OK

func _ready() -> void:
	_rng.randomize()
	_ship = get_parent() as Ship
	top_level = true  # draw smoke in world space so it trails behind
	z_index = 3  # over the hull, so the beacon and sparks read against it

func _process(delta: float) -> void:
	global_transform = Transform2D.IDENTITY
	if not _ship:
		return

	var want := level_for(_ship.hull_strength, _ship.max_hull) if _venting() else Level.OK
	if want != _level:
		_level = want
		_reseat_breaches()

	if _level == Level.OK:
		_next_arc = 0.0
		_beacon = 0.0
	else:
		_emit_smoke(delta)
		_update_arcs(delta)
		_beacon = fmod(_beacon + delta, BEACON_PERIOD)

	_age_puffs(delta)
	queue_redraw()

## Breach points sit on the hull and stay put for as long as the level holds, so
## the smoke has a source instead of fogging out of the whole ship.
func _reseat_breaches() -> void:
	_breaches.clear()
	for i in BREACHES.get(_level, 0):
		_breaches.append(Vector2(_rng.randf_range(-9.0, 7.0), _rng.randf_range(-5.0, 5.0)))

func _breach() -> Vector2:
	if _breaches.is_empty():
		return Vector2.ZERO
	return _breaches[_rng.randi() % _breaches.size()]

func _emit_smoke(delta: float) -> void:
	_smoke_accum += delta * SMOKE_RATE[_level]
	while _smoke_accum >= 1.0:
		_smoke_accum -= 1.0
		var local := _breach()
		var drift := Vector2(_rng.randf_range(-6.0, 6.0), _rng.randf_range(-6.0, 6.0))
		# Dirtier and darker than the fuel vapor, so a smoking ship never reads as a thirsty one.
		var dark := _rng.randf() < 0.65
		_puffs.append({
			"pos": _ship.to_global(local),
			"vel": _ship.linear_velocity * 0.2 + drift,
			"age": 0.0, "life": _rng.randf_range(1.4, 2.6),
			"r0": _rng.randf_range(1.0, 2.0), "r1": _rng.randf_range(6.0, 11.0),
			"color": Colors.HULL_DARK if dark else Colors.HULL_MID,
			"a0": _rng.randf_range(0.18, 0.32),
		})

func _update_arcs(delta: float) -> void:
	var gap: Vector2 = ARC_GAP[_level]
	if _next_arc <= 0.0:
		_next_arc = _rng.randf_range(gap.x, gap.y)
	_next_arc -= delta
	if _next_arc > 0.0:
		return
	_next_arc = _rng.randf_range(gap.x, gap.y)
	_spit_sparks()

## A short shower of sparks off one breach, plus a kick of the camera so a hull
## this far gone is felt as well as seen.
func _spit_sparks() -> void:
	var origin := _ship.to_global(_breach())
	for i in _rng.randi_range(8, 14):
		var dir := Vector2.RIGHT.rotated(_rng.randf_range(0.0, TAU))
		_puffs.append({
			"pos": origin,
			"vel": _ship.linear_velocity + dir * _rng.randf_range(60.0, 190.0),
			"age": 0.0, "life": _rng.randf_range(0.18, 0.4),
			"r0": _rng.randf_range(1.2, 2.4), "r1": 0.4,
			"color": Colors.SUN if _rng.randf() < 0.5 else Colors.ORANGE,
			"a0": 1.0,
		})
	if _level == Level.CRITICAL and _ship.damage_shake_time <= 0.0:
		_ship.damage_shake_time = 0.12
		_ship.damage_shake_current_intensity = 1.2

func _age_puffs(delta: float) -> void:
	if _puffs.is_empty():
		return
	for p in _puffs:
		p.age += delta
		p.pos += p.vel * delta
		p.vel *= 1.0 - minf(delta * 2.2, 1.0)
	_puffs = _puffs.filter(func(p: Dictionary): return p.age < p.life)

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var c: Color = p.color
		c.a = p.a0 * (1.0 - t) * (1.0 - t)
		draw_circle(p.pos, lerpf(p.r0, p.r1, 1.0 - pow(1.0 - t, 2.0)), c)
	_draw_beacon()

## The strobe: a hard on/off blink rather than a fade, so it reads as a lamp.
func _draw_beacon() -> void:
	if _level != Level.CRITICAL or _ship == null:
		return
	if _beacon > BEACON_PERIOD * 0.22:
		return
	var at := _ship.to_global(_breaches[0] if not _breaches.is_empty() else Vector2.ZERO)
	draw_circle(at, BEACON_RADIUS * 2.4, Color(Colors.DANGER, 0.22))
	draw_circle(at, BEACON_RADIUS, Colors.DANGER)

## Everywhere but the dock, where the hull gets patched, and past the point where
## there is a ship left to smoke.
func _venting() -> bool:
	if _ship.is_gone():
		return false
	var sm := _ship.state_machine
	return sm != null and not (sm.current_state is LandedState)
