extends Node2D
class_name ShipExplosion

## Ship death explosion: white flash, a lumpy fireball that cools into smoke,
## shockwave rings, streaking sparks, the hull shattered into burning debris,
## and a chain of smaller cook-off blasts that go off around (and on) the wreckage.
## Spawned into the world by DestroyedState; frees itself once everything has faded.

const DURATION := 7.0
const FLASH_TIME := 0.12
const SHAKE_INTENSITY := 6.0
const SHAKE_DURATION := 1.1
const MAIN_BLAST_SIZE := 55.0
const DEBRIS_HEAT_TIME := 1.8
const DEBRIS_FADE_START := 4.5
const EMBER_TIME := 1.6

const SPARK_COLORS: Array[Color] = [Colors.CREAM, Colors.SUN, Colors.MUSTARD, Colors.ORANGE]

class Spark:
	var pos: Vector2
	var vel: Vector2
	var age := 0.0
	var life := 1.0
	var color: Color
	var drag := 2.0
	var width := 1.5
	var streak := 0.04  ## Tail length in seconds of travel

class Blast:
	var pos: Vector2
	var at := 0.0  ## Scheduled time
	var size := 20.0
	var fired := false
	var on_debris := -1  ## Debris index to follow when firing, or -1
	var lumps: Array[Vector2] = []  ## Fixed lobe offsets (unit scale) for an irregular fireball

class Ring:
	var pos: Vector2
	var at := 0.0
	var life := 1.0
	var radius := 100.0
	var width := 4.0
	var color: Color
	var alpha := 0.8

class Puff:
	var pos: Vector2
	var vel: Vector2
	var age := 0.0
	var life := 2.5
	var r0 := 10.0
	var r1 := 40.0

class Debris:
	var node: Polygon2D
	var vel: Vector2
	var spin := 0.0
	var base_color: Color
	var ember_timer := 0.0

var rng := RandomNumberGenerator.new()
var velocity := Vector2.ZERO  ## Wreck drift, matched to the ship so the camera stays on it

var _time := 0.0
var _blasts: Array[Blast] = []
var _rings: Array[Ring] = []
var _sparks: Array[Spark] = []
var _puffs: Array[Puff] = []
var _debris: Array[Debris] = []
var _smoke: Node2D
var _camera: Camera2D = null
var _camera_base_offset := Vector2.ZERO
var _shake := 0.0

func _init() -> void:
	top_level = true
	z_index = 50
	var additive := CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = additive
	# Smoke uses normal blending and sits behind the fire
	_smoke = Node2D.new()
	_smoke.z_index = -1
	_smoke.draw.connect(_draw_smoke)
	add_child(_smoke)

## Kick off the explosion at `hull`'s position. Every Polygon2D under `hull` is shattered
## into debris. `camera` (optional) gets shaken and restored to `camera_base_offset`.
func start(hull: Node2D, drift: Vector2 = Vector2.ZERO, camera: Camera2D = null,
		camera_base_offset: Vector2 = Vector2.ZERO, seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	velocity = drift
	_camera = camera
	_camera_base_offset = camera_base_offset
	if hull:
		global_position = hull.global_position
		_shatter_hull(hull)
	_schedule_blasts()
	if not EventBus.ship_respawned.is_connected(_finish):
		EventBus.ship_respawned.connect(_finish)

func is_finished() -> bool:
	return _time >= DURATION

func _process(delta: float) -> void:
	advance(delta)

## Steps the whole simulation. Public so tests can drive it deterministically.
func advance(delta: float) -> void:
	_time += delta
	position += velocity * delta

	for blast in _blasts:
		if not blast.fired and _time >= blast.at:
			_fire(blast)

	_update_sparks(delta)
	_update_puffs(delta)
	_update_debris(delta)
	_update_shake(delta)

	queue_redraw()
	_smoke.queue_redraw()
	if is_finished():
		_finish()

func _finish() -> void:
	if is_instance_valid(_camera):
		_camera.offset = _camera_base_offset
		_camera = null
	if EventBus.ship_respawned.is_connected(_finish):
		EventBus.ship_respawned.disconnect(_finish)
	if is_inside_tree():
		queue_free()

# --- Setup -------------------------------------------------------------------

## Splits a polygon into chunky wedges fanned from its centroid, `span` edges per wedge.
static func shatter(points: PackedVector2Array, span: int = 2) -> Array[PackedVector2Array]:
	var shards: Array[PackedVector2Array] = []
	var n := points.size()
	if n < 3:
		return shards
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= n
	var step := maxi(span, 1)
	var i := 0
	while i < n:
		var shard := PackedVector2Array([center])
		for k in mini(step, n - i) + 1:
			shard.append(points[(i + k) % n])
		shards.append(shard)
		i += step
	return shards

func _shatter_hull(hull: Node2D) -> void:
	var to_local := global_transform.affine_inverse()
	var polys: Array[Polygon2D] = []
	if hull is Polygon2D:
		polys.append(hull)
	for node in hull.find_children("*", "Polygon2D", true, false):
		polys.append(node)
	for poly in polys:
		var xform := to_local * poly.global_transform
		for shard in shatter(xform * poly.polygon, 2):
			_add_debris(shard, poly.color)
	# Extra shrapnel so the wreck reads as more than a few big pieces
	for i in 10:
		var c := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 8.0)
		var s := rng.randf_range(1.5, 3.5)
		var a := rng.randf() * TAU
		_add_debris(PackedVector2Array([
			c + Vector2.from_angle(a) * s,
			c + Vector2.from_angle(a + 2.2) * s * rng.randf_range(0.5, 1.0),
			c + Vector2.from_angle(a + 4.1) * s * rng.randf_range(0.5, 1.0),
		]), Colors.HULL_LIGHT if i % 2 == 0 else Colors.HULL_MID)

