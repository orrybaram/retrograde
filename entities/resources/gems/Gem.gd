extends Node2D
class_name Gem

## A loose gem floating in space. Spawned in bursts when a harvest hit lands.
## Carries the scrap's orbital velocity as `drift` while its burst speed bleeds off,
## blinks during its last seconds, then disappears. GemMagnet on the ship pulls it in
## and collects it; a full hold leaves it floating. Wreck gems (dropped when the ship
## explodes) are `persistent`: they never expire, survive respawns and are saved.

const LIFETIME := 30.0
const BLINK_TIME := 5.0
const BURST_DAMPING := 2.4
const CHIP_SPEED := Vector2(30.0, 70.0)    # min, max burst speed
const BREAK_SPEED := Vector2(60.0, 140.0)
const SPIN_SPEED := 1.6
const MAX_ACTIVE := 300
const TRAIL_SCALE := 0.07  # streak length per px/s of closing speed while magnet-pulled

static var active: Array[Gem] = []

var item_id := ""
var drift := Vector2.ZERO
var velocity := Vector2.ZERO
var age := 0.0
var persistent := false
var _size := 2.0
var _color := Colors.PRIMARY
var _pulled_frame := -10
var _trail := Vector2.ZERO  # world-space streak behind a pulled gem

## Throw `ids` out of `from`'s position into `world`. Final breaks scatter wider.
static func burst(world: Node, from: Vector2, base_velocity: Vector2, ids: Array[String], final: bool, rng: RandomNumberGenerator) -> Array[Gem]:
	var speed := BREAK_SPEED if final else CHIP_SPEED
	var spawned: Array[Gem] = []
	var offset := rng.randf() * TAU
	for i in ids.size():
		# Spread evenly with jitter so a burst never clumps on one side.
		var angle := offset + TAU * i / ids.size() + rng.randf_range(-0.4, 0.4)
		var v := Vector2.RIGHT.rotated(angle) * rng.randf_range(speed.x, speed.y)
		spawned.append(spawn(world, ids[i], from, base_velocity, v))
	return spawned

static func spawn(world: Node, id: String, pos: Vector2, base_velocity: Vector2, burst_velocity: Vector2) -> Gem:
	while active.size() >= MAX_ACTIVE:
		_oldest_evictable().expire()
	var gem := Gem.new()
	gem.item_id = id
	gem.drift = base_velocity
	gem.velocity = base_velocity + burst_velocity
	gem.rotation = randf() * TAU
	world.add_child(gem)
	gem.global_position = pos
	return gem

## Loose gems go first; wreck gems only when nothing else is left.
static func _oldest_evictable() -> Gem:
	for gem in active:
		if not gem.persistent:
			return gem
	return active[0]

## Throw `ids` out of a wreck at `from`. They settle in place and never expire.
static func wreck_burst(world: Node, from: Vector2, ids: Array[String], rng: RandomNumberGenerator) -> Array[Gem]:
	var spawned := burst(world, from, Vector2.ZERO, ids, true, rng)
	for gem in spawned:
		gem.persistent = true
	return spawned

static func clear_all(keep_wreck := false) -> void:
	for gem in active.duplicate():
		if not (keep_wreck and gem.persistent):
			gem.expire()

## Wreck gems as [item_id, x, y] rows (for saving).
static func wreck_rows() -> Array:
	var rows := []
	for gem in active:
		if gem.persistent:
			rows.append([gem.item_id, gem.global_position.x, gem.global_position.y])
	return rows

static func restore_wreck(world: Node, rows: Array) -> void:
	for row in rows:
		if row is Array and row.size() == 3 and GemData.is_gem(str(row[0])):
			var gem := spawn(world, str(row[0]), Vector2(row[1], row[2]), Vector2.ZERO, Vector2.ZERO)
			gem.persistent = true

## Burst speed decays toward the carried drift velocity.
static func damp(v: Vector2, carried: Vector2, delta: float) -> Vector2:
	return carried + (v - carried) * exp(-BURST_DAMPING * delta)

func _ready() -> void:
	_size = GemData.size_of(item_id)
	_color = GemData.color_of(item_id)
	z_index = 4
	add_to_group("gems")
	active.append(self)
	tree_exiting.connect(func(): active.erase(self))

func _physics_process(delta: float) -> void:
	if not persistent:
		age += delta
		if age >= LIFETIME:
			expire()
			return
	var pulled := is_pulled()
	if not pulled:
		velocity = damp(velocity, drift, delta)
	global_position += velocity * delta
	rotation += SPIN_SPEED * delta
	if pulled or _trail != Vector2.ZERO:
		_trail = (drift - velocity) * TRAIL_SCALE if pulled else Vector2.ZERO
		queue_redraw()
	var remaining := LIFETIME - age
	visible = remaining > BLINK_TIME or fmod(remaining, 0.3) > 0.12

func is_pulled() -> bool:
	return Engine.get_physics_frames() - _pulled_frame <= 1

## Steer toward `target`, matching its velocity plus `speed` of closing speed.
func pull_toward(target: Vector2, target_velocity: Vector2, speed: float, delta: float) -> void:
	_pulled_frame = Engine.get_physics_frames()
	var desired := target_velocity + global_position.direction_to(target) * speed
	velocity = velocity.lerp(desired, 1.0 - exp(-4.0 * delta))
	drift = target_velocity

func collect() -> void:
	InventoryManager.add_item(item_id, 1)
	EventBus.gem_collected.emit(item_id, global_position)
	expire()

func expire() -> void:
	active.erase(self)
	queue_free()

func _draw() -> void:
	var s := _size
	if _trail != Vector2.ZERO:
		draw_line(Vector2.ZERO, _trail.rotated(-rotation), Color(_color, 0.45), maxf(s * 0.6, 1.0))
	draw_gem(self, s, _color)

## The gem's glow + diamond, centered on `canvas`'s origin. Shared with HoldCashIn.
static func draw_gem(canvas: CanvasItem, s: float, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, -s * 1.4), Vector2(s, 0), Vector2(0, s * 1.4), Vector2(-s, 0)])
	canvas.draw_circle(Vector2.ZERO, s * 2.2, Color(color, 0.18))
	canvas.draw_colored_polygon(points, color)
	canvas.draw_line(points[0], points[2], Color(Colors.SPACE_BG, 0.35), maxf(s * 0.25, 0.5))
