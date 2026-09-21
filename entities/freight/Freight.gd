extends RigidBody2D
class_name Freight

## Something too big for the hold (docs/adr/0012): clamped rigidly to the ship's nose at
## its one Lug and pushed home ahead of it. Let go, it coasts on as the ship was moving -
## same velocity, same heading, plus a slow drift off the nose - and gravity never bends its path. While
## clamped it is not a body of its own: Ship.clamp_freight folds its mass, inertia and
## outline into the ship's, and Ship.release_freight hands them back.
## Holding `action` with the nose this close to the Lug (px) starts the magnet. Angle and
## speed don't matter: the magnet turns the piece into its pose on the way in.
const MAGNET_RANGE := 25.0
## Once pulling, it keeps pulling out to this far - the ship may drift while it holds.
const MAGNET_HOLD_RANGE := 50.0
## How hard the magnet closes the gap (per second of offset), and its top speeds.
const MAGNET_GAIN := 6.0
const MAGNET_SPEED := 160.0  # px/s, relative to the ship
const MAGNET_SPIN := 4.0     # rad/s
## Close enough to its pose to clamp.
const SEAT_DISTANCE := 3.0
const SEAT_ANGLE := 0.08
## Bumping into a loose piece only hurts the hull above this closing speed (px/s); the
## ship's ordinary knock threshold is far lower. Nudging Freight around is expected.
const KNOCK_DAMAGE_SPEED := 250.0

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

## How long the Lug stays lit after a Sweep ring passes over it.
const LUG_GLOW_TIME := 0.6
## How long the whole piece takes to fade from lit back to its own colours once clamped.
const CLAMP_FLASH_TIME := 0.35

var _collider: CollisionPolygon2D
var _visual: Node2D
var _lug_line: Line2D
var _body: Polygon2D
var _edge: Line2D
var _clamp_flash: Tween
var _lug_glow: Tween

func _init() -> void:
	mass = 3.0  # the ship's own mass, so a clamped test piece halves its acceleration
	gravity_scale = 0.0  # nothing pulls on Freight; it goes where the ship sent it
	linear_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody2D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	can_sleep = false

func _ready() -> void:
	add_to_group("freight")
	add_to_group("sonar_listeners")
	z_index = 1
	_collider = CollisionPolygon2D.new()
	_collider.name = "Collision"
	_collider.polygon = outline
	add_child(_collider)
	_visual = _build_visual()
	# Clamped, this body is disabled to take it out of physics; its looks must keep
	# running regardless, or an echo, a glow or a punch caught mid-way would freeze there.
	_visual.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_visual)

## A Sweep ring reaches the Lug (not the middle of the piece): that is the part that answers.
func sonar_point() -> Vector2:
	return lug_global()

## The Lug answers as the ring passes: it lights up in the Titan's purple, sends small rings
## back out, and fades.
func on_sonar_touched() -> void:
	if not _lug_line:
		return
	SonarEcho.answer(_visual, lug_position)
	if _lug_glow:
		_lug_glow.kill()
	_lug_line.default_color = Colors.TITAN
	_lug_line.width = 5.0
	_lug_glow = _visual.create_tween().set_parallel()
	_lug_glow.tween_property(_lug_line, "default_color", Colors.HULL_LIGHT, LUG_GLOW_TIME)
	_lug_glow.tween_property(_lug_line, "width", 3.0, LUG_GLOW_TIME)

## The clunk of being clamped or let go: a short punch in scale. `amount` is how far past
## its own size it jolts.
func punch(amount := 0.08) -> void:
	if not _visual:
		return
	_visual.scale = Vector2.ONE * (1.0 + amount)
	_visual.create_tween().tween_property(_visual, "scale", Vector2.ONE, 0.18 + amount) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Clamped: the whole piece lights up - body, outline and Lug - and settles back to its
