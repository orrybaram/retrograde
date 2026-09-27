extends RigidBody2D
class_name Freight

## Something too big for the hold (docs/adr/0012): clamped rigidly to the ship's nose at
## its one Lug and pushed home ahead of it. Let go, it coasts on as the ship was moving -
## same velocity, same heading, plus a slow drift off the nose, losing only a trace of speed
## to DRAG - and gravity never bends its path. While
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
## Loose Freight bleeds off speed at this rate (per second): a trace of drag, far too
## little to notice on an ordinary release, but enough that a piece let go of after a
## long boost slows below the ship's cruise speed in time and can be caught again.
const DRAG := 0.001
## Bumping into a loose piece only hurts the hull above this closing speed (px/s); the
## ship's ordinary knock threshold is far lower. Nudging Freight around is expected.
const KNOCK_DAMAGE_SPEED := 250.0
## The Void cannot take Freight: loose, it is stopped this far (px) inside VoidZone.EDGE_RADIUS.
const VOID_MARGIN := 8.0
const _VOID := preload("res://scripts/VoidZone.gd")
const VOID_STOP_RADIUS := _VOID.EDGE_RADIUS - VOID_MARGIN
## A load still clamped when the Void takes the ship turns up this far inside the edge
## (px; 1 km on the HUD's readout), on the same bearing from the sun.
const VOID_RETURN_DISTANCE := 1000.0
const VOID_RETURN_RADIUS := _VOID.EDGE_RADIUS - VOID_RETURN_DISTANCE

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

## The ship has had hold of this piece. From then on it is never lost from view: let go,
## it is marked on the Chart and tracked (docs/adr/0012). Never touched, it has no mark.
var handled := false

## Which Section of SR-7 this is (Sections.gd), or "" for any other Freight. A Section
## goes into the Mount with the same id and nowhere else.
var section := ""
## How a Section is drawn over its body (Sections.detail): "" for plain Freight.
var art := ""
## Which Component this is (Components.gd), or "" for any other Freight. A Component goes
## home to SR-7's Cradle, not a Mount.
var component := ""

## How far off (px) a Sweep still gets an answer from it, past where the ring itself
## reaches: faint and broken at the edge, firming up closer (answer_clarity). 0 answers
## only where a ring reaches, like any piece.
var answer_range := 0.0
## Dead to the Sweep until SR-7's core is cold-started (the Cargo Bay, docs/OPENING.md §9).
var answers_needs_power := false
## How clear (0..1) an answer is from the very edge of `answer_range`.
const FAINTEST_ANSWER := 0.2

## Lodged: held at `lodged_offset` in `lodged_in`'s frame (a new game's Section, floating
## dead beside SR-7) so it keeps pace with it instead of being left behind as it moves on
## - to the player it just hangs there. The magnet breaks it free. `lodged_in` is set by whoever placed it there
## (Mount.ensure_section), and is not saved; `lodged` and the offset are.
var lodged := false
var lodged_offset := Vector2.ZERO
var lodged_in: Node2D = null
## Radians/s the lodged spot turns round `lodged_in`: a piece adrift in a debris ring goes
## round with the ring (and turns with it) rather than hanging still in it. 0 hangs still.
var lodged_spin := 0.0

## Buried in a planet's ground (the SOLAR ARRAY, lying in Rook). The magnet reaches it but
## can't lift it: a ship coupled onto its Lug has to fly away from the ground and keep
## pulling harder than `pull_threshold` for PULL_TIME to tear it free (pull). Saved.
var buried := false
## How hard it holds in the ground, as a share of the Aux's full thrust pointed straight
## out of it (FlyingState.pull_force): under 1 the Aux can tear it free; over 1 only the
## Burn can. Set by the Mount that buried it (Mount.buried_pull_threshold).
const DEFAULT_PULL_THRESHOLD := 0.6
var pull_threshold := DEFAULT_PULL_THRESHOLD
## Seconds of pulling past the threshold that tear it free, and how much slower than that
## the progress drains away when the pull eases off.
const PULL_TIME := 1.3
const PULL_EASE := 0.6
## This piece's own PULL_TIME: a heavier one takes longer to tear out (Components).
var pull_time := PULL_TIME
## 0..1: how far the pull has got. Not saved - a load starts the pull over.
var pull_progress := 0.0
## The pull draws it up out of the ground this far (px) on its way to tearing free. It
## never sinks back: what a pull won stays won.
const PULL_RISE := 18.0
var _risen := 0.0
## Straining at it shakes the camera up to this hard, and throws a puff of dust at the
## ground this often (s) - harder and more often the nearer the pull is to the threshold.
const STRAIN_SHAKE := 2.5
const STRAIN_DUST_EVERY := 0.28
var _strain_dust := 0.0
const BREAK_SHAKE := 7.0