func _add_debris(points: PackedVector2Array, color: Color) -> void:
	var center := Vector2.ZERO
	for p in points:
		center += p
	center /= points.size()
	var node := Polygon2D.new()
	node.polygon = points * Transform2D(0.0, center)  # Re-center on the shard
	node.position = center
	node.color = color
	node.z_index = 1
	node.use_parent_material = false
	add_child(node)

	var d := Debris.new()
	d.node = node
	d.base_color = color
	var dir := center.normalized() if center.length() > 0.5 else Vector2.from_angle(rng.randf() * TAU)
	d.vel = dir.rotated(rng.randf_range(-0.6, 0.6)) * rng.randf_range(50.0, 260.0)
	d.spin = rng.randf_range(-9.0, 9.0)
	d.ember_timer = rng.randf_range(0.0, 0.08)
	_debris.append(d)

func _schedule_blasts() -> void:
	_add_blast(Vector2.ZERO, 0.0, MAIN_BLAST_SIZE)
	# Cook-offs: a rapid stutter near the core, then a few on flying wreckage
	var t := 0.14
	for i in 4:
		var blast := _add_blast(
			Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(15.0, 55.0),
			t, rng.randf_range(10.0, 20.0))
		if i >= 2 and not _debris.is_empty():
			blast.on_debris = rng.randi_range(0, _debris.size() - 1)
		t += rng.randf_range(0.15, 0.35)
	# One last heavy thump as the core goes
	_add_blast(Vector2.from_angle(rng.randf() * TAU) * 20.0, t + 0.2, MAIN_BLAST_SIZE * 0.6)

func _add_blast(pos: Vector2, at: float, size: float) -> Blast:
	var blast := Blast.new()
	blast.pos = pos
	blast.at = at
	blast.size = size
	for i in 5:
		blast.lumps.append(Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.3, 0.75))
	_blasts.append(blast)
	return blast

# --- Simulation --------------------------------------------------------------