## own colours, so the moment it takes hold is unmistakable.
func flash_clamped() -> void:
	if not _body:
		return
	if _clamp_flash:
		_clamp_flash.kill()
	if _lug_glow:
		_lug_glow.kill()
	_body.color = Colors.HULL_MID.lerp(Colors.PRIMARY, 0.65)
	_edge.default_color = Colors.CREAM
	_edge.width = 2.0
	_lug_line.default_color = Colors.CREAM
	_lug_line.width = 5.5
	_clamp_flash = _visual.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_clamp_flash.tween_property(_body, "color", Colors.HULL_MID, CLAMP_FLASH_TIME)
	_clamp_flash.tween_property(_edge, "default_color", Colors.HULL_LIGHT, CLAMP_FLASH_TIME)
	_clamp_flash.tween_property(_edge, "width", 1.0, CLAMP_FLASH_TIME)
	_clamp_flash.tween_property(_lug_line, "default_color", Colors.HULL_LIGHT, CLAMP_FLASH_TIME * 1.4)
	_clamp_flash.tween_property(_lug_line, "width", 3.0, CLAMP_FLASH_TIME * 1.4)

## Let go: just the Lug glints cream and fades - a lighter mark than the clamp's flash.
func flash_released() -> void:
	if not _lug_line:
		return
	if _lug_glow:
		_lug_glow.kill()
	_lug_line.default_color = Colors.CREAM
	_lug_line.width = 5.0
	_lug_glow = _visual.create_tween().set_parallel()
	_lug_glow.tween_property(_lug_line, "default_color", Colors.HULL_LIGHT, LUG_GLOW_TIME)
	_lug_glow.tween_property(_lug_line, "width", 3.0, LUG_GLOW_TIME)

## Spawn a piece into `world` at `pos`, turned to `rot`.
static func spawn(world: Node, pos: Vector2, rot := 0.0, velocity := Vector2.ZERO) -> Freight:
	var f := Freight.new()
	world.add_child(f)
	f.global_position = pos
	f.global_rotation = rot
	f.linear_velocity = velocity
	return f

## Spawn a piece with its Lug `gap` px ahead of `ship`'s nose, facing it, moving with it:
## a moment's hold of `action` from clamped.
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

func lug_global() -> Vector2:
	return to_global(lug_position)

func lug_facing_global() -> Vector2:
	return lug_facing.rotated(global_rotation).normalized()

## Is the Lug at `lug` within reach of a nose at `nose` - `reach` px?
static func in_reach(nose: Vector2, lug: Vector2, reach := MAGNET_RANGE) -> bool:
	return nose.distance_to(lug) <= reach

## One step of the magnet pulling this piece toward `target` (a global transform: where it
## rides once clamped) on a carrier moving at `carrier_velocity`. Returns true once it is
## seated and can be clamped.
func magnet_step(target: Transform2D, carrier_velocity: Vector2) -> bool:
	var gap := target.origin - global_position
	var turn := wrapf(target.get_rotation() - global_rotation, -PI, PI)
	if is_seated(gap, turn):
		return true
	var pull := magnet_motion(gap, turn)
	linear_velocity = carrier_velocity + pull[0]
	angular_velocity = pull[1]
	return false

## The magnet's velocity (relative to the carrier) and spin for a piece `gap` px and
## `turn` radians away from its pose: proportional, capped, and never stalling short.
static func magnet_motion(gap: Vector2, turn: float) -> Array:
	var v := (gap * MAGNET_GAIN).limit_length(MAGNET_SPEED)
	if v.length() < 20.0 and gap.length() > 0.0:
		v = gap.normalized() * minf(20.0, gap.length() * 60.0)  # don't creep the last few px
	var w := clampf(turn * MAGNET_GAIN, -MAGNET_SPIN, MAGNET_SPIN)
	return [v, w]

static func is_seated(gap: Vector2, turn: float) -> bool:
	return gap.length() <= SEAT_DISTANCE and absf(turn) <= SEAT_ANGLE

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
	_body = body
	var edge := Line2D.new()
	edge.points = outline
	edge.closed = true
	edge.width = 1.0
	edge.default_color = Colors.HULL_LIGHT
	root.add_child(edge)
	_edge = edge
	# The Lug: a flange across the end the ship takes hold of. Scrap has nothing like it.
	var across := lug_facing.orthogonal().normalized()
	var lug := Line2D.new()
	lug.points = PackedVector2Array([
		lug_position + across * 8.0, lug_position - across * 8.0,
	])
	lug.width = 3.0
	lug.default_color = Colors.HULL_LIGHT
	root.add_child(lug)
	_lug_line = lug
	return root