var _collider: CollisionPolygon2D
var _tracking: NodeTrackingTarget
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
	linear_damp = DRAG
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

## Hitstop slows physics, but orbits keep wall-clock time: a lodged piece rides its
## planet's orbit, so while time is slowed it is put straight on its spot rather than left
## trailing behind (the ship keeps pace the same way - Ship._process).
func _process(_delta: float) -> void:
	if lodged and is_instance_valid(lodged_in) and HarvestJuice.is_hitstopped():
		global_position = lodged_in.to_global(lodged_offset)

## A Sweep ring reaches the Lug (not the middle of the piece): that is the part that answers.
func sonar_point() -> Vector2:
	return lug_global()

## The Lug answers as the ring passes: it lights up in the Titan's purple, pings back with
## a ring as strong as the one that reached it, and fades. A `clarity` under 1 is an answer
## from past the ring's reach (answer_clarity): fainter, and broken up.
func on_sonar_touched(strength := 1.0, clarity := 1.0) -> void:
	if not _lug_line:
		return
	EventBus.freight_answered.emit()
	SonarEcho.answer_ping(_visual, lug_position, strength, Colors.TITAN, clarity)
	if _lug_glow:
		_lug_glow.kill()
	_lug_line.default_color = Color(Colors.HULL_LIGHT.lerp(Colors.TITAN, clarity), 1.0)
	_lug_line.width = 3.0 + 2.0 * clarity
	_lug_glow = _visual.create_tween().set_parallel()
	_lug_glow.tween_property(_lug_line, "default_color", Colors.HULL_LIGHT, LUG_GLOW_TIME)
	_lug_glow.tween_property(_lug_line, "width", 3.0, LUG_GLOW_TIME)

## Whether a Sweep can get an answer from it at all: a piece that needs SR-7's power is
## dead to it until the core's cold start.
func answers_sweep() -> bool:
	if not answers_needs_power:
		return true
	return StationPower.is_powered(get_tree().get_first_node_in_group("game_state") as GameState)

## How clearly it answers a ring whose edge dies at `ring_reach` px, sent from `distance`
## px off (SonarPulse): 1 where the ring reaches, 0 where it doesn't answer at all.
func answer_clarity(distance: float, ring_reach: float) -> float:
	if not answers_sweep():
		return 0.0
	return long_answer_clarity(distance, ring_reach, answer_range)

## 1 inside `ring_reach`; past it, out to `answer_reach`, fading from 1 to FAINTEST_ANSWER;
## 0 beyond `answer_reach` (or past the ring when there is none).
static func long_answer_clarity(distance: float, ring_reach: float, answer_reach: float) -> float:
	if distance <= ring_reach:
		return 1.0
	if distance > answer_reach:
		return 0.0
	var t := (distance - ring_reach) / maxf(answer_reach - ring_reach, 0.001)
	return lerpf(1.0, FAINTEST_ANSWER, t)

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
	_body.color = Sections.body_color(art).lerp(Colors.PRIMARY, 0.65)
	_edge.default_color = Colors.CREAM
	_edge.width = 2.0
	_lug_line.default_color = Colors.CREAM
	_lug_line.width = 5.5
	_clamp_flash = _visual.create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_clamp_flash.tween_property(_body, "color", Sections.body_color(art), CLAMP_FLASH_TIME)
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

## Spawn Section `id` into `world` at `pos`, turned to `rot`.
static func spawn_section(world: Node, id: String, pos: Vector2, rot := 0.0) -> Freight:
	var f := Freight.new()
	Sections.apply(f, id)
	world.add_child(f)
	f.global_position = pos
	f.global_rotation = rot
	return f

## Hold this piece `offset` from `body` from now on, until the magnet takes it.
func lodge_in(body: Node2D, offset: Vector2, spin := 0.0) -> void:
	lodged = true
	lodged_in = body
	lodged_offset = offset
	lodged_spin = spin

# --- buried ---

func is_buried() -> bool:
	return buried

## Sunk into `planet`'s ground: drawn under the planet's disc, so only what sticks out of
## the ground shows, and never pushing on the planet it is inside. `threshold` > 0 buries
## it holding that hard (pull_threshold); without one it only re-sinks a piece still buried.
func bury_in(planet: Node2D, threshold := 0.0) -> void:
	if threshold > 0.0:
		buried = true
		pull_threshold = threshold
	if not is_buried():
		return
	z_index = 0
	var body := planet as PhysicsBody2D
	if body:
		add_collision_exception_with(body)

## Where it goes into the ground (global): the ground point under the middle of the piece.
func ground_point() -> Vector2:
	var planet := lodged_in as Planet
	if planet == null:
		return global_position
	var dir := (global_position - planet.global_position).normalized()
	return planet.global_position + dir * Mount.ground_radius(planet)

