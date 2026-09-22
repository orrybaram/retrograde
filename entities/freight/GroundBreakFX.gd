extends Node2D
class_name GroundBreakFX

## A buried piece being worked out of a planet's ground (Freight.tug). A tug that doesn't
## free it throws a little dust and grit and a few sparks where it goes in; the last one
## rips it out: a burst of dust rolling out along the ground, chunks of rock tumbling away,
## a spray of sparks, a shock ring, and a scar left in the ground where it lay.
##
## Parented to the planet, so it rides the planet's orbit and doesn't streak off behind it.
## Drawn, not particles, on its own randomness - never the shared RNG.

## How much of each a tug throws, and the break-free. `power` scales count and speed.
const TUG := {"dust": 14, "chunks": 5, "sparks": 10, "power": 0.6, "ring": false}
const BREAK := {"dust": 46, "chunks": 18, "sparks": 36, "power": 1.0, "ring": true}
## The instant it rips out: a white-hot flash at the break, this long and this wide.
const FLASH_TIME := 0.18
const FLASH_RADIUS := 38.0
const DUST_LIFE := 1.7
const CHUNK_LIFE := 1.5
const SPARK_LIFE := 0.55
const RING_LIFE := 0.7
const RING_RADIUS := 170.0
## The scar left in the ground: how long it takes to fade in, and its size.
const SCAR_SIZE := Vector2(34, 14)

var _rng := RandomNumberGenerator.new()
var _age := 0.0
var _life := 0.0
var _outward := Vector2.UP
var _ground := Colors.HULL_MID
var _ring := false
var _scar := false
## Each: [pos, vel, life, age, size, spin, angle, points]
var _dust: Array = []
var _chunks: Array = []
var _sparks: Array = []

## A tug that didn't free it, at `pos` (global) on `planet`'s ground facing `outward`.
static func tug(planet: Node2D, pos: Vector2, outward: Vector2) -> GroundBreakFX:
	return _spawn(planet, pos, outward, TUG, false)

## The piece rips free: the full burst, and a scar left behind.
static func break_free(planet: Node2D, pos: Vector2, outward: Vector2) -> GroundBreakFX:
	return _spawn(planet, pos, outward, BREAK, true)

static func _spawn(planet: Node2D, pos: Vector2, outward: Vector2, kind: Dictionary, scar: bool) -> GroundBreakFX:
	var fx := GroundBreakFX.new()
	fx.add_to_group("ground_fx")
	fx.z_index = 2
	planet.add_child(fx)
	fx.global_position = pos
	fx._outward = planet.global_transform.basis_xform_inv(outward).normalized()
	var p := planet as Planet
	if p:
		fx._ground = p.color
	fx._scar = scar
	fx._ring = kind["ring"]
	fx._rng.randomize()
	fx._emit(kind)
	# A new game or a load puts the ground back as it was
	EventBus.planets_restored.connect(fx.queue_free)
	return fx

func _emit(kind: Dictionary) -> void:
	var power: float = kind["power"]
	var tangent := _outward.orthogonal()
	for i in kind["dust"]:
		# Dust rolls out low along the ground, both ways, and a little up
		var side := tangent * (1.0 if _rng.randf() < 0.5 else -1.0)
		var dir := side.lerp(_outward, _rng.randf_range(0.35, 0.9)).normalized()
		_dust.append([_jitter(6.0), dir * _rng.randf_range(20.0, 95.0) * power, DUST_LIFE * _rng.randf_range(0.6, 1.0),
			0.0, _rng.randf_range(5.0, 12.0) * lerpf(0.6, 1.0, power), 0.0, 0.0, null])
	for i in kind["chunks"]:
		var dir := _outward.rotated(_rng.randf_range(-0.9, 0.9))
		var size := _rng.randf_range(2.5, 6.0) * lerpf(0.6, 1.0, power)
		_chunks.append([_jitter(4.0), dir * _rng.randf_range(60.0, 200.0) * power, CHUNK_LIFE * _rng.randf_range(0.6, 1.0),
			0.0, size, _rng.randf_range(-7.0, 7.0), _rng.randf() * TAU, _rock(size)])
	for i in kind["sparks"]:
		var dir := _outward.rotated(_rng.randf_range(-1.1, 1.1))
		_sparks.append([_jitter(3.0), dir * _rng.randf_range(90.0, 300.0) * power, SPARK_LIFE * _rng.randf_range(0.4, 1.0),
			0.0, 0.0, 0.0, 0.0, null])
	_life = maxf(DUST_LIFE, CHUNK_LIFE)

