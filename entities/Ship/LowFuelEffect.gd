extends Node2D
class_name LowFuelEffect

## Makes the ship itself signal a low tank. Added by Ship at runtime.
## - Vapor: faint puffs leak from the hull and hang in space behind the ship.
## - Sputter: while thrusting, the engine coughs — thrust and plume cut out, a backfire
##   spits sparks and smoke, and the hull jolts. FlyingState stops the plume emitting
##   during a cough (particles already out finish naturally). Rare when LOW, frequent when CRITICAL.
## Only runs in flight; docking refuels and clears it. Puffs are drawn in world space.

enum Level { OK, LOW, CRITICAL }

const LOW_RATIO := 0.25
const CRITICAL_RATIO := 0.10

const EXHAUST := Vector2(-13, 0)  # ship-local
const VAPOR_RATE := {Level.LOW: 7.0, Level.CRITICAL: 16.0}  # puffs per second
const COUGH_GAP := {Level.LOW: Vector2(1.2, 2.8), Level.CRITICAL: Vector2(0.25, 0.8)}  # seconds between coughs
const COUGH_LENGTH := Vector2(0.2, 0.4)
const JOLT := 2.5  # px hull kick on a cough

var _ship: Ship
var _level := Level.OK
var _puffs: Array[Dictionary] = []  # {pos, vel, age, life, r0, r1, color, a0}
var _vapor_accum := 0.0
var _cough_left := 0.0  # > 0 while the engine is cut
var _next_cough := 0.0
var _jolt := Vector2.ZERO

static func level_for(fuel: float, max_fuel: float) -> Level:
	if max_fuel <= 0.0 or fuel <= 0.0:
		return Level.CRITICAL
	var ratio := fuel / max_fuel
	if ratio <= CRITICAL_RATIO:
		return Level.CRITICAL
	if ratio <= LOW_RATIO:
		return Level.LOW
	return Level.OK

## True while a cough has the engine cut; FlyingState withholds thrust.
func is_coughing() -> bool:
	return _cough_left > 0.0

func _ready() -> void:
	_ship = get_parent() as Ship
	top_level = true  # draw puffs in world space so they trail behind
	z_index = -1

func _process(delta: float) -> void:
	global_transform = Transform2D.IDENTITY
	if not _ship:
		return
	_level = level_for(_ship.fuel, _ship.max_fuel) if _in_flight() else Level.OK

	if _level == Level.OK:
		_end_cough()
		_next_cough = 0.0
	else:
		_emit_vapor(delta)
		_update_sputter(delta)

	_update_jolt(delta)
	_age_puffs(delta)

func _emit_vapor(delta: float) -> void:
	_vapor_accum += delta * VAPOR_RATE[_level]
	while _vapor_accum >= 1.0:
		_vapor_accum -= 1.0
		var local := Vector2(randf_range(-10.0, 2.0), randf_range(-5.0, 5.0))
		var drift := Vector2(randf_range(-8.0, 2.0), randf_range(-10.0, 10.0)).rotated(_ship.rotation)
		_puffs.append({
			"pos": _ship.to_global(local),
			"vel": _ship.linear_velocity * 0.15 + drift,
			"age": 0.0, "life": randf_range(1.2, 2.0),
			"r0": 1.0, "r1": randf_range(4.0, 7.0),
			"color": Colors.CREAM_SOFT, "a0": randf_range(0.10, 0.18),
		})

func _update_sputter(delta: float) -> void:
	var thrusting := (_ship.want_thrust or _ship.want_reverse_thrust) and _ship.fuel > 0.0
	if _cough_left > 0.0:
		_cough_left -= delta
		if _cough_left <= 0.0:
			_end_cough()
		return
	if not thrusting:
		return
	if _next_cough <= 0.0:
		_next_cough = randf_range(COUGH_GAP[_level].x, COUGH_GAP[_level].y) * 0.5
	_next_cough -= delta
	if _next_cough <= 0.0:
		_start_cough()

func _start_cough() -> void:
	var gap: Vector2 = COUGH_GAP[_level]
	_cough_left = randf_range(COUGH_LENGTH.x, COUGH_LENGTH.y)
	_next_cough = randf_range(gap.x, gap.y)
	_jolt = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized() * JOLT
	if _ship.damage_shake_time <= 0.0:
		_ship.damage_shake_time = 0.18
		_ship.damage_shake_current_intensity = 1.8

	# Backfire: sparks and a smoke gout out of the exhaust.
	var reverse := _ship.want_reverse_thrust and not _ship.want_thrust
	var back := Vector2.LEFT.rotated(_ship.rotation) * (-1.0 if reverse else 1.0)
	var origin := _ship.to_global(-EXHAUST if reverse else EXHAUST)
	for i in randi_range(12, 18):
		_puffs.append({
			"pos": origin,
			"vel": _ship.linear_velocity + back.rotated(randf_range(-0.6, 0.6)) * randf_range(80.0, 220.0),
			"age": 0.0, "life": randf_range(0.25, 0.5),
			"r0": randf_range(1.8, 3.2), "r1": 0.6,
			"color": Colors.ORANGE if randf() < 0.6 else Colors.SUN, "a0": 1.0,
		})
	for i in randi_range(7, 11):
		_puffs.append({
			"pos": origin + back * randf_range(0.0, 4.0),
			"vel": _ship.linear_velocity * 0.4 + back.rotated(randf_range(-0.9, 0.9)) * randf_range(15.0, 45.0),
			"age": 0.0, "life": randf_range(0.9, 1.5),
			"r0": 3.0, "r1": randf_range(9.0, 15.0),
			"color": Colors.HULL_LIGHT, "a0": randf_range(0.35, 0.55),
		})

func _end_cough() -> void:
	_cough_left = 0.0

func _update_jolt(delta: float) -> void:
	if not _ship.ship_polygon:
		return
	_jolt = _jolt.move_toward(Vector2.ZERO, delta * 12.0)
	_ship.ship_polygon.position = _jolt

func _age_puffs(delta: float) -> void:
	if _puffs.is_empty():
		return
	for p in _puffs:
		p.age += delta
		p.pos += p.vel * delta
		p.vel *= 1.0 - minf(delta * 2.5, 1.0)
	_puffs = _puffs.filter(func(p: Dictionary): return p.age < p.life)
	queue_redraw()

func _draw() -> void:
	for p in _puffs:
		var t: float = p.age / p.life
		var c: Color = p.color
		c.a = p.a0 * (1.0 - t) * (1.0 - t)
		draw_circle(p.pos, lerpf(p.r0, p.r1, 1.0 - pow(1.0 - t, 2.0)), c)

func _in_flight() -> bool:
	var sm := _ship.state_machine
	return sm != null and (sm.current_state is FlyingState or sm.current_state is HarvestingState)