func _fire(blast: Blast) -> void:
	blast.fired = true
	if blast.on_debris >= 0 and blast.on_debris < _debris.size():
		blast.pos = _debris[blast.on_debris].node.position
	var big := blast.size >= MAIN_BLAST_SIZE * 0.6
	var k := blast.size / MAIN_BLAST_SIZE

	if blast.at == 0.0:
		_add_ring(blast.pos, 0.0, 0.9, 320.0, 6.0, Colors.CREAM, 0.6)
		_add_ring(blast.pos, 0.12, 1.4, 520.0, 2.0, Colors.PRIMARY, 0.3)
	elif big:
		_add_ring(blast.pos, 0.0, 0.8, 220.0, 3.0, Colors.CREAM, 0.35)
	else:
		_add_ring(blast.pos, 0.0, 0.45, 100.0 * k + 25.0, 1.5, Colors.PRIMARY, 0.3)

	var count := 60 if blast.at == 0.0 else int(8 + 20 * k)
	for i in count:
		var s := Spark.new()
		s.pos = blast.pos
		var speed := rng.randf_range(100.0, 600.0) * (0.45 + 0.55 * k)
		s.vel = Vector2.from_angle(rng.randf() * TAU) * speed
		s.life = rng.randf_range(0.3, 1.0)
		s.color = SPARK_COLORS[rng.randi() % SPARK_COLORS.size()]
		s.drag = rng.randf_range(1.2, 3.0)
		s.width = rng.randf_range(1.0, 2.6)
		_sparks.append(s)

	for i in (6 if big else 2):
		var p := Puff.new()
		p.pos = blast.pos + Vector2.from_angle(rng.randf() * TAU) * blast.size * rng.randf_range(0.0, 0.6)
		p.vel = (p.pos - blast.pos).normalized() * rng.randf_range(10.0, 45.0)
		p.life = rng.randf_range(2.0, 4.0) * (1.0 if big else 0.6)
		p.r0 = blast.size * 0.4
		p.r1 = blast.size * rng.randf_range(1.2, 2.0)
		_puffs.append(p)

	_shake = maxf(_shake, 0.8 if big else 0.2)

func _add_ring(pos: Vector2, delay: float, life: float, radius: float, width: float, color: Color, alpha: float) -> void:
	var r := Ring.new()
	r.pos = pos
	r.at = _time + delay
	r.life = life
	r.radius = radius
	r.width = width
	r.color = color
	r.alpha = alpha
	_rings.append(r)

func _update_sparks(delta: float) -> void:
	for s in _sparks:
		s.age += delta
		s.vel *= maxf(0.0, 1.0 - s.drag * delta)
		s.pos += s.vel * delta
	_sparks = _sparks.filter(func(s: Spark): return s.age < s.life)
	_rings = _rings.filter(func(r: Ring): return _time < r.at + r.life)

func _update_puffs(delta: float) -> void:
	for p in _puffs:
		p.age += delta
		p.pos += p.vel * delta
		p.vel *= maxf(0.0, 1.0 - 0.6 * delta)
	_puffs = _puffs.filter(func(p: Puff): return p.age < p.life)

func _update_debris(delta: float) -> void:
	var heat := clampf(1.0 - _time / DEBRIS_HEAT_TIME, 0.0, 1.0)
	var fade := 1.0 - clampf((_time - DEBRIS_FADE_START) / (DURATION - DEBRIS_FADE_START), 0.0, 1.0)
	for d in _debris:
		d.vel *= maxf(0.0, 1.0 - 0.35 * delta)
		d.node.position += d.vel * delta
		d.node.rotation += d.spin * delta
		var hot := d.base_color.lerp(Colors.ORANGE, 0.85).lerp(Colors.SUN, heat * heat)
		d.node.color = Color(d.base_color.lerp(hot, heat), fade)
		# Burning pieces shed embers
		if _time < EMBER_TIME:
			d.ember_timer -= delta
			if d.ember_timer <= 0.0:
				d.ember_timer = rng.randf_range(0.06, 0.15) + _time * 0.06
				var e := Spark.new()
				e.pos = d.node.position
				e.vel = d.vel * 0.15 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(5.0, 25.0)
				e.life = rng.randf_range(0.4, 0.9)
				e.color = Colors.ORANGE if rng.randf() < 0.6 else Colors.RUST_RED
				e.drag = 1.0
				e.width = rng.randf_range(1.5, 2.8)
				e.streak = 0.0
				_sparks.append(e)

func _update_shake(delta: float) -> void:
	if not is_instance_valid(_camera):
		return
	var decay := clampf(1.0 - _time / SHAKE_DURATION, 0.0, 1.0)
	_shake = maxf(0.0, _shake - delta * 2.5)
	var amount := SHAKE_INTENSITY * maxf(decay * decay, _shake * 0.5)
	if amount <= 0.01:
		_camera.offset = _camera_base_offset
		return
	var phase := _time * 38.0
	_camera.offset = _camera_base_offset + Vector2(sin(phase * 2.1), cos(phase * 1.7)) * amount

