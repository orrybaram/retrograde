extends Node2D
class_name LowFuelEffect

## Makes the ship itself signal a low tank. Added by Ship at runtime; draws what its
## Drive decides and decides nothing itself.
## - Vapor: faint puffs leak from the hull and hang in space behind the ship, at the rate
##   of the Drive's warning level (only in flight; docking refuels and clears it).
## - Backfire: when the Drive coughs (a Burn tried on a low or empty tank), the exhaust
##   spits sparks and smoke and the hull jolts. The Drive holds the boost off for the
##   cough; ordinary Aux thrust never coughs.
## Puffs are drawn in world space.

const EXHAUST := Vector2(-13, 0)  # ship-local
const VAPOR_RATE := {Drive.Level.LOW: 7.0, Drive.Level.CRITICAL: 16.0}  # puffs per second
const JOLT := 2.5  # px hull kick on a cough

var _ship: Ship
var _level := Drive.Level.OK
var _puffs: Array[Dictionary] = []  # {pos, vel, age, life, r0, r1, color, a0}
var _vapor_accum := 0.0
var _jolt := Vector2.ZERO

func _ready() -> void:
	_ship = get_parent() as Ship
	top_level = true  # draw puffs in world space so they trail behind
	z_index = -1
	if _ship:
		_ship.drive.coughed.connect(_backfire)

func _process(delta: float) -> void:
	global_transform = Transform2D.IDENTITY
	if not _ship:
		return
	_level = _ship.drive.warning()
	if _level != Drive.Level.OK:
		_emit_vapor(delta)

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

func _backfire() -> void:
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
