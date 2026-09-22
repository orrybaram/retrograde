extends AnimatableBody2D
class_name ArrayNudge

## SR-7's right solar wing (docs/OPENING.md §2). Still on its hinge at the keel, but left
## hanging out of true. It is not Freight and nothing clamps it: the ship pushes it home
## with its hull. Pressed against the wing and moving or thrusting so as to turn it back,
## the wing turns; within SNAP_ANGLE of true it swings the rest of the way and locks with the same
## clunk as a seated Section. It only ever turns toward true - a push the wrong way just
## meets a wing that will not give. The node's own transform is the wing seated; its
## rotation is how far off true it hangs. Seated state: GameState.seated_sections.

## How far off true a new game leaves it: well down, so it plainly hangs.
const HANG_ANGLE := deg_to_rad(50.0)
## Hanging, the wing sways limply on its hinge, this much either way, this slowly. Looks
## only: the push and the lock work on where it hangs, not the sway.
const SWAY := deg_to_rad(2.5)
const SWAY_PERIOD := 4.2
## Close enough to true to swing home.
const SNAP_ANGLE := deg_to_rad(3.0)
## The ship counts as pressing on the wing with its centre this close to it (px).
const REACH := 16.0
## How much of the turn the ship's push would give the wing actually reaches it, and the
## fastest the wing will turn. A deliberate shove, not a flick.
const PUSH_GAIN := 0.8
const MAX_TURN_SPEED := deg_to_rad(35.0)
## Held against the wing the hull barely moves, so thrusting counts as pushing at this
## speed (px/s) along the way the engine drives - forward, or back on reverse thrust.
const THRUST_PUSH := 120.0
const LOCK_TIME := 0.3

@export var section := Sections.SOLAR_ARRAY_2
@export var hang_angle := HANG_ANGLE

var seated := false
var _home: Transform2D
var _reach: PackedVector2Array
var _locking: Tween
var _sway_clock := 0.0
## Sparks at the hinge and a red strobe on the keel beside it, while the wing hangs.
var alarm: CutAlarm

func _ready() -> void:
	add_to_group("nudges")
	_home = transform
	# It hangs off the station's own hull: the two never push on each other
	if get_parent() is PhysicsBody2D:
		add_collision_exception_with(get_parent())
	var shape := get_node_or_null("Collision") as CollisionPolygon2D
	if shape:
		var grown := Geometry2D.offset_polygon(shape.polygon, REACH)
		_reach = grown[0] if not grown.is_empty() else shape.polygon
	_build_alarm()
	EventBus.planets_restored.connect(refresh)
	refresh()

## Match the saved or new game: locked true, or hanging off it.
func refresh() -> void:
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	_show_seated(gs != null and gs.is_section_seated(section))

func _show_seated(on: bool) -> void:
	if _locking:
		_locking.kill()
	seated = on
	if alarm:
		alarm.active = not on
	transform = _home * Transform2D(0.0 if on else hang_angle, Vector2.ZERO)

## How far off true it hangs right now (radians, clockwise on screen).
func off_true() -> float:
	return angle_difference(_home.get_rotation(), rotation)

func _process(delta: float) -> void:
	var visual := get_node_or_null("Visual") as Node2D
	if visual == null:
		return
	if seated:
		visual.rotation = 0.0
		return
	_sway_clock += delta
	visual.rotation = sway_at(_sway_clock)

## The limp sway `t` s in, round the hinge.
static func sway_at(t: float) -> float:
	return sin(t * TAU / SWAY_PERIOD) * SWAY

func _physics_process(delta: float) -> void:
	if seated:
		return
	var ship := get_tree().get_first_node_in_group("ship") as Ship
	if ship == null or not is_pressing(ship.global_position):
		return
	# Work in the station's frame, relative to the station's own motion
	var station := get_parent() as Node2D
	var frame := station.global_transform if station else Transform2D.IDENTITY
	var carrier := (station as RigidBody2D).linear_velocity if station is RigidBody2D else Vector2.ZERO
	var at := frame.affine_inverse() * ship.global_position
	var push := frame.basis_xform_inv(ship_push(ship, carrier))
	var off := push_step(off_true(), _home.origin, at, push, delta)
	transform = _home * Transform2D(off, Vector2.ZERO)
	if absf(off) <= SNAP_ANGLE:
		lock()

## How hard `ship` is pushing, as a velocity relative to the station moving at `carrier`:
## how it is moving, plus the thrust it is putting into whatever it is up against.
static func ship_push(ship: Ship, carrier: Vector2) -> Vector2:
	var heading := Vector2.RIGHT.rotated(ship.global_rotation)
	var thrust := (1.0 if ship.want_thrust else 0.0) - (1.0 if ship.want_reverse_thrust else 0.0)
	return ship.linear_velocity - carrier + heading * thrust * THRUST_PUSH

## Whether a ship with its centre at `at` (global) is pressing on the wing.
func is_pressing(at: Vector2) -> bool:
	return not _reach.is_empty() and Geometry2D.is_point_in_polygon(to_local(at), _reach)

## One step of a push: a wing `off` radians off true, hinged at `hinge`, pressed at `at`
## by something moving at `push` (all in the same frame) for `dt` s. Returns how far off
## true it is after. It turns only toward true, never past it, and no faster than
## MAX_TURN_SPEED.
static func push_step(off: float, hinge: Vector2, at: Vector2, push: Vector2, dt: float) -> float:
	var r := at - hinge
	if r.length_squared() < 1.0 or is_zero_approx(off):
		return off
	var spin := r.cross(push) / r.length_squared() * PUSH_GAIN
	if signf(spin) == signf(off) or is_zero_approx(spin):
		return off
	var turn := minf(absf(spin), MAX_TURN_SPEED) * dt
	return signf(off) * maxf(absf(off) - turn, 0.0)

## Swing the last of the way and lock: seated from here on, and saved at once.
func lock() -> void:
	if seated:
		return
	seated = true
	var gs := get_tree().get_first_node_in_group("game_state") as GameState
	if gs:
		gs.mark_section_seated(section)
		Save.save_seated_section(section, PackedStringArray(gs.seated_sections.keys()))
	_locking = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_locking.tween_property(self, "transform", _home, LOCK_TIME)
	_locking.tween_callback(func() -> void:
		Mount.clunk(self)
		if alarm:
			alarm.active = false
		EventBus.section_seated.emit(section))

## On the station, not the wing, so it stays put while the wing turns: the hinge's torn
## lines spark out along the wing's root, and a lamp sits on the keel beside it.
func _build_alarm() -> void:
	var station := get_parent() as Node2D
	if station == null:
		return
	alarm = CutAlarm.new()
	alarm.name = "NudgeAlarm"
	alarm.z_index = 2
	alarm.transform = _home
	alarm.segments = [[Vector2(0, -20), Vector2(0, 20), Vector2.RIGHT]]
	alarm.lamps = PackedVector2Array([Vector2(-10, -14)])
	station.add_child.call_deferred(alarm)

func is_locking() -> bool:
	return _locking != null and _locking.is_running()