## One step (`dt` s) of a coupled ship pulling with `force` (FlyingState.pull_force). Past
## `pull_threshold` the pull builds; short of it, it drains. True once it has built all
## the way: the piece is ready to tear free (break_free).
func pull(force: float, dt: float) -> bool:
	if not is_buried():
		return true
	if force >= pull_threshold:
		pull_progress = minf(pull_progress + dt / pull_time, 1.0)
	else:
		pull_progress = maxf(pull_progress - dt / pull_time * PULL_EASE, 0.0)
	if pull_progress > _risen and lodged_in:
		var up := lodged_in.global_transform.basis_xform_inv(ground_point() - lodged_in.global_position).normalized()
		lodged_offset += up * (pull_progress - _risen) * PULL_RISE
		_risen = pull_progress
	return pull_progress >= 1.0

## 0..1: how hard `force` strains it, 1 at the threshold and past it.
func strain_of(force: float) -> float:
	return clampf(force / maxf(pull_threshold, 0.001), 0.0, 1.0)

## A coupled ship straining at it, `amount` 0..1, for `dt` s: it trembles in the ground,
## the ground throws dust, and the camera shakes - all harder the harder it pulls.
func strain(amount: float, dt := 0.0, ship: Ship = null) -> void:
	if not _visual:
		return
	var k := amount * amount * 1.8
	var t := Time.get_ticks_msec() / 1000.0
	_visual.position = Vector2(sin(t * 91.0), cos(t * 77.0)) * k if amount > 0.05 else Vector2.ZERO
	if amount <= 0.15:
		_strain_dust = 0.0
		return
	if ship:
		_shake(ship, STRAIN_SHAKE * amount)
	_strain_dust -= dt
	if _strain_dust <= 0.0 and lodged_in:
		_strain_dust = STRAIN_DUST_EVERY * (1.6 - amount)
		var ground := ground_point()
		var outward := (ground - lodged_in.global_position).normalized()
		GroundBreakFX.strain.call_deferred(lodged_in, ground, outward, amount)

## Torn out of the ground: the burst and the scar, and it can be clamped like any piece.
func break_free(ship: Ship) -> void:
	if not is_buried():
		return
	buried = false
	pull_progress = 0.0
	if _visual:
		_visual.position = Vector2.ZERO
	var planet := lodged_in
	var ground := ground_point()
	var outward := (ground - planet.global_position).normalized() if planet else Vector2.UP
	if planet:
		GroundBreakFX.break_free(planet, ground, outward)
	z_index = 1
	punch(0.15)
	if ship:
		_shake(ship, BREAK_SHAKE)
	# It is still half inside the planet: let it clear before they can touch again
	var body := planet as PhysicsBody2D
	if body:
		part_from(body, 2.5)

static func _shake(ship: Ship, intensity: float) -> void:
	ship.damage_shake_time = 0.35
	ship.damage_shake_current_intensity = intensity

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

## Riding on a ship's nose.
func is_clamped() -> bool:
	return get_parent() is Ship

## Left clamped to an abandoned hull.
func is_aboard_derelict() -> bool:
	return get_parent() is DerelictShip

## A body of its own, out in space: the only kind the magnet can take.
func is_loose() -> bool:
	return not is_clamped() and not is_aboard_derelict()

## Handled and let go: drawn on the Chart as the ship's own mark.
func is_marked() -> bool:
	return handled and is_loose()

## This piece, as something to steer toward. One per piece, so NavSystem can tell it is
## still the one being tracked.
func tracking_target() -> NodeTrackingTarget:
	if _tracking == null:
		_tracking = NodeTrackingTarget.new(self, label, 60.0)
	return _tracking

## Where a clamped piece is headed: a Section's Mount, a Component's Cradle, or home.
func destination() -> TrackingTarget:
	if section != "":
		var mount := Mount.for_section(get_tree(), section)
		if mount:
			return mount.tracking_target()
	elif component != "":
		var cradle := Cradle.find(get_tree())
		if cradle:
			return cradle.tracking_target()
	return NavSystem.home_target()

## Don't collide with `body` for `seconds`: they were touching when they parted.
func part_from(body: PhysicsBody2D, seconds := 0.6) -> void:
	add_collision_exception_with(body)
	get_tree().create_timer(seconds).timeout.connect(func() -> void:
		if is_instance_valid(self) and is_instance_valid(body):
			remove_collision_exception_with(body))

## The Void never draws loose Freight in: headed out, it stops at the edge.
func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	if lodged and is_instance_valid(lodged_in):
		# Keep pace: close on the lodged spot within the step
		lodged_offset = lodged_offset.rotated(lodged_spin * state.step)
		var spot := lodged_in.to_global(lodged_offset)
		state.linear_velocity = (spot - state.transform.origin) / maxf(state.step, 0.0001)
		state.angular_velocity = lodged_spin
		return
	var held := held_at_edge(state.transform.origin, state.linear_velocity, VoidZone.sun_position())
	if held.is_empty():
		return
	var t := state.transform
	t.origin = held[0]
	state.transform = t
	state.linear_velocity = Vector2.ZERO
	state.angular_velocity = 0.0