func _jitter(r: float) -> Vector2:
	return Vector2(_rng.randf_range(-r, r), _rng.randf_range(-r, r))

## An irregular lump of rock `size` px across.
func _rock(size: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := _rng.randi_range(4, 6)
	for i in n:
		pts.append(Vector2.RIGHT.rotated(TAU * i / n + _rng.randf_range(-0.3, 0.3)) * size * _rng.randf_range(0.6, 1.0))
	return pts

func _process(delta: float) -> void:
	_age += delta
	for group: Array in [_dust, _chunks, _sparks]:
		for p: Array in group:
			p[3] += delta
			p[0] += p[1] * delta
			p[6] += p[5] * delta
	for p: Array in _dust:
		p[1] *= 1.0 - 1.8 * delta  # dust hangs
	for p: Array in _chunks:
		p[1] *= 1.0 - 0.9 * delta
	for p: Array in _sparks:
		p[1] *= 1.0 - 3.0 * delta
	if _age >= _life and not _scar:
		queue_free()
		return
	if _age >= _life:
		_dust.clear()
		_chunks.clear()
		_sparks.clear()
		set_process(false)
	queue_redraw()

## How far through its life particle `p` is, 0..1.
static func _t(p: Array) -> float:
	return clampf(p[3] / p[2], 0.0, 1.0)

func _draw() -> void:
	if _scar:
		# The hole it came out of: dark, raw rock at the lip, fading in as the dust clears
		var a := clampf(_age / 0.3, 0.0, 1.0)
		var along := _outward.orthogonal()
		var hole := PackedVector2Array()
		for i in 12:
			var ang := TAU * i / 12.0
			hole.append(along * cos(ang) * SCAR_SIZE.x * 0.5 + _outward * (sin(ang) * SCAR_SIZE.y * 0.5 - 3.0))
		draw_colored_polygon(hole, Color(Colors.SPACE_BG, 0.85 * a))
		draw_polyline(hole + PackedVector2Array([hole[0]]), Color(Colors.HULL_DARK, a), 1.5)
	if _ring and _age < FLASH_TIME:
		var f := 1.0 - _age / FLASH_TIME
		draw_circle(Vector2.ZERO, FLASH_RADIUS * (0.6 + 0.4 * f), Color(Colors.CREAM, 0.5 * f))
		draw_circle(Vector2.ZERO, FLASH_RADIUS * 0.35, Color(Colors.CREAM, 0.9 * f))
	if _ring and _age < RING_LIFE:
		var t := _age / RING_LIFE
		var r := lerpf(10.0, RING_RADIUS, 1.0 - pow(1.0 - t, 3.0))
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 64, Color(Colors.CREAM, 0.45 * (1.0 - t)), 2.0, true)
		draw_arc(Vector2.ZERO, r * 0.7, 0.0, TAU, 48, Color(Colors.PRIMARY, 0.3 * (1.0 - t)), 1.0, true)
	for p: Array in _dust:
		var t := _t(p)
		if t >= 1.0:
			continue
		# Pale dust, so it reads over the ground it comes off as well as over space
		var c := Colors.CREAM_SOFT.lerp(_ground, 0.3)
		c.a = 0.55 * (1.0 - t)
		draw_circle(p[0], p[4] * (1.0 + t * 1.6), c)
	for p: Array in _chunks:
		var t := _t(p)
		if t >= 1.0:
			continue
		var c := _ground.darkened(0.45)
		c.a = 1.0 - t * t
		var xf := Transform2D(p[6], p[0])
		draw_colored_polygon(xf * (p[7] as PackedVector2Array), c)
	for p: Array in _sparks:
		var t := _t(p)
		if t >= 1.0:
			continue
		var c := Colors.CREAM.lerp(Colors.ORANGE, t)
		c.a = 1.0 - t
		draw_line(p[0], p[0] - (p[1] as Vector2) * 0.05, c, 1.5)