# --- Drawing -----------------------------------------------------------------

func _draw() -> void:
	# Opening flash over the whole view
	if _time < FLASH_TIME:
		var k := 1.0 - _time / FLASH_TIME
		var h := _view_half_extent()
		draw_rect(Rect2(-h, -h, h * 2.0, h * 2.0), Color(Colors.CREAM, 0.35 * k * k))

	for ring in _rings:
		var age := _time - ring.at
		if age < 0.0:
			continue
		var t := age / ring.life
		var r := ring.radius * (1.0 - pow(1.0 - t, 3.0))
		var a := ring.alpha * (1.0 - t) * (1.0 - t)
		draw_arc(ring.pos, r, 0.0, TAU, 96, Color(ring.color, a), maxf(1.0, ring.width * (1.0 - t)), true)
		# Soft inner wash trailing the front
		draw_arc(ring.pos, r * 0.95, 0.0, TAU, 96, Color(ring.color, a * 0.12), ring.width * 2.0, true)

	for blast in _blasts:
		if blast.fired:
			_draw_fireball(blast)

	# Hot halo around burning wreckage so small pieces stay readable
	var heat := clampf(1.0 - _time / (DEBRIS_HEAT_TIME * 1.4), 0.0, 1.0)
	if heat > 0.0:
		for d in _debris:
			var pulse := 0.8 + 0.2 * sin(_time * 25.0 + d.spin * 3.0)
			draw_circle(d.node.position, 5.0, Color(Colors.ORANGE, 0.25 * heat * pulse))
			draw_circle(d.node.position, 2.0, Color(Colors.SUN, 0.45 * heat * pulse))

	for s in _sparks:
		var t := s.age / s.life
		var color := s.color.lerp(Colors.RUST_RED, t)
		# Embers flicker as they die
		var flicker := 1.0 if s.streak > 0.0 else 0.6 + 0.4 * sin(s.age * 40.0 + s.pos.x)
		color.a = (1.0 - t) * flicker
		if s.streak > 0.0:
			draw_line(s.pos, s.pos - s.vel * s.streak, color, s.width, true)
		else:
			draw_circle(s.pos, s.width, color)

func _draw_fireball(blast: Blast) -> void:
	var age := _time - blast.at
	var life := 0.5 + blast.size / MAIN_BLAST_SIZE * 0.9
	if age >= life:
		return
	var t := age / life
	var grow := 1.0 - pow(1.0 - minf(age / 0.25, 1.0), 3.0)
	var r := blast.size * (0.3 + 0.7 * grow) * (1.0 + 0.35 * t)
	var color: Color
	if t < 0.25:
		color = Colors.CREAM.lerp(Colors.SUN, t / 0.25)
	elif t < 0.6:
		color = Colors.SUN.lerp(Colors.ORANGE, (t - 0.25) / 0.35)
	else:
		color = Colors.ORANGE.lerp(Colors.RUST_RED, (t - 0.6) / 0.4)
	var a := pow(1.0 - t, 1.5)
	draw_circle(blast.pos, r * 1.4, Color(color, a * 0.15))
	for lump in blast.lumps:
		draw_circle(blast.pos + lump * r, r * 0.55, Color(color, a * 0.4))
	draw_circle(blast.pos, r, Color(color, a * 0.8))
	draw_circle(blast.pos, r * 0.55 * (1.0 - t), Color(Colors.CREAM, a))

func _draw_smoke() -> void:
	for p in _puffs:
		var t := p.age / p.life
		var r := lerpf(p.r0, p.r1, 1.0 - (1.0 - t) * (1.0 - t))
		var a := 0.45 * sin(PI * minf(t * 1.6, 1.0)) * (1.0 - t)
		_smoke.draw_circle(p.pos, r, Color(Colors.HULL_MID, a))
		_smoke.draw_circle(p.pos, r * 0.6, Color(Colors.HULL_DARK, a))

func _view_half_extent() -> float:
	var cam := get_viewport().get_camera_2d() if is_inside_tree() else null
	var zoom := cam.zoom if cam else Vector2.ONE
	var view := get_viewport_rect().size / zoom if is_inside_tree() else Vector2(4000, 4000)
	return view.length() * 0.5