## Whether a loose piece at `pos` moving at `velocity` is stopped by the Void's edge:
## [where it stops], or [] if it goes on. Headed out through the edge from inside, it
## stops just inside it, so nothing can drift or be pushed out. Let go of somewhere past
## the edge, it stops where it is, still headed nowhere, for the ship to come back for.
static func held_at_edge(pos: Vector2, velocity: Vector2, sun: Vector2) -> Array:
	var out := pos - sun
	var d := out.length()
	if d < VOID_STOP_RADIUS or velocity.dot(out) <= 0.0:
		return []
	if d > _VOID.EDGE_RADIUS:
		return [pos]
	return [sun + out / d * VOID_STOP_RADIUS]

## Where a load still clamped when the Void takes its ship at `pos` turns up: on the same
## bearing from the sun, VOID_RETURN_DISTANCE inside the edge.
static func void_return_point(pos: Vector2, sun: Vector2) -> Vector2:
	var out := pos - sun
	return sun + (out.normalized() if out.length() > 0.0 else Vector2.RIGHT) * VOID_RETURN_RADIUS

# --- saving (docs/adr/0012: saved where it is, never respawned or despawned) ---

## This piece as plain data: where it is, how it is moving, and whether it is clamped.
func to_row() -> Dictionary:
	var v := linear_velocity
	var ship := get_parent() as Ship
	if ship:
		v = ship.linear_velocity
	return {
		"x": global_position.x, "y": global_position.y, "rot": global_rotation,
		"vx": v.x, "vy": v.y, "spin": angular_velocity if is_loose() else 0.0,
		"label": label, "handled": handled, "clamped": is_clamped(),
		"section": section, "lodged": lodged, "lodged_x": lodged_offset.x, "lodged_y": lodged_offset.y,
		"lodged_spin": lodged_spin, "buried": buried, "component": component,
	}

static func from_row(world: Node, row: Dictionary) -> Freight:
	var f := Freight.new()
	Sections.apply(f, str(row.get("section", "")))
	Components.apply(f, str(row.get("component", "")))
	f.label = str(row.get("label", f.label))
	f.lodged = bool(row.get("lodged", false))
	f.lodged_offset = Vector2(float(row.get("lodged_x", 0.0)), float(row.get("lodged_y", 0.0)))
	f.lodged_spin = float(row.get("lodged_spin", 0.0))
	f.buried = bool(row.get("buried", false))  # older saves kept a count of tugs left
	f.handled = bool(row.get("handled", false))
	world.add_child(f)
	f.global_position = Vector2(float(row.get("x", 0.0)), float(row.get("y", 0.0)))
	f.global_rotation = float(row.get("rot", 0.0))
	f.linear_velocity = Vector2(float(row.get("vx", 0.0)), float(row.get("vy", 0.0)))
	f.angular_velocity = float(row.get("spin", 0.0))
	return f

## Every piece not aboard a derelict (those are saved with their derelict), for saving.
static func snapshot_all(tree: SceneTree) -> Array:
	var rows := []
	for node in tree.get_nodes_in_group("freight"):
		var f := node as Freight
		if f and not f.is_aboard_derelict() and not f.is_queued_for_deletion():
			rows.append(f.to_row())
	return rows

## Put saved pieces back into `world`. Returns the one that was clamped (not yet on any
## ship: the caller clamps it once the ship is in place), or null.
static func restore_all(world: Node, rows: Array) -> Freight:
	var clamped: Freight = null
	for row in rows:
		if not row is Dictionary:
			continue
		# A Section SR-7 no longer has (MAST 1, from before the station was rebuilt) is
		# not put back: its Mount is gone, and so is it
		var id := str(row.get("section", ""))
		if id != "" and not Sections.exists(id):
			continue
		var f := from_row(world, row)
		if bool(row.get("clamped", false)) and clamped == null:
			clamped = f
			f.process_mode = Node.PROCESS_MODE_DISABLED  # waits, out of physics, for its ship
	return clamped

## Take every piece out of the world, including one on the ship's nose: a load or a new
## game replaces them all.
static func clear_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("freight"):
		var f := node as Freight
		if f == null:
			continue
		var ship := f.get_parent() as Ship
		if ship:
			ship.discard_freight()
		f.remove_from_group("freight")  # gone for saves this frame, not just at free
		f.queue_free()

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
	lodged = false
	lodged_in = null
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
	body.color = Sections.body_color(art)
	root.add_child(body)
	_body = body
	for line in Sections.detail(art, outline):
		root.add_child(line)
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
