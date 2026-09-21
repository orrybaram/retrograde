extends RigidBody2D
class_name Freight

## Something too big for the hold (docs/adr/0012): clamped rigidly to the ship's nose at
## its one Lug and pushed home ahead of it. Loose, it parks - momentum bleeds to a full
## stop and gravity never moves it - so it is always where the ship left it. While
## clamped it is not a body of its own: Ship.clamp_freight folds its mass, inertia and
## outline into the ship's, and Ship.release_freight hands them back.

## Per second, how fast a loose piece sheds its motion...
const PARK_DAMPING := 1.5
## ...and the speed (px/s) and spin (rad/s) below which it stops dead.
const PARK_SPEED := 2.0
const PARK_SPIN := 0.02
## How close the ship's nose must be to the Lug to take hold (px).
const CLAMP_REACH := 16.0
## The docking checks: slower than this relative to the piece, nose within this of the Lug.
const CLAMP_SPEED := 50.0
const CLAMP_ANGLE_DEG := 30.0

## A test piece: a long mast-like bar with its Lug on one end.
const TEST_OUTLINE := [
	Vector2(-40, -6), Vector2(30, -7), Vector2(40, -4),
	Vector2(40, 4), Vector2(30, 7), Vector2(-40, 6),
]

@export var label := "FREIGHT"
@export var outline := PackedVector2Array(TEST_OUTLINE)
## Where the ship takes hold, in local space, and which way the Lug faces (outward).
@export var lug_position := Vector2(-40, 0)
@export var lug_facing := Vector2.LEFT

var _collider: CollisionPolygon2D

func _init() -> void:
	mass = 3.0  # the ship's own mass, so a clamped test piece halves its acceleration
	gravity_scale = 0.0  # planets pull through Area2D gravity; Freight does not answer it
	can_sleep = false

func _ready() -> void:
	add_to_group("freight")
	z_index = 1
	_collider = CollisionPolygon2D.new()
	_collider.name = "Collision"
	_collider.polygon = outline
	add_child(_collider)
	add_child(_build_visual())

## Spawn a piece into `world` at `pos`, turned to `rot`.
static func spawn(world: Node, pos: Vector2, rot := 0.0, velocity := Vector2.ZERO) -> Freight:
	var f := Freight.new()
	world.add_child(f)
	f.global_position = pos
	f.global_rotation = rot
	f.linear_velocity = velocity
	return f

## Spawn a piece with its Lug `gap` px ahead of `ship`'s nose, facing it, moving with it:
## one press of `action` from clamped.
static func spawn_ahead_of(ship: Ship, gap := 6.0) -> Freight:
	var nose := ship.to_global(Ship.NOSE)
	var heading := Vector2.RIGHT.rotated(ship.global_rotation)
	var f := Freight.new()
	# Turn it so the Lug faces straight back at the nose
	var rot := (-heading).angle() - f.lug_facing.angle()
	var pos := nose + heading * gap - f.lug_position.rotated(rot)
	ship.get_parent().add_child(f)
	f.global_position = pos
	f.global_rotation = rot
	f.linear_velocity = ship.linear_velocity
	return f

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	var parked := parked_motion(state.linear_velocity, state.angular_velocity, state.step)
	state.linear_velocity = parked[0]
	state.angular_velocity = parked[1]

## Where a loose piece's motion goes after `dt`: bled down, and zeroed once it is slow.
static func parked_motion(velocity: Vector2, spin: float, dt: float) -> Array:
	var k := exp(-PARK_DAMPING * dt)
	velocity *= k
	spin *= k
	if velocity.length() < PARK_SPEED:
		velocity = Vector2.ZERO
	if absf(spin) < PARK_SPIN:
		spin = 0.0
	return [velocity, spin]

func lug_global() -> Vector2:
	return to_global(lug_position)

func lug_facing_global() -> Vector2:
	return lug_facing.rotated(global_rotation).normalized()

## Can a ship whose nose is at `nose`, pointing along `heading`, moving at `rel_velocity`
## relative to the piece, take hold of a Lug at `lug` facing `facing`? The docking checks:
## close, slow, and nose-in to the Lug.
static func can_clamp(nose: Vector2, heading: Vector2, rel_velocity: Vector2, lug: Vector2, facing: Vector2) -> bool:
	if nose.distance_to(lug) > CLAMP_REACH:
		return false
	if rel_velocity.length() >= CLAMP_SPEED:
		return false
	return heading.normalized().dot(-facing.normalized()) >= cos(deg_to_rad(CLAMP_ANGLE_DEG))

## Where a clamped piece sits in its carrier's local space: the Lug on `nose`, facing
## straight back along the carrier. The pose is fixed by the Lug, so a piece always
## rides the same way.
static func clamped_pose(lug_pos: Vector2, facing: Vector2, nose: Vector2) -> Transform2D:
	var rot := Vector2.LEFT.angle() - facing.angle()
	return Transform2D(rot, nose - lug_pos.rotated(rot))

## Moment of inertia of a uniform slab over `points`' bounding box, about the origin
## those points are given in. Good enough to make a long piece turn far worse than a
## short one.
static func box_inertia(points: PackedVector2Array, m: float) -> float:
	if points.is_empty():
		return 0.0
	var box := bounds(points)
	return m * (box.size.x * box.size.x + box.size.y * box.size.y) / 12.0 \
		+ m * box.get_center().length_squared()

## The piece's centre of mass in its own space (the middle of its outline's box).
func own_center() -> Vector2:
	return bounds(outline).get_center()

static func bounds(points: PackedVector2Array) -> Rect2:
	var box := Rect2(points[0], Vector2.ZERO)
	for p in points:
		box = box.expand(p)
	return box

func _build_visual() -> Node2D:
	var root := Node2D.new()
	root.name = "Visual"
	var body := Polygon2D.new()
	body.polygon = outline
	body.color = Colors.HULL_MID
	root.add_child(body)
	var edge := Line2D.new()
	edge.points = outline
	edge.closed = true
	edge.width = 1.0
	edge.default_color = Colors.HULL_LIGHT
	root.add_child(edge)
	# The Lug: a flange across the end the ship takes hold of. Scrap has nothing like it.
	var across := lug_facing.orthogonal().normalized()
	var lug := Line2D.new()
	lug.points = PackedVector2Array([
		lug_position + across * 8.0, lug_position - across * 8.0,
	])
	lug.width = 3.0
	lug.default_color = Colors.HULL_LIGHT
	root.add_child(lug)
	return root
